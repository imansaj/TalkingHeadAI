from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.api.routes import chat, knowledge, admin, sessions
from app.api.websocket import router as ws_router
from app.db.dynamodb import create_tables
from app.services.rag_service import RAGService

settings = get_settings()

app = FastAPI(title=settings.app_title)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(chat.router, prefix="/api/chat", tags=["Chat"])
app.include_router(knowledge.router, prefix="/api/knowledge", tags=["Knowledge Base"])
app.include_router(admin.router, prefix="/api/admin", tags=["Admin"])
app.include_router(sessions.router, prefix="/api/sessions", tags=["Sessions"])
app.include_router(ws_router, prefix="/ws", tags=["WebSocket"])


@app.on_event("startup")
async def startup():
    create_tables()
    RAGService.load_index()


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/debug/env")
async def debug_env():
    key = settings.elevenlabs_api_key
    return {
        "elevenlabs_key_length": len(key),
        "elevenlabs_key_prefix": key[:5] if len(key) > 5 else "EMPTY",
        "elevenlabs_key_suffix": key[-4:] if len(key) > 4 else "EMPTY",
        "elevenlabs_voice_id": settings.elevenlabs_voice_id,
        "openai_key_set": bool(settings.openai_api_key),
        "has_whitespace": key != key.strip(),
    }


@app.get("/debug/tts-test")
async def debug_tts():
    import httpx
    key = settings.elevenlabs_api_key.strip()
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{settings.elevenlabs_voice_id}"
    headers = {"xi-api-key": key, "Content-Type": "application/json"}
    payload = {"text": "test", "model_id": "eleven_multilingual_v2",
               "voice_settings": {"stability": 0.5, "similarity_boost": 0.75}}
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, json=payload, headers=headers)
        return {"status": resp.status_code, "body": resp.text[:300] if resp.status_code != 200 else "OK"}
