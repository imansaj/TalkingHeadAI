import base64
import json
import logging
import re
import time

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import StreamingResponse
import httpx

from app.services.knowledge_service import KnowledgeService
from app.services.llm_service import LLMService
from app.services.stt_service import STTService
from app.services.tts_service import TTSService
from app.services.rag_service import RAGService
from app.models.schemas import ChatRequest, ChatResponse, AnswerType

logger = logging.getLogger(__name__)
router = APIRouter()

# Sentence-end pattern: .!? followed by space or end
_SENTENCE_END = re.compile(r"[.!?…]\s*$")


@router.get("/debug-search")
async def debug_search(q: str = "hello"):
    """Debug endpoint: test FAISS search results for a query."""
    results = RAGService.search(q, top_k=5)
    return {
        "query": q,
        "index_total": RAGService._index.ntotal if RAGService._index else 0,
        "metadata_count": len(RAGService._metadata),
        "results": results,
    }


def _sse_event(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data)}\n\n"


@router.post("/text", response_model=ChatResponse)
async def chat_text(req: ChatRequest):
    """Text-based chat — returns text + audio (non-streaming fallback)."""
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


@router.post("/stream")
async def chat_stream(req: ChatRequest):
    """Streaming chat — SSE stream of synced text+audio sentence events.

    Events:
      sentence    {"text": "...", "audio_base64": "..."}  — one sentence with its audio
      done        {"answer_type": "...", "times_asked": ..., "full_text": "..."}
      error       {"detail": "..."}
    """

    def _tts(client, text: str) -> str:
        """Generate TTS and return base64-encoded audio."""
        tts_resp = client.audio.speech.create(model="tts-1", voice="alloy", input=text)
        return base64.b64encode(tts_resp.content).decode("utf-8")

    def generate():
        try:
            t0 = time.time()
            question = req.text

            from app.config import get_settings
            from app.db.dynamodb import get_table
            from decimal import Decimal
            from openai import OpenAI

            settings = get_settings()
            client = OpenAI(
                api_key=settings.openai_api_key,
                timeout=httpx.Timeout(30.0, connect=10.0),
            )

            logger.info("[STREAM] Starting RAG search for: %s", question[:80])
            t_rag = time.time()
            rag_results = RAGService.search(question, top_k=5)
            logger.info(
                "[STREAM] RAG search done in %.2fs, results=%d",
                time.time() - t_rag,
                len(rag_results),
            )

            match = None
            match_source = None
            SIMILARITY_THRESHOLD = 0.75

            if rag_results and rag_results[0]["score"] >= SIMILARITY_THRESHOLD:
                q_id = rag_results[0]["question_id"]
                logger.info(
                    "[STREAM] Top match: q_id=%s, score=%.4f",
                    q_id,
                    rag_results[0]["score"],
                )
                table = get_table(settings.dynamodb_table_knowledge)
                resp = table.get_item(Key={"question_id": q_id})
                match = resp.get("Item")
                if match:
                    match_source = "knowledge"
                    logger.info("[STREAM] Matched knowledge entry")
                else:
                    unanswered_table = get_table(settings.dynamodb_table_unanswered)
                    resp = unanswered_table.get_item(Key={"question_id": q_id})
                    match = resp.get("Item")
                    if match:
                        match_source = "unanswered"
                        logger.info("[STREAM] Matched unanswered entry")
                    else:
                        logger.info(
                            "[STREAM] q_id=%s not found in knowledge or unanswered tables (session chunk?)",
                            q_id,
                        )
            else:
                if rag_results:
                    logger.info(
                        "[STREAM] Top score %.4f below threshold %.2f",
                        rag_results[0]["score"],
                        SIMILARITY_THRESHOLD,
                    )
                else:
                    logger.info("[STREAM] No RAG results")

            # --- Case B: Known answer ---
            if match and match_source == "knowledge":
                table = get_table(settings.dynamodb_table_knowledge)
                new_count = int(match.get("times_asked", 1)) + 1
                table.update_item(
                    Key={"question_id": match["question_id"]},
                    UpdateExpression="SET times_asked = :c",
                    ExpressionAttributeValues={":c": Decimal(str(new_count))},
                )

                yield _sse_event(
                    "meta", {"answer_type": "known", "times_asked": new_count}
                )

                prefix = f"{new_count} people have asked this question. "
                prefix_audio = _tts(client, prefix)
                yield _sse_event(
                    "sentence", {"text": prefix, "audio_base64": prefix_audio}
                )

                sentence_buffer = ""
                full_text_parts = [prefix]

                for token in LLMService.generate_response_stream(
                    question=question,
                    context_chunks=[match["answer"]],
                    is_new=False,
                ):
                    full_text_parts.append(token)
                    sentence_buffer += token

                    if (
                        _SENTENCE_END.search(sentence_buffer)
                        and len(sentence_buffer) >= 20
                    ):
                        audio_b64 = _tts(client, sentence_buffer.strip())
                        yield _sse_event(
                            "sentence",
                            {"text": sentence_buffer, "audio_base64": audio_b64},
                        )
                        sentence_buffer = ""

                if sentence_buffer.strip():
                    audio_b64 = _tts(client, sentence_buffer.strip())
                    yield _sse_event(
                        "sentence", {"text": sentence_buffer, "audio_base64": audio_b64}
                    )

                full_text = "".join(full_text_parts)
                yield _sse_event(
                    "done",
                    {
                        "answer_type": "known",
                        "times_asked": new_count,
                        "full_text": full_text,
                    },
                )
                return

            # --- Case C: Previously asked unanswered ---
            if match and match_source == "unanswered":
                # Still "new" per requirements (not in knowledge base yet)
                logger.info("[STREAM] Case C: repeated unanswered — treating as new")
                yield _sse_event("meta", {"answer_type": "new", "times_asked": None})

                prefix = "This is a new question. I will give you a general response. "
                prefix_audio = _tts(client, prefix)
                yield _sse_event(
                    "sentence", {"text": prefix, "audio_base64": prefix_audio}
                )

                # Stream a fresh LLM response using RAG context
                context_chunks = [r["text"] for r in rag_results]
                sentence_buffer = ""
                full_text_parts = [prefix]

                for token in LLMService.generate_response_stream(
                    question=question,
                    context_chunks=context_chunks,
                    is_new=True,
                ):
                    full_text_parts.append(token)
                    sentence_buffer += token

                    if (
                        _SENTENCE_END.search(sentence_buffer)
                        and len(sentence_buffer) >= 20
                    ):
                        audio_b64 = _tts(client, sentence_buffer.strip())
                        yield _sse_event(
                            "sentence",
                            {"text": sentence_buffer, "audio_base64": audio_b64},
                        )
                        sentence_buffer = ""

                if sentence_buffer.strip():
                    audio_b64 = _tts(client, sentence_buffer.strip())
                    yield _sse_event(
                        "sentence", {"text": sentence_buffer, "audio_base64": audio_b64}
                    )

                full_text = "".join(full_text_parts)
                yield _sse_event(
                    "done",
                    {
                        "answer_type": "new",
                        "times_asked": None,
                        "full_text": full_text,
                    },
                )
                return

            # --- Case A: New question — stream LLM + sentence-level TTS ---
            logger.info("[STREAM] Case A: new question")
            yield _sse_event("meta", {"answer_type": "new", "times_asked": None})

            context_chunks = [r["text"] for r in rag_results]

            prefix = "This is a new question. I will give you a general response. "
            logger.info("[STREAM] Generating TTS for prefix...")
            t_tts = time.time()
            prefix_audio = _tts(client, prefix)
            logger.info("[STREAM] Prefix TTS done in %.2fs", time.time() - t_tts)
            yield _sse_event("sentence", {"text": prefix, "audio_base64": prefix_audio})

            sentence_buffer = ""
            full_text_parts = [prefix]

            logger.info(
                "[STREAM] Starting LLM stream (model=%s, context_chunks=%d)...",
                settings.openai_model,
                len(context_chunks),
            )
            t_llm = time.time()
            token_count = 0
            for token in LLMService.generate_response_stream(
                question=question,
                context_chunks=context_chunks,
                is_new=True,
            ):
                token_count += 1
                full_text_parts.append(token)
                sentence_buffer += token

                if _SENTENCE_END.search(sentence_buffer) and len(sentence_buffer) >= 20:
                    audio_b64 = _tts(client, sentence_buffer.strip())
                    yield _sse_event(
                        "sentence", {"text": sentence_buffer, "audio_base64": audio_b64}
                    )
                    sentence_buffer = ""

            logger.info(
                "[STREAM] LLM stream done in %.2fs, tokens=%d",
                time.time() - t_llm,
                token_count,
            )

            if sentence_buffer.strip():
                audio_b64 = _tts(client, sentence_buffer.strip())
                yield _sse_event(
                    "sentence", {"text": sentence_buffer, "audio_base64": audio_b64}
                )

            full_text = "".join(full_text_parts)

            import uuid
            from datetime import datetime

            q_id = str(uuid.uuid4())
            general_response = full_text[len(prefix) :]
            unanswered_table = get_table(settings.dynamodb_table_unanswered)
            unanswered_table.put_item(
                Item={
                    "question_id": q_id,
                    "question": question,
                    "general_response": general_response,
                    "created_at": datetime.utcnow().isoformat(),
                    "status": "pending",
                }
            )
            RAGService.add_entry(
                q_id,
                embed_text=question,
                context_text=f"Q: {question}\nA: {general_response}",
            )

            t1 = time.time()
            logger.info("[TIMING] Streaming total: %.2fs", t1 - t0)

            yield _sse_event(
                "done",
                {
                    "answer_type": "new",
                    "times_asked": None,
                    "full_text": full_text,
                },
            )

        except Exception as e:
            logger.exception("Stream error")
            yield _sse_event("error", {"detail": str(e)})

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
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
