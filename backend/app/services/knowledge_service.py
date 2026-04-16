import uuid
from datetime import datetime
from decimal import Decimal
from boto3.dynamodb.conditions import Attr

from app.config import get_settings
from app.db.dynamodb import get_table
from app.services.rag_service import RAGService
from app.services.llm_service import LLMService
from app.models.schemas import AnswerType

settings = get_settings()

SIMILARITY_THRESHOLD = 0.82


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
        rag_results = RAGService.search(question, top_k=5)

        match = None
        if rag_results and rag_results[0]["score"] >= SIMILARITY_THRESHOLD:
            table = get_table(settings.dynamodb_table_knowledge)
            resp = table.get_item(Key={"question_id": rag_results[0]["question_id"]})
            match = resp.get("Item")

        if match:
            # Case B: Known question
            table = get_table(settings.dynamodb_table_knowledge)
            new_count = int(match.get("times_asked", 1)) + 1
            table.update_item(
                Key={"question_id": match["question_id"]},
                UpdateExpression="SET times_asked = :c",
                ExpressionAttributeValues={":c": Decimal(str(new_count))},
            )
            return {
                "answer_type": AnswerType.KNOWN,
                "text": f"{new_count} people have asked this question. {match['answer']}",
                "times_asked": new_count,
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

        # Add to vector index
        RAGService.add_entry(q_id, f"Q: {question}\nA: {answer}")
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
        RAGService.add_entry(question_id, f"Q: {item['question']}\nA: {answer}")

        item["answer"] = answer
        item["updated_at"] = now
        return item

    @classmethod
    def list_knowledge(cls) -> list[dict]:
        table = get_table(settings.dynamodb_table_knowledge)
        resp = table.scan()
        return resp.get("Items", [])

    @classmethod
    def list_unanswered(cls) -> list[dict]:
        table = get_table(settings.dynamodb_table_unanswered)
        resp = table.scan(FilterExpression=Attr("status").eq("pending"))
        return resp.get("Items", [])

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
