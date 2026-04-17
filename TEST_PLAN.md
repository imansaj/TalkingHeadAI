# TalkingHeadAI — Manual Test Plan

> **Goal:** Verify all core functional requirements with minimal, focused test cases.

---

## Pre-Test Setup

### Environment Checklist
- [ ] Backend running (`uvicorn app.main:app --host 0.0.0.0 --port 8000`)
- [ ] Frontend running (`flutter run -d chrome`)
- [ ] DynamoDB tables empty (fresh start)
- [ ] FAISS index empty (delete `data/faiss_index/` folder)
- [ ] OpenAI API key valid
- [ ] Test in **Incognito/Private mode**

---

## Seed Data

### Knowledge Base Entries (3 Q&A Pairs)

| # | Question | Answer |
|---|----------|--------|
| 1 | What is machine learning? | Machine learning is a branch of artificial intelligence that enables systems to learn and improve from experience without being explicitly programmed. |
| 2 | What is an API? | An API (Application Programming Interface) is a set of rules and protocols that allows different software applications to communicate with each other. |
| 3 | What is Docker? | Docker is a platform for developing, shipping, and running applications in lightweight, portable containers. Containers package an application with its dependencies. |

### Session Transcript (for RAG enrichment)

**Title:** "Mentor Session — Data Pipelines"

```
Jack: A data pipeline is a series of data processing steps where the output of one step is the input of the next.
Mentee: What tools are commonly used?
Jack: Apache Airflow is popular for orchestrating pipelines. You also have Apache Kafka for real-time streaming.
Mentee: How do you handle failures?
Jack: You need retry logic, dead-letter queues for failed records, and idempotent operations so re-runs don't duplicate data.
```

---

## SECTION 1: API Tests

> Run with `curl` or any HTTP client against `http://localhost:8000`.

| # | Test | Steps | Expected |
|---|------|-------|----------|
| A1 | Health check | `GET /health` | `{"status": "ok"}` |
| A2 | Create KB entry | `POST /api/knowledge/` with Q&A #1 | 200, returns `question_id` |
| A3 | List KB entries | Seed all 3 entries → `GET /api/knowledge/` | Returns 3 entries |
| A4 | Delete KB entry | `DELETE /api/knowledge/{id}` | Entry removed from list |
| A5 | Known question | `POST /api/chat/text` with "What is machine learning?" | `answer_type: "known"`, response includes "X people have asked this question" |
| A6 | Known question (paraphrased) | "Can you explain machine learning?" | `answer_type: "known"` (similarity ≥ 0.75) |
| A7 | `times_asked` increments | Ask "What is an API?" 3 times | `times_asked` goes 1 → 2 → 3 |
| A8 | New question | "What is quantum computing?" | `answer_type: "new"`, response starts with "This is a new question. I will give you a general response." |
| A9 | New question in unanswered | After A8, `GET /api/admin/unanswered` | Contains "What is quantum computing?" with status "pending" |
| A10 | Mentor reviews question | `POST /api/admin/review` with question_id + custom answer | Entry moved from unanswered to KB |
| A11 | Reviewed question is now known | Ask "What is quantum computing?" again | `answer_type: "known"`, `times_asked: 1` |
| A12 | Approve AI answer | Ask new question → `POST /api/admin/approve` with question_id | AI response promoted to KB |
| A13 | Upload session transcript | `POST /api/sessions/upload` with seed transcript | 200, `session_id` returned |
| A14 | Session enriches responses | Ask "What is Apache Airflow?" | `answer_type: "new"`, response mentions "orchestrating pipelines" (from transcript) |
| A15 | Session does NOT override KB | Add KB entry for "data pipelines", upload transcript, ask about it | `answer_type: "known"`, uses KB answer not transcript |
| A16 | Audio in response | Any chat query | `audio_base64` field is non-null |
| A17 | Streaming chat | `POST /api/chat/stream` with any question | SSE events: `meta` → `sentence` (with audio) → `done` |

---

## SECTION 2: Frontend UI Tests

> Run in Chrome Incognito.

| # | Test | Steps | Expected |
|---|------|-------|----------|
| U1 | Page loads | Navigate to `/` | Avatar renders, input field visible, no console errors |
| U2 | Send known question | Type "What is Docker?" → Send | User bubble (right), AI response streams in (left), "Known Answer" tag shown |
| U3 | Send new question | Type "What is Kubernetes?" → Send | "New Question" tag shown |
| U4 | Audio plays | Send any question | Audio plays, avatar mouth animates |
| U5 | Stop Speaking | Click "Stop Speaking" during audio | Audio and animation stop |
| U6 | Empty input blocked | Click Send with empty field | Nothing happens |
| U7 | Admin — Unanswered tab | Navigate to `/admin` | Unanswered questions listed (or empty state) |
| U8 | Admin — Approve answer | Click "Approve" on unanswered entry | Entry moves to Knowledge Base tab |
| U9 | Admin — Submit custom answer | Enter answer text, click Submit | Entry moves to KB with mentor's answer |
| U10 | Admin — KB tab | Switch to KB tab | Lists entries with question, answer, times_asked |
| U11 | Admin — Add KB entry | Click add, fill Q&A, submit | New entry appears |
| U12 | Admin — Sessions tab | Upload transcript via UI | Session appears, marked processed |
| U13 | Avatar idle vs speaking | Observe before/after sending question | Idle: mouth closed, blinking. Speaking: mouth moves, head bobs |

---

## SECTION 3: End-to-End Workflow

> The single critical path that validates all core requirements.

| Step | Action | Verify |
|------|--------|--------|
| 1 | Clear all data | `DELETE /api/knowledge/`, `/api/admin/unanswered`, `/api/sessions/` |
| 2 | Seed KB with 3 entries via Admin UI or API | All 3 appear in KB tab |
| 3 | Chat: "What is machine learning?" | `answer_type: "known"`, `times_asked: 1`, audio plays, avatar animates |
| 4 | Chat: "What is Kubernetes?" | `answer_type: "new"`, prefix "This is a new question...", audio plays |
| 5 | Admin: review "What is Kubernetes?" with a custom answer | Entry moves from Unanswered to KB |
| 6 | Chat: "What is Kubernetes?" again | `answer_type: "known"`, `times_asked: 1` |
| 7 | Admin: upload data pipelines transcript | Session created and processed |
| 8 | Chat: "What is Apache Airflow?" | `answer_type: "new"`, response references transcript content (pipelines, orchestrating) |
| 9 | Add KB entry "What is a data pipeline?" with a mentor answer | Entry created |
| 10 | Chat: "What is a data pipeline?" | `answer_type: "known"` — KB answer used, NOT session transcript |

---

## Final Checklist

- [ ] Known questions return `answer_type: "known"` with `times_asked` counter
- [ ] New questions return `answer_type: "new"` with "This is a new question..." prefix
- [ ] New questions appear in unanswered pool for mentor review
- [ ] Mentor review (custom answer) promotes question to known
- [ ] Mentor approve (AI answer) promotes question to known
- [ ] Session transcripts enrich general responses via RAG context
- [ ] Session content does NOT override mentor-approved KB answers
- [ ] Audio plays and avatar animates during responses
- [ ] `times_asked` increments correctly across repeated queries
- [ ] All state is server-side (no browser caching issues)
