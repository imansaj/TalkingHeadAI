from fastapi import APIRouter, HTTPException

from app.services.knowledge_service import KnowledgeService
from app.models.schemas import KnowledgeCreateRequest, KnowledgeUpdateRequest

router = APIRouter()


@router.get("/")
async def list_knowledge():
    return KnowledgeService.list_knowledge()


@router.post("/")
async def create_knowledge(req: KnowledgeCreateRequest):
    return KnowledgeService.add_knowledge_entry(req.question, req.answer)


@router.put("/{question_id}")
async def update_knowledge(question_id: str, req: KnowledgeUpdateRequest):
    result = KnowledgeService.update_knowledge_entry(question_id, req.answer)
    if not result:
        raise HTTPException(status_code=404, detail="Entry not found")
    return result
