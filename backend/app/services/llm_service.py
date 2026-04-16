import logging
import re
import time
from collections.abc import Generator

from openai import OpenAI

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# Sentence boundary: period/!/?/… followed by whitespace or end-of-string
_SENTENCE_RE = re.compile(r'(?<=[.!?…])\s+')


class LLMService:
    @staticmethod
    def _client() -> OpenAI:
        return OpenAI(api_key=settings.openai_api_key)

    @classmethod
    def _build_messages(cls, question: str, context_chunks: list[str], is_new: bool) -> list[dict]:
        system = (
            "You are TalkingHeadAI, a helpful conversational assistant. "
            "Answer questions using the provided context. "
            "Be concise, friendly, and accurate. "
            "Do not use markdown formatting."
        )

        context_block = "\n\n---\n\n".join(context_chunks) if context_chunks else ""
        original_ctx_len = len(context_block)
        if len(context_block) > 2000:
            context_block = context_block[:2000]
            logger.info("[LLM] Context truncated from %d to 2000 chars", original_ctx_len)
        logger.info("[LLM] context_chunks=%d, context_len=%d, question_len=%d", len(context_chunks), len(context_block), len(question))

        if is_new:
            if context_block:
                user_prompt = (
                    "The following question is new and has no approved answer in the knowledge base.\n"
                    "Use the context below (from past sessions and existing knowledge) to give a helpful general response.\n\n"
                    f"Context:\n{context_block}\n\n"
                    f"Question: {question}\n\n"
                    "Provide a general but helpful response."
                )
            else:
                user_prompt = (
                    f"Question: {question}\n\n"
                    "There is no context available yet. Provide a helpful general response based on your knowledge."
                )
        else:
            user_prompt = (
                "Use the following approved answer context to respond precisely.\n\n"
                f"Context:\n{context_block}\n\n"
                f"Question: {question}"
            )

        return [
            {"role": "system", "content": system},
            {"role": "user", "content": user_prompt},
        ]

    @classmethod
    def generate_response(
        cls,
        question: str,
        context_chunks: list[str],
        is_new: bool,
    ) -> str:
        messages = cls._build_messages(question, context_chunks, is_new)
        logger.info("[LLM] Sending to %s (non-streaming)", settings.openai_model)
        t0 = time.time()

        resp = cls._client().chat.completions.create(
            model=settings.openai_model,
            messages=messages,
        )

        t1 = time.time()
        choice = resp.choices[0]
        content = choice.message.content

        logger.info(
            "[LLM] Done in %.2fs | finish_reason=%s | content_length=%d | usage=%s",
            t1 - t0,
            choice.finish_reason,
            len(content) if content else 0,
            resp.usage,
        )
        if not content or not content.strip():
            logger.warning("[LLM] Empty content! finish_reason=%s, full_choice=%s", choice.finish_reason, choice)

        if content and content.strip():
            return content.strip()

        return "I'm sorry, I couldn't generate a response. Please try again."

    @classmethod
    def generate_response_stream(
        cls,
        question: str,
        context_chunks: list[str],
        is_new: bool,
    ) -> Generator[str, None, None]:
        """Yield text chunks as they arrive from the OpenAI streaming API.

        Each yielded string is a small token-level chunk.
        """
        messages = cls._build_messages(question, context_chunks, is_new)
        logger.info("[LLM] Sending to %s (streaming)", settings.openai_model)
        t0 = time.time()

        stream = cls._client().chat.completions.create(
            model=settings.openai_model,
            messages=messages,
            stream=True,
        )

        full_text = []
        for chunk in stream:
            delta = chunk.choices[0].delta if chunk.choices else None
            if delta and delta.content:
                full_text.append(delta.content)
                yield delta.content

        t1 = time.time()
        logger.info("[LLM] Stream done in %.2fs | total_length=%d", t1 - t0, sum(len(t) for t in full_text))
