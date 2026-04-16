import logging
import time

from openai import OpenAI

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class LLMService:
    @staticmethod
    def _client() -> OpenAI:
        return OpenAI(api_key=settings.openai_api_key)

    @classmethod
    def generate_response(
        cls,
        question: str,
        context_chunks: list[str],
        is_new: bool,
    ) -> str:
        system = (
            "You are TalkingHeadAI, a helpful conversational assistant. "
            "Answer questions using the provided context. "
            "Be concise, friendly, and accurate. "
            "Do not use markdown formatting."
        )

        context_block = "\n\n---\n\n".join(context_chunks) if context_chunks else ""
        original_ctx_len = len(context_block)
        # Truncate context to avoid exceeding prompt limits
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

        logger.info("[LLM] Sending to %s | user_prompt=%d chars | system=%d chars | total_input=%d chars",
                    settings.openai_model, len(user_prompt), len(system), len(user_prompt) + len(system))
        t0 = time.time()

        # Use Chat Completions API — most reliable with gpt-5-mini
        resp = cls._client().chat.completions.create(
            model=settings.openai_model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_prompt},
            ],
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
