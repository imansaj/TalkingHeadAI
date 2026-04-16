from fastapi import APIRouter, HTTPException

from app.services.knowledge_service import KnowledgeService
from app.models.schemas import ReviewAnswerRequest

router = APIRouter()


@router.get("/unanswered")
async def list_unanswered():
    """List all pending unanswered questions for mentor review."""
    return KnowledgeService.list_unanswered()


@router.post("/review")
async def review_question(req: ReviewAnswerRequest):
    """Mentor reviews an unanswered question and provides an authoritative answer."""
    try:
        return KnowledgeService.review_unanswered(req.question_id, req.answer)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
