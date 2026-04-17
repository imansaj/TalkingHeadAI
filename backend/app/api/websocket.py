import base64
import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.services.stt_service import STTService
from app.services.tts_service import TTSService
from app.services.knowledge_service import KnowledgeService

logger = logging.getLogger(__name__)
router = APIRouter()


@router.websocket("/chat")
async def ws_chat(ws: WebSocket):
    """
    Real-time voice chat over WebSocket.

    Client sends:
      - Binary frame: raw audio bytes for STT
      - Text frame:   JSON {"type": "text", "text": "..."}

    Server sends:
      - Text frame: JSON {
            "answer_type": "new"|"known",
            "text": "...",
            "audio_base64": "...",
            "times_asked": int|null
        }
    """
    await ws.accept()

    try:
        while True:
            message = await ws.receive()

            if "bytes" in message and message["bytes"]:
                # Voice input
                audio_bytes = message["bytes"]
                transcript = STTService.transcribe(audio_bytes)
                question = transcript
            elif "text" in message and message["text"]:
                data = json.loads(message["text"])
                question = data.get("text", "")
            else:
                continue

            if not question.strip():
                continue

            try:
                result = KnowledgeService.answer_question(question)
                audio_b64 = await TTSService.synthesize_base64(result["text"])

                await ws.send_json(
                    {
                        "answer_type": result["answer_type"].value,
                        "text": result["text"],
                        "audio_base64": audio_b64,
                        "times_asked": result["times_asked"],
                        "user_question": question,
                    }
                )
            except Exception as e:
                logger.exception("Error processing question via WebSocket: %s", question[:80])
                await ws.send_json(
                    {
                        "answer_type": "error",
                        "text": f"Sorry, an error occurred: {e}",
                        "audio_base64": "",
                        "times_asked": None,
                        "user_question": question,
                    }
                )
    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception("WebSocket connection error")
