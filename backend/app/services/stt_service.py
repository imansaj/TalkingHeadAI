import tempfile
from pathlib import Path
from openai import OpenAI

from app.config import get_settings

settings = get_settings()


class STTService:
    @staticmethod
    def _client() -> OpenAI:
        return OpenAI(api_key=settings.openai_api_key)

    @classmethod
    def transcribe(cls, audio_bytes: bytes, filename: str = "audio.webm") -> str:
        suffix = Path(filename).suffix or ".webm"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
            tmp.write(audio_bytes)
            tmp.flush()
            with open(tmp.name, "rb") as f:
                resp = cls._client().audio.transcriptions.create(
                    model="whisper-1", file=f
                )
        return resp.text
