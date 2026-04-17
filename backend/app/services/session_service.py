import uuid
import logging
from datetime import datetime

from app.config import get_settings
from app.db.dynamodb import get_table
from app.services.rag_service import RAGService

logger = logging.getLogger(__name__)
settings = get_settings()


class SessionService:
    @classmethod
    def upload_transcript(cls, title: str, transcript: str) -> dict:
        session_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        item = {
            "session_id": session_id,
            "title": title,
            "transcript": transcript,
            "created_at": now,
            "processed": False,
        }
        table = get_table(settings.dynamodb_table_sessions)
        table.put_item(Item=item)

        # Auto-process: index transcript into FAISS for RAG enrichment
        try:
            cls._index_transcript(session_id, title, transcript)
            item["processed"] = True
            table.update_item(
                Key={"session_id": session_id},
                UpdateExpression="SET processed = :p",
                ExpressionAttributeValues={":p": True},
            )
            logger.info(
                "[SESSION] Auto-processed transcript '%s' (%s)", title, session_id
            )
        except Exception:
            logger.exception(
                "[SESSION] Auto-process failed for '%s' (%s), can retry via /process",
                title,
                session_id,
            )

        return item

    @classmethod
    def process_transcript(cls, session_id: str) -> dict:
        """Index a session transcript into FAISS for RAG context enrichment."""
        table = get_table(settings.dynamodb_table_sessions)
        resp = table.get_item(Key={"session_id": session_id})
        item = resp.get("Item")
        if not item:
            raise ValueError("Session not found")

        # Remove old chunks for this session before re-indexing
        RAGService.remove_entries_by_prefix(f"session_{session_id}_")

        cls._index_transcript(session_id, item["title"], item["transcript"])

        table.update_item(
            Key={"session_id": session_id},
            UpdateExpression="SET processed = :p",
            ExpressionAttributeValues={":p": True},
        )

        item["processed"] = True
        return item

    @classmethod
    def _index_transcript(cls, session_id: str, title: str, transcript: str):
        """Chunk and index a transcript into FAISS (batch embedding)."""
        chunks = cls._chunk_text(transcript, max_chars=settings.session_chunk_max_chars)
        logger.info("[SESSION] Indexing %d chunks for session '%s'", len(chunks), title)
        entries = []
        for i, chunk in enumerate(chunks):
            chunk_id = f"session_{session_id}_{i}"
            entries.append(
                {
                    "question_id": chunk_id,
                    "embed_text": chunk,
                    "context_text": f"[Session: {title}]\n{chunk}",
                    "source_type": "session_transcript",
                }
            )
        RAGService.add_entries_batch(entries)

    @classmethod
    def ingest_unprocessed(cls) -> int:
        """Process all unprocessed session transcripts. Called by the scheduler."""
        table = get_table(settings.dynamodb_table_sessions)
        resp = table.scan()
        items = resp.get("Items", [])
        count = 0
        for item in items:
            if item.get("processed"):
                continue
            session_id = item["session_id"]
            title = item.get("title", "")
            transcript = item.get("transcript", "")
            if not transcript:
                continue
            try:
                cls._index_transcript(session_id, title, transcript)
                table.update_item(
                    Key={"session_id": session_id},
                    UpdateExpression="SET processed = :p",
                    ExpressionAttributeValues={":p": True},
                )
                count += 1
                logger.info(
                    "[SESSION] Scheduled ingestion processed '%s' (%s)",
                    title,
                    session_id,
                )
            except Exception:
                logger.exception(
                    "[SESSION] Scheduled ingestion failed for '%s' (%s)",
                    title,
                    session_id,
                )
        return count

    @classmethod
    def list_sessions(cls) -> list[dict]:
        table = get_table(settings.dynamodb_table_sessions)
        resp = table.scan()
        items = resp.get("Items", [])
        # Don't return full transcript in list view
        for item in items:
            item.pop("transcript", None)
        return items

    @classmethod
    def delete_session(cls, session_id: str) -> dict:
        table = get_table(settings.dynamodb_table_sessions)
        table.delete_item(Key={"session_id": session_id})
        return {"deleted": session_id}

    @classmethod
    def delete_all_sessions(cls) -> dict:
        table = get_table(settings.dynamodb_table_sessions)
        resp = table.scan(ProjectionExpression="session_id")
        items = resp.get("Items", [])
        while resp.get("LastEvaluatedKey"):
            resp = table.scan(
                ProjectionExpression="session_id",
                ExclusiveStartKey=resp["LastEvaluatedKey"],
            )
            items.extend(resp.get("Items", []))
        with table.batch_writer() as batch:
            for item in items:
                batch.delete_item(Key={"session_id": item["session_id"]})
        return {"deleted": len(items)}

    @staticmethod
    def _chunk_text(text: str, max_chars: int = 500) -> list[str]:
        sentences = text.replace("\n", " ").split(". ")
        chunks, current = [], ""
        for s in sentences:
            if len(current) + len(s) + 2 > max_chars and current:
                chunks.append(current.strip())
                current = ""
            current += s + ". "
        if current.strip():
            chunks.append(current.strip())
        return chunks
