from fastapi import APIRouter, HTTPException

from app.services.session_service import SessionService
from app.models.schemas import SessionUploadRequest

router = APIRouter()


@router.get("/")
async def list_sessions():
    return SessionService.list_sessions()


@router.post("/upload")
async def upload_transcript(req: SessionUploadRequest):
    return SessionService.upload_transcript(req.title, req.transcript)


@router.post("/{session_id}/process")
async def process_session(session_id: str):
    """Index a session transcript into the RAG vector store."""
    try:
        return SessionService.process_transcript(session_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
