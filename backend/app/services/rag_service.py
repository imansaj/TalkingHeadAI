import os
import json
import numpy as np
import faiss
from openai import OpenAI

from app.config import get_settings

settings = get_settings()


class RAGService:
    _index: faiss.IndexFlatIP | None = None
    _metadata: list[dict] = []  # [{question_id, text}]
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
                cls._metadata = json.load(f)
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
    def add_entry(cls, question_id: str, text: str):
        vec = cls.embed([text])
        cls._index.add(vec)
        cls._metadata.append({"question_id": question_id, "text": text})
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
            texts = [m["text"] for m in cls._metadata]
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
            entry = cls._metadata[idx].copy()
            entry["score"] = float(score)
            results.append(entry)
        return results
