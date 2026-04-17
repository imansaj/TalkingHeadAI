from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum


# ── Knowledge Base ──────────────────────────────────────────


class KnowledgeEntry(BaseModel):
    question_id: str
    question: str
    answer: str
    times_asked: int = 1
    source: str = "mentor"  # "mentor" | "session_transcript"
    created_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())


class KnowledgeCreateRequest(BaseModel):
    question: str
    answer: str


class KnowledgeUpdateRequest(BaseModel):
    answer: str


# ── Unanswered Pool ─────────────────────────────────────────


class UnansweredEntry(BaseModel):
    question_id: str
    question: str
    general_response: str
    created_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    status: str = "pending"  # "pending" | "reviewed"


# ── Session Transcripts ─────────────────────────────────────


class SessionTranscript(BaseModel):
    session_id: str
    title: str
    transcript: str
    created_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    processed: bool = False


class SessionUploadRequest(BaseModel):
    title: str
    transcript: str


# ── Chat ────────────────────────────────────────────────────


class ChatRequest(BaseModel):
    text: str | None = None  # text query (alternative to audio)


class AnswerType(str, Enum):
    NEW = "new"
    KNOWN = "known"


class ChatResponse(BaseModel):
    answer_type: AnswerType
    text: str
    audio_base64: str | None = None
    times_asked: int | None = None  # for known questions


# ── Admin ───────────────────────────────────────────────────


class ReviewAnswerRequest(BaseModel):
    question_id: str
    answer: str


class ApproveAnswerRequest(BaseModel):
    question_id: str
