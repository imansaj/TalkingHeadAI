import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.api.routes import chat, knowledge, admin, sessions
from app.api.websocket import router as ws_router
from app.db.dynamodb import create_tables
from app.services.rag_service import RAGService

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")

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
    # Rebuild from DynamoDB if local index is empty (ephemeral disk on Render)
    if RAGService._index is None or RAGService._index.ntotal == 0:
        RAGService.rebuild_from_db()


@app.get("/health")
async def health():
    return {"status": "ok", "version": "v8-faiss-fix"}
