from fastapi import APIRouter, UploadFile, File, Form

from app.services.knowledge_service import KnowledgeService
from app.services.stt_service import STTService
from app.services.tts_service import TTSService
from app.models.schemas import ChatRequest, ChatResponse

router = APIRouter()


@router.post("/text", response_model=ChatResponse)
async def chat_text(req: ChatRequest):
    """Text-based chat — returns text + audio."""
    result = KnowledgeService.answer_question(req.text)
    audio_b64 = await TTSService.synthesize_base64(result["text"])
    return ChatResponse(
        answer_type=result["answer_type"],
        text=result["text"],
        audio_base64=audio_b64,
        times_asked=result["times_asked"],
    )


@router.post("/voice", response_model=ChatResponse)
async def chat_voice(audio: UploadFile = File(...)):
    """Voice-based chat — accepts audio, returns text + audio."""
    audio_bytes = await audio.read()
    transcript = STTService.transcribe(audio_bytes, audio.filename or "audio.webm")
    result = KnowledgeService.answer_question(transcript)
    audio_b64 = await TTSService.synthesize_base64(result["text"])
    return ChatResponse(
        answer_type=result["answer_type"],
        text=result["text"],
        audio_base64=audio_b64,
        times_asked=result["times_asked"],
    )
