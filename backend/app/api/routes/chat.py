import logging
import time
from fastapi import APIRouter, UploadFile, File, Form, HTTPException

from app.services.knowledge_service import KnowledgeService
from app.services.stt_service import STTService
from app.services.tts_service import TTSService
from app.models.schemas import ChatRequest, ChatResponse

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/text", response_model=ChatResponse)
async def chat_text(req: ChatRequest):
    """Text-based chat — returns text + audio."""
    try:
        t0 = time.time()
        result = KnowledgeService.answer_question(req.text)
        t1 = time.time()
        logger.info("[TIMING] KnowledgeService.answer_question: %.2fs", t1 - t0)

        audio_b64 = await TTSService.synthesize_base64(result["text"])
        t2 = time.time()
        logger.info("[TIMING] TTSService.synthesize: %.2fs", t2 - t1)
        logger.info("[TIMING] Total: %.2fs", t2 - t0)

        return ChatResponse(
            answer_type=result["answer_type"],
            text=result["text"],
            audio_base64=audio_b64,
            times_asked=result["times_asked"],
        )
    except Exception as e:
        logger.exception("Chat text error")
        raise HTTPException(status_code=500, detail=str(e))


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
