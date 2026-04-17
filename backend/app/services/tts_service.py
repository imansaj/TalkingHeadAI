import base64
from openai import OpenAI
import httpx

from app.config import get_settings

settings = get_settings()
_client = OpenAI(
    api_key=settings.openai_api_key,
    timeout=httpx.Timeout(30.0, connect=10.0),
)


class TTSService:
    @classmethod
    async def synthesize(cls, text: str) -> bytes:
        response = _client.audio.speech.create(
            model="tts-1",
            voice="alloy",
            input=text,
        )
        return response.content

    @classmethod
    async def synthesize_base64(cls, text: str) -> str:
        audio_bytes = await cls.synthesize(text)
        return base64.b64encode(audio_bytes).decode("utf-8")
