import logging

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.background import BackgroundScheduler

from app.config import get_settings
from app.api.routes import chat, knowledge, admin, sessions
from app.api.websocket import router as ws_router
from app.db.dynamodb import create_tables
from app.services.rag_service import RAGService
from app.services.session_service import SessionService

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s"
)
logger = logging.getLogger(__name__)

settings = get_settings()

scheduler = BackgroundScheduler()


def _scheduled_ingest():
    """Background job: ingest any unprocessed session transcripts."""
    try:
        count = SessionService.ingest_unprocessed()
        if count:
            logger.info(
                "[SCHEDULER] Ingested %d unprocessed session transcripts", count
            )
    except Exception:
        logger.exception("[SCHEDULER] Session ingestion failed")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    create_tables()
    RAGService.load_index()
    RAGService.rebuild_from_db()
    scheduler.add_job(
        _scheduled_ingest,
        "interval",
        minutes=settings.session_ingest_interval_minutes,
        id="session_ingest",
    )
    scheduler.start()
    logger.info(
        "[SCHEDULER] Session ingestion job started (every %d min)",
        settings.session_ingest_interval_minutes,
    )
    yield
    # Shutdown
    scheduler.shutdown(wait=False)


app = FastAPI(title=settings.app_title, lifespan=lifespan)

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


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "version": "v9-rebuild-fix",
        "faiss_vectors": RAGService._index.ntotal if RAGService._index else 0,
        "rebuild_attempted": RAGService._rebuild_attempted,
    }
