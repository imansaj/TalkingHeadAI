from fastapi import APIRouter, HTTPException

from app.services.knowledge_service import KnowledgeService
from app.models.schemas import ReviewAnswerRequest, ApproveAnswerRequest

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


@router.post("/approve")
async def approve_question(req: ApproveAnswerRequest):
    """Approve the AI's general response as the authoritative answer."""
    try:
        return KnowledgeService.approve_unanswered(req.question_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/unanswered/{question_id}")
async def delete_unanswered(question_id: str):
    """Delete a single unanswered question."""
    if not KnowledgeService.delete_unanswered_entry(question_id):
        raise HTTPException(status_code=404, detail="Entry not found")
    return {"deleted": question_id}


@router.delete("/unanswered")
async def delete_all_unanswered():
    """Delete all unanswered questions."""
    count = KnowledgeService.delete_all_unanswered()
    return {"deleted": count}
