# TalkingHeadAI

Real-time conversational talking-head agent with voice I/O, animated avatar, and dynamically evolving knowledge base.

## Architecture

```
┌─────────────────┐         ┌──────────────────────────────┐
│  Flutter Web    │◄──REST──►│  FastAPI Backend              │
│  (Talking Head) │  + WS   │                              │
│                 │         │  ┌──────────┐ ┌────────────┐ │
│  • Chat UI      │         │  │ OpenAI   │ │ ElevenLabs │ │
│  • Admin Panel  │         │  │ GPT-4o-m │ │   TTS      │ │
│  • 2D Avatar    │         │  └──────────┘ └────────────┘ │
│                 │         │  ┌──────────┐ ┌────────────┐ │
└─────────────────┘         │  │  Whisper  │ │   FAISS    │ │
                            │  │   STT    │ │  (vectors) │ │
                            │  └──────────┘ └────────────┘ │
                            │  ┌─────────────────────────┐ │
                            │  │       DynamoDB           │ │
                            │  │ knowledge | unanswered   │ │
                            │  │ sessions                 │ │
                            │  └─────────────────────────┘ │
                            └──────────────────────────────┘
```

## Two-Mode Answering

| Mode | Trigger | Response |
|------|---------|----------|
| **Known** | Question matches KB (cosine similarity ≥ 0.82) | Exact answer + "X people have asked this" |
| **New** | No match found | General RAG response + stored in unanswered pool |

## Knowledge Base Sources

1. **Mentor (Jack)** — Reviews unanswered pool, provides authoritative answers via Admin Panel
2. **Session transcripts** — Mentor–mentee call transcripts ingested for RAG context enrichment

## Setup

### Backend

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # Fill in your API keys
uvicorn app.main:app --reload --port 8000
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/chat/text` | Text chat → text + audio response |
| POST | `/api/chat/voice` | Voice chat → text + audio response |
| WS | `/ws/chat` | Real-time WebSocket voice chat |
| GET | `/api/knowledge/` | List all KB entries |
| POST | `/api/knowledge/` | Add KB entry |
| PUT | `/api/knowledge/{id}` | Update KB entry |
| GET | `/api/admin/unanswered` | List unanswered questions |
| POST | `/api/admin/review` | Mentor reviews & answers a question |
| POST | `/api/sessions/upload` | Upload session transcript |
| POST | `/api/sessions/{id}/process` | Index transcript into FAISS |

## Environment Variables

See `backend/.env.example` for all required keys:
- `OPENAI_API_KEY` — GPT-4o-mini + Whisper + embeddings
- `ELEVENLABS_API_KEY` — Text-to-speech
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — DynamoDB access
