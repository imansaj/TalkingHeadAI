import base64
import httpx

from app.config import get_settings

settings = get_settings()

ELEVENLABS_URL = "https://api.elevenlabs.io/v1/text-to-speech"


class TTSService:
    @classmethod
    async def synthesize(cls, text: str) -> bytes:
        url = f"{ELEVENLABS_URL}/{settings.elevenlabs_voice_id}"
        headers = {
            "xi-api-key": settings.elevenlabs_api_key,
            "Content-Type": "application/json",
        }
        payload = {
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
        }
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(url, json=payload, headers=headers)
            resp.raise_for_status()
            return resp.content

    @classmethod
    async def synthesize_base64(cls, text: str) -> str:
        audio_bytes = await cls.synthesize(text)
        return base64.b64encode(audio_bytes).decode("utf-8")
