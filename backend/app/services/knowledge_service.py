import uuid
import time
import logging
from datetime import datetime
from decimal import Decimal
from boto3.dynamodb.conditions import Attr

from app.config import get_settings
from app.db.dynamodb import get_table
from app.services.rag_service import RAGService
from app.services.llm_service import LLMService
from app.models.schemas import AnswerType

logger = logging.getLogger(__name__)

settings = get_settings()

SIMILARITY_THRESHOLD = 0.75


class KnowledgeService:
    # ── Lookup / matching ──────────────────────────────────

    @classmethod
    def find_matching_question(cls, question: str) -> dict | None:
        results = RAGService.search(question, top_k=1)
        if not results:
            return None
        best = results[0]
        if best["score"] < SIMILARITY_THRESHOLD:
            return None
        # Fetch full entry from DynamoDB
        table = get_table(settings.dynamodb_table_knowledge)
        resp = table.get_item(Key={"question_id": best["question_id"]})
        return resp.get("Item")

    # ── Two-mode answer ─────────────────────────────────────

    @classmethod
    def answer_question(cls, question: str) -> dict:
        # Single embedding search — reuse results for both matching and context
        t0 = time.time()
        rag_results = RAGService.search(question, top_k=5)
        t1 = time.time()
        logger.info(
            "[THINKING] RAG search: %.2fs | results=%d", t1 - t0, len(rag_results)
        )

        match = None
        match_source = None  # "knowledge" or "unanswered"
        if rag_results:
            logger.info(
                "[MATCHING] Top result: score=%.4f, q_id=%s, threshold=%.2f",
                rag_results[0]["score"],
                rag_results[0]["question_id"],
                SIMILARITY_THRESHOLD,
            )
        if rag_results and rag_results[0]["score"] >= SIMILARITY_THRESHOLD:
            q_id = rag_results[0]["question_id"]
            # Check knowledge table first (approved answers)
            table = get_table(settings.dynamodb_table_knowledge)
            resp = table.get_item(Key={"question_id": q_id})
            match = resp.get("Item")
            if match:
                match_source = "knowledge"
            else:
                # Check unanswered table (previously asked but not approved)
                unanswered_table = get_table(settings.dynamodb_table_unanswered)
                resp = unanswered_table.get_item(Key={"question_id": q_id})
                match = resp.get("Item")
                if match:
                    match_source = "unanswered"

        if match and match_source == "knowledge":
            # Case B: Known approved question — use LLM for natural delivery
            table = get_table(settings.dynamodb_table_knowledge)
            new_count = int(match.get("times_asked", 1)) + 1
            table.update_item(
                Key={"question_id": match["question_id"]},
                UpdateExpression="SET times_asked = :c",
                ExpressionAttributeValues={":c": Decimal(str(new_count))},
            )
            llm_answer = LLMService.generate_response(
                question=question,
                context_chunks=[match["answer"]],
                is_new=False,
            )
            return {
                "answer_type": AnswerType.KNOWN,
                "text": f"{new_count} people have asked this question. {llm_answer}",
                "times_asked": new_count,
            }

        if match and match_source == "unanswered":
            # Previously asked but not yet reviewed — still a "new" question per requirements
            # Don't create a duplicate unanswered entry
            context_chunks = [r["text"] for r in rag_results]
            general_response = LLMService.generate_response(
                question=question,
                context_chunks=context_chunks,
                is_new=True,
            )
            full_response = (
                "This is a new question. I will give you a general response. "
                + general_response
            )
            return {
                "answer_type": AnswerType.NEW,
                "text": full_response,
                "times_asked": None,
            }

        # Case A: New question — RAG general response
        context_chunks = [r["text"] for r in rag_results]

        general_response = LLMService.generate_response(
            question=question,
            context_chunks=context_chunks,
            is_new=True,
        )

        full_response = (
            "This is a new question. I will give you a general response. "
            + general_response
        )

        # Store in unanswered pool
        q_id = str(uuid.uuid4())
        unanswered_table = get_table(settings.dynamodb_table_unanswered)
        unanswered_table.put_item(
            Item={
                "question_id": q_id,
                "question": question,
                "general_response": general_response,
                "created_at": datetime.utcnow().isoformat(),
                "status": "pending",
            }
        )

        # Add to FAISS index — embed question for matching, store Q+A for context
        RAGService.add_entry(
            q_id,
            embed_text=question,
            context_text=f"Q: {question}\nA: {general_response}",
        )

        return {
            "answer_type": AnswerType.NEW,
            "text": full_response,
            "times_asked": None,
        }

    # ── CRUD helpers ─────────────────────────────────────────

    @classmethod
    def add_knowledge_entry(cls, question: str, answer: str) -> dict:
        q_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        item = {
            "question_id": q_id,
            "question": question,
            "answer": answer,
            "times_asked": Decimal("0"),
            "source": "mentor",
            "created_at": now,
            "updated_at": now,
        }
        table = get_table(settings.dynamodb_table_knowledge)
        table.put_item(Item=item)

        # Add to vector index — embed question for matching, store Q+A for context
        RAGService.add_entry(
            q_id, embed_text=question, context_text=f"Q: {question}\nA: {answer}"
        )
        return item

    @classmethod
    def update_knowledge_entry(cls, question_id: str, answer: str) -> dict | None:
        table = get_table(settings.dynamodb_table_knowledge)
        resp = table.get_item(Key={"question_id": question_id})
        item = resp.get("Item")
        if not item:
            return None

        now = datetime.utcnow().isoformat()
        table.update_item(
            Key={"question_id": question_id},
            UpdateExpression="SET answer = :a, updated_at = :u",
            ExpressionAttributeValues={":a": answer, ":u": now},
        )

        # Update vector index
        RAGService.remove_entry(question_id)
        RAGService.add_entry(
            question_id,
            embed_text=item["question"],
            context_text=f"Q: {item['question']}\nA: {answer}",
        )

        item["answer"] = answer
        item["updated_at"] = now
        return item

    @classmethod
    def list_knowledge(cls) -> list[dict]:
        table = get_table(settings.dynamodb_table_knowledge)
        resp = table.scan()
        return resp.get("Items", [])

    @classmethod
    def delete_knowledge_entry(cls, question_id: str) -> bool:
        table = get_table(settings.dynamodb_table_knowledge)
        resp = table.get_item(Key={"question_id": question_id})
        if not resp.get("Item"):
            return False
        table.delete_item(Key={"question_id": question_id})
        RAGService.remove_entry(question_id)
        return True

    @classmethod
    def delete_all_knowledge(cls) -> int:
        table = get_table(settings.dynamodb_table_knowledge)
        items = []
        resp = table.scan(ProjectionExpression="question_id")
        items.extend(resp.get("Items", []))
        while "LastEvaluatedKey" in resp:
            resp = table.scan(
                ProjectionExpression="question_id",
                ExclusiveStartKey=resp["LastEvaluatedKey"],
            )
            items.extend(resp.get("Items", []))
        for item in items:
            table.delete_item(Key={"question_id": item["question_id"]})
            RAGService.remove_entry(item["question_id"])
        return len(items)

    @classmethod
    def list_unanswered(cls) -> list[dict]:
        table = get_table(settings.dynamodb_table_unanswered)
        resp = table.scan(FilterExpression=Attr("status").eq("pending"))
        return resp.get("Items", [])

    @classmethod
    def delete_unanswered_entry(cls, question_id: str) -> bool:
        table = get_table(settings.dynamodb_table_unanswered)
        resp = table.get_item(Key={"question_id": question_id})
        if not resp.get("Item"):
            return False
        table.delete_item(Key={"question_id": question_id})
        RAGService.remove_entry(question_id)
        return True

    @classmethod
    def delete_all_unanswered(cls) -> int:
        table = get_table(settings.dynamodb_table_unanswered)
        items = []
        resp = table.scan(ProjectionExpression="question_id")
        items.extend(resp.get("Items", []))
        while "LastEvaluatedKey" in resp:
            resp = table.scan(
                ProjectionExpression="question_id",
                ExclusiveStartKey=resp["LastEvaluatedKey"],
            )
            items.extend(resp.get("Items", []))
        for item in items:
            table.delete_item(Key={"question_id": item["question_id"]})
            RAGService.remove_entry(item["question_id"])
        return len(items)

    @classmethod
    def review_unanswered(cls, question_id: str, answer: str) -> dict:
        """Mentor reviews an unanswered question — promote it to knowledge base."""
        unanswered_table = get_table(settings.dynamodb_table_unanswered)
        resp = unanswered_table.get_item(Key={"question_id": question_id})
        item = resp.get("Item")
        if not item:
            raise ValueError("Unanswered entry not found")

        # Promote to knowledge base
        kb_entry = cls.add_knowledge_entry(item["question"], answer)

        # Mark as reviewed
        unanswered_table.update_item(
            Key={"question_id": question_id},
            UpdateExpression="SET #s = :s",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": "reviewed"},
        )

        return kb_entry
