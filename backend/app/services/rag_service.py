import os
import json
import numpy as np
import faiss
from openai import OpenAI

from app.config import get_settings

settings = get_settings()


class RAGService:
    _index: faiss.IndexFlatIP | None = None
    _metadata: list[dict] = []  # [{question_id, embed_text, context_text}]
    _dimension: int = 1536  # text-embedding-3-small

    @classmethod
    def _get_client(cls) -> OpenAI:
        return OpenAI(api_key=settings.openai_api_key)

    @classmethod
    def embed(cls, texts: list[str]) -> np.ndarray:
        client = cls._get_client()
        resp = client.embeddings.create(
            input=texts, model=settings.openai_embedding_model
        )
        vecs = np.array([e.embedding for e in resp.data], dtype="float32")
        faiss.normalize_L2(vecs)
        return vecs

    @classmethod
    def load_index(cls):
        idx_path = settings.faiss_index_path
        index_file = os.path.join(idx_path, "index.faiss")
        meta_file = os.path.join(idx_path, "metadata.json")

        if os.path.exists(index_file) and os.path.exists(meta_file):
            cls._index = faiss.read_index(index_file)
            with open(meta_file) as f:
                raw_meta = json.load(f)
            # Migrate old format: {question_id, text} -> {question_id, embed_text, context_text}
            cls._metadata = []
            for m in raw_meta:
                if "embed_text" in m:
                    cls._metadata.append(m)
                else:
                    cls._metadata.append({
                        "question_id": m["question_id"],
                        "embed_text": m.get("text", ""),
                        "context_text": m.get("text", ""),
                    })
        else:
            cls._index = faiss.IndexFlatIP(cls._dimension)
            cls._metadata = []

    @classmethod
    def save_index(cls):
        idx_path = settings.faiss_index_path
        os.makedirs(idx_path, exist_ok=True)
        faiss.write_index(cls._index, os.path.join(idx_path, "index.faiss"))
        with open(os.path.join(idx_path, "metadata.json"), "w") as f:
            json.dump(cls._metadata, f)

    @classmethod
    def add_entry(cls, question_id: str, embed_text: str, context_text: str | None = None):
        """Add an entry to the FAISS index.

        Args:
            question_id: Unique ID for this entry.
            embed_text: Text to embed for similarity search (typically the question).
            context_text: Text to return as RAG context (typically Q+A). Defaults to embed_text.
        """
        vec = cls.embed([embed_text])
        cls._index.add(vec)
        cls._metadata.append({
            "question_id": question_id,
            "embed_text": embed_text,
            "context_text": context_text or embed_text,
        })
        cls.save_index()

    @classmethod
    def remove_entry(cls, question_id: str):
        """Rebuild index without the given question_id."""
        new_meta = [m for m in cls._metadata if m["question_id"] != question_id]
        if len(new_meta) == len(cls._metadata):
            return
        cls._metadata = new_meta
        cls._index = faiss.IndexFlatIP(cls._dimension)
        if cls._metadata:
            texts = [m["embed_text"] for m in cls._metadata]
            vecs = cls.embed(texts)
            cls._index.add(vecs)
        cls.save_index()

    @classmethod
    def search(cls, query: str, top_k: int = 5) -> list[dict]:
        if cls._index is None or cls._index.ntotal == 0:
            return []
        vec = cls.embed([query])
        k = min(top_k, cls._index.ntotal)
        scores, indices = cls._index.search(vec, k)
        results = []
        for score, idx in zip(scores[0], indices[0]):
            if idx < 0:
                continue
            entry = cls._metadata[idx]
            results.append({
                "question_id": entry["question_id"],
                "text": entry["context_text"],
                "score": float(score),
            })
        return results
