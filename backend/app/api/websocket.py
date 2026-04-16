import base64
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.services.stt_service import STTService
from app.services.tts_service import TTSService
from app.services.knowledge_service import KnowledgeService

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
    except WebSocketDisconnect:
        pass
