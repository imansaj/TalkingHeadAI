import logging

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

        resp = cls._client().chat.completions.create(
            model=settings.openai_model,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_prompt},
            ],
            max_completion_tokens=4096,
            reasoning={"effort": "low"},
        )
        choice = resp.choices[0]
        content = choice.message.content

        # Log for debugging
        logger.info(
            "LLM response: finish_reason=%s, content_length=%s, usage=%s",
            choice.finish_reason,
            len(content) if content else 0,
            resp.usage,
        )

        if content and content.strip():
            return content.strip()

        # Fallback: try output_text for newer response format
        if hasattr(resp, 'output_text') and resp.output_text:
            return resp.output_text.strip()

        return "I'm sorry, I couldn't generate a response. Please try again."
