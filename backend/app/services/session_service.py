import uuid
from datetime import datetime

from app.config import get_settings
from app.db.dynamodb import get_table
from app.services.rag_service import RAGService

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
        return item

    @classmethod
    def process_transcript(cls, session_id: str) -> dict:
        """Index a session transcript into FAISS for RAG context enrichment."""
        table = get_table(settings.dynamodb_table_sessions)
        resp = table.get_item(Key={"session_id": session_id})
        item = resp.get("Item")
        if not item:
            raise ValueError("Session not found")

        # Chunk the transcript into ~500-char segments
        transcript = item["transcript"]
        chunks = cls._chunk_text(transcript, max_chars=500)

        for i, chunk in enumerate(chunks):
            chunk_id = f"session_{session_id}_{i}"
            RAGService.add_entry(
                chunk_id,
                embed_text=chunk,
                context_text=f"[Session: {item['title']}]\n{chunk}",
            )

        table.update_item(
            Key={"session_id": session_id},
            UpdateExpression="SET processed = :p",
            ExpressionAttributeValues={":p": True},
        )

        item["processed"] = True
        return item

    @classmethod
    def list_sessions(cls) -> list[dict]:
        table = get_table(settings.dynamodb_table_sessions)
        resp = table.scan()
        items = resp.get("Items", [])
        # Don't return full transcript in list view
        for item in items:
            item.pop("transcript", None)
        return items

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
