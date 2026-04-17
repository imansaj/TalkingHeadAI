# TalkingHeadAI — Comprehensive Test Plan

> **Goal:** Verify every functional requirement across multiple browsers (Chrome, Firefox, Safari, Edge) to eliminate false positives from cached/local data.

---

## Pre-Test Setup

### Environment Checklist
- [ ] Backend running (`uvicorn app.main:app --host 0.0.0.0 --port 8000`)
- [ ] Frontend running (`flutter run -d chrome`)
- [ ] DynamoDB tables empty (fresh start)
- [ ] FAISS index empty (delete `data/faiss_index/` folder)
- [ ] OpenAI API key valid
- [ ] Test in **Incognito/Private mode** in each browser

### Browser Matrix
| Browser | Version | Incognito | Result |
|---------|---------|-----------|--------|
| Chrome  | latest  | Yes       |        |
| Firefox | latest  | Yes       |        |
| Safari  | latest  | Yes       |        |
| Edge    | latest  | Yes       |        |

### Cross-Browser Gotchas to Watch For
- **IndexedDB / localStorage leaks** — always use incognito
- **AudioContext autoplay policies** — Safari/Chrome block autoplay until user gesture
- **WebSocket connection handling** — Firefox may differ in close codes
- **SSE (EventSource) reconnection** — varies by browser
- **Clipboard API** — Safari requires user gesture, Firefox needs permissions
- **base64 audio Data URI playback** — Edge/Safari may handle differently
- **CSS rendering** — CustomPaint canvas differences

---

## SECTION 1: Seed Data — Questions & Authoritative Answers

Use these exact Q&A pairs to populate the knowledge base before testing "known question" flows.

### Knowledge Base Entries (10 Approved Q&A Pairs)

| # | Question | Authoritative Answer | Source |
|---|----------|---------------------|--------|
| 1 | What is machine learning? | Machine learning is a branch of artificial intelligence that enables systems to learn and improve from experience without being explicitly programmed. It focuses on algorithms that can access data and use it to learn for themselves. | mentor |
| 2 | What is Python used for? | Python is a general-purpose programming language used for web development, data science, machine learning, automation, scripting, and scientific computing. Its readability and large ecosystem make it popular across many domains. | mentor |
| 3 | How does a neural network work? | A neural network consists of layers of interconnected nodes (neurons). Each connection has a weight. Input data flows through layers, gets multiplied by weights, summed, and passed through activation functions. Through backpropagation, weights are adjusted to minimize prediction error. | mentor |
| 4 | What is the difference between SQL and NoSQL? | SQL databases are relational, use structured schemas with tables and rows, and support ACID transactions. NoSQL databases are non-relational, offer flexible schemas (document, key-value, graph, column-family), and are optimized for horizontal scaling and unstructured data. | mentor |
| 5 | What is an API? | An API (Application Programming Interface) is a set of rules and protocols that allows different software applications to communicate with each other. It defines the methods and data formats for requesting and exchanging information between systems. | mentor |
| 6 | What is Docker? | Docker is a platform for developing, shipping, and running applications in lightweight, portable containers. Containers package an application with its dependencies, ensuring consistent behavior across development, testing, and production environments. | mentor |
| 7 | What is version control? | Version control is a system that records changes to files over time so you can recall specific versions later. Git is the most popular version control system, enabling collaboration, branching, merging, and tracking the complete history of a codebase. | mentor |
| 8 | What is cloud computing? | Cloud computing is the delivery of computing services including servers, storage, databases, networking, software, and analytics over the internet. It offers faster innovation, flexible resources, and economies of scale compared to on-premises infrastructure. | mentor |
| 9 | What is agile methodology? | Agile is an iterative approach to software development that delivers work in small increments called sprints. It emphasizes collaboration, customer feedback, continuous improvement, and the ability to adapt to changing requirements throughout the development process. | mentor |
| 10 | What is a REST API? | A REST (Representational State Transfer) API is an architectural style for designing networked applications. It uses standard HTTP methods (GET, POST, PUT, DELETE), is stateless, and resources are identified by URIs. Data is typically exchanged in JSON format. | mentor |

### Session Transcript (for RAG context enrichment)

**Title:** "Mentor Session — Introduction to Data Pipelines"

**Transcript:**
```
Jack: Today let's talk about data pipelines. A data pipeline is a series of data processing steps where the output of one step is the input of the next. They're used to move data from source systems to destinations like data warehouses.

Mentee: What tools are commonly used?

Jack: Apache Airflow is popular for orchestrating pipelines. You also have Apache Kafka for real-time streaming, and tools like dbt for transforming data in the warehouse. AWS has services like Glue and Step Functions too.

Mentee: What about data quality?

Jack: Great question. Data quality checks should be embedded at each stage. You validate schema, check for nulls, duplicates, and outliers. Tools like Great Expectations can automate these validations. Without quality gates, bad data propagates downstream.

Mentee: How do you handle failures?

Jack: You need retry logic, dead-letter queues for failed records, alerting, and idempotent operations so re-runs don't duplicate data. Observability is key — log everything, monitor lag, and set up dashboards.
```

---

## SECTION 2: API-Level Test Cases

### 2.1 Health Check

| TC# | Test Case | Steps | Expected Result | Cross-Browser |
|-----|-----------|-------|-----------------|---------------|
| API-01 | Health endpoint returns OK | `GET /health` | `{"status": "ok", "faiss_vectors": 0}` (on fresh DB) | N/A (API) |
| API-02 | Health after seeding | Seed 10 entries + 1 session → `GET /health` | `faiss_vectors` > 0 | N/A |

### 2.2 Knowledge Base CRUD

| TC# | Test Case | Steps | Expected Result |
|-----|-----------|-------|-----------------|
| KB-01 | Create knowledge entry | `POST /api/knowledge/` with Q&A #1 from table above | 200, returns `question_id` |
| KB-02 | Create all 10 entries | POST each of the 10 Q&A pairs | All return 200 |
| KB-03 | List all entries | `GET /api/knowledge/` | Returns 10 entries, each with `question`, `answer`, `times_asked=0` |
| KB-04 | Update an answer | `PUT /api/knowledge/{id}` change answer for Q#1 | 200, answer updated on subsequent GET |
| KB-05 | Delete single entry | `DELETE /api/knowledge/{id}` | 200, entry removed from list |
| KB-06 | Re-create deleted entry | POST the deleted Q&A again | 200, new `question_id` |
| KB-07 | Delete all entries | `DELETE /api/knowledge/` | 200, GET returns empty list |
| KB-08 | Create entry with empty question | `POST /api/knowledge/` with `question: ""` | 422 validation error |
| KB-09 | Create entry with empty answer | `POST /api/knowledge/` with `answer: ""` | 422 validation error |
| KB-10 | Create duplicate question | POST same question twice | Both succeed (no uniqueness constraint) |

### 2.3 Chat — Two-Mode Answering

| TC# | Test Case | Steps | Expected Result |
|-----|-----------|-------|-----------------|
| CHAT-01 | Known question (exact match) | Seed KB → `POST /api/chat/text` with "What is machine learning?" | `answer_type: "known"`, `times_asked: 1`, response starts with "1 people have asked this question" |
| CHAT-02 | Known question (paraphrased) | "Can you explain what machine learning is?" | `answer_type: "known"` (if similarity ≥ 0.75) |
| CHAT-03 | Known question counter increment | Ask "What is machine learning?" 3 times | `times_asked` increments: 1 → 2 → 3 |
| CHAT-04 | New question (no match) | "What is quantum entanglement?" (not in KB) | `answer_type: "new"`, response starts with "This is a new question. I will give you a general response." |
| CHAT-05 | New question stored in unanswered | After CHAT-04, `GET /api/admin/unanswered` | Contains "What is quantum entanglement?" with status "pending" |
| CHAT-06 | New question added to FAISS | After CHAT-04, ask same question again | Should match in RAG (score may now be ≥ 0.75 since it was indexed) |
| CHAT-07 | Borderline similarity | Ask a question very similar but not identical to a KB entry | Observe: does score cross 0.75 threshold? Check `answer_type` |
| CHAT-08 | Completely unrelated question | "What is the recipe for chocolate cake?" | `answer_type: "new"`, general response from any available context |
| CHAT-09 | Empty question | `POST /api/chat/text` with `text: ""` | 422 or graceful error |
| CHAT-10 | Very long question (1000+ chars) | POST with extremely long text | Should handle without crashing; may truncate context |
| CHAT-11 | Special characters in question | "What is C++ & how does <template> work?" | No HTML injection, proper response |
| CHAT-12 | Unicode question | "¿Qué es el aprendizaje automático?" | Handles gracefully, returns English response |
| CHAT-13 | Audio in response | Any chat query | `audio_base64` field is non-null, valid base64-encoded MP3 |

### 2.4 Streaming Chat (SSE)

| TC# | Test Case | Steps | Expected Result |
|-----|-----------|-------|-----------------|
| SSE-01 | Stream known answer | `POST /api/chat/stream` with known question | Events: `meta` (answer_type=known) → multiple `sentence` → `done` |
| SSE-02 | Stream new answer | `POST /api/chat/stream` with new question | Events: `meta` (answer_type=new) → `sentence` with prefix → more `sentence` → `done` |
| SSE-03 | Each sentence has audio | Inspect every `sentence` event | Each has `text` and `audio_base64` |
| SSE-04 | Done event has full text | Check `done` event data | `full_text` matches concatenation of all sentence texts |
| SSE-05 | Stream timeout | Send query that takes very long | No timeout before 120s |
| SSE-06 | Multiple concurrent streams | Open 3 tabs, send queries simultaneously | All complete independently without interference |

### 2.5 Voice Chat

| TC# | Test Case | Steps | Expected Result |
|-----|-----------|-------|-----------------|
| VOICE-01 | Upload audio file | `POST /api/chat/voice` with a .webm file saying "What is Python?" | Transcription matches, response is "known" |
| VOICE-02 | Upload empty audio | POST with 0-byte file | Error response, no crash |
| VOICE-03 | Upload non-audio file | POST with a .txt file | Error response |

### 2.6 WebSocket Chat

| TC# | Test Case | Steps | Expected Result |
|-----|-----------|-------|-----------------|
| WS-01 | Text message | Connect to `ws://localhost:8000/ws/chat`, send `{"type":"text","text":"What is Docker?"}` | JSON response with `answer_type`, `text`, `audio_base64` |
| WS-02 | Binary audio message | Send raw audio bytes | Response with transcribed question and answer |
| WS-03 | Multiple messages on same connection | Send 3 different questions sequentially | 3 separate responses, each correct |
| WS-04 | Connection close handling | Close WebSocket mid-response | Server handles gracefully, no crash |
| WS-05 | Invalid JSON text message | Send `{"invalid": true}` | Error response or graceful handling |
| WS-06 | Reconnection | Close and reopen WebSocket | New connection works, no stale state |

### 2.7 Admin — Unanswered Queue

| TC# | Test Case | Steps | Expected Result |
|-----|-----------|-------|-----------------|
| ADMIN-01 | List empty unanswered | `GET /api/admin/unanswered` (fresh) | Empty list |
| ADMIN-02 | Question appears after new query | Ask a new question via chat, then GET unanswered | Question in list with status "pending", `general_response` populated |
| ADMIN-03 | Review with custom answer | `POST /api/admin/review` with question_id and Jack's answer | Entry removed from unanswered, added to knowledge base |
| ADMIN-04 | Verify reviewed answer works | After ADMIN-03, ask the same question via chat | `answer_type: "known"`, `times_asked: 1` |
| ADMIN-05 | Approve AI response | `POST /api/admin/approve` with question_id | AI's general response promoted to knowledge base |
| ADMIN-06 | Verify approved answer works | After ADMIN-05, ask same question | `answer_type: "known"` |
| ADMIN-07 | Delete unanswered | `DELETE /api/admin/unanswered/{id}` | Entry removed |
| ADMIN-08 | Delete all unanswered | `DELETE /api/admin/unanswered` | All entries removed |
| ADMIN-09 | Review non-existent question | POST review with fake question_id | 404 or error |

### 2.8 Sessions (Transcript Upload)

| TC# | Test Case | Steps | Expected Result |
|-----|-----------|-------|-----------------|
| SESS-01 | Upload session transcript | `POST /api/sessions/upload` with title + transcript text from seed data | 200, session_id returned, `processed: true` |
| SESS-02 | List sessions | `GET /api/sessions/` | Contains uploaded session |
| SESS-03 | Session enriches RAG | After upload, ask "What tools are used for data pipelines?" | Response references Airflow, Kafka, dbt (from transcript) |
| SESS-04 | Session doesn't override KB | Add KB entry for "data pipelines", upload transcript, query | Known answer from KB used, not session content |
| SESS-05 | Re-process session | `POST /api/sessions/{id}/process` | 200, re-indexed |
| SESS-06 | Delete session | `DELETE /api/sessions/{id}` | Session removed |
| SESS-07 | Delete all sessions | `DELETE /api/sessions/` | All removed |
| SESS-08 | Upload empty transcript | POST with `transcript: ""` | 422 or graceful error |
| SESS-09 | Upload very large transcript | POST with 50,000+ character transcript | Handles chunking correctly, no timeout |

---

## SECTION 3: Frontend UI Test Cases (Cross-Browser)

> **Run every test in EACH browser (Chrome, Firefox, Safari, Edge), all in Incognito/Private mode.**

### 3.1 Chat Screen

| TC# | Test Case | Steps | Expected (verify in each browser) |
|-----|-----------|-------|-----------------------------------|
| UI-01 | Page loads | Navigate to `/` | Avatar renders, input field visible, no console errors |
| UI-02 | Send text message | Type "What is Python?" → click Send | User bubble appears (right, blue), AI response streams in (left, dark) |
| UI-03 | Known answer tag | Ask a seeded question | `📚 Known Answer` tag appears, "Asked N times" shown |
| UI-04 | New answer tag | Ask unknown question | `✨ New Question` tag appears, no times_asked counter |
| UI-05 | Audio plays automatically | Send any question | Audio plays after user gesture; avatar mouth animates |
| UI-06 | Stop Speaking button | While audio plays, click "Stop Speaking" | Audio stops, avatar stops animating |
| UI-07 | Copy message | Click copy icon on a message | Text copied to clipboard (verify with paste), snackbar appears for 1s |
| UI-08 | Multiple messages | Send 5 different questions | All messages visible in scroll, order preserved |
| UI-09 | Scroll behavior | Send many messages until scrolling needed | Auto-scrolls to latest message |
| UI-10 | Empty input prevention | Click Send with empty input | Nothing happens (no empty message sent) |
| UI-11 | Input while streaming | Send a question, immediately type another | Second input should wait or queue properly |
| UI-12 | Loading indicators | Send question, observe | "Thinking..." then "Streaming..." indicators visible |
| UI-13 | Long response rendering | Ask question that produces long answer | Text wraps properly, max 70% width, no overflow |

### 3.2 Avatar / Talking Head Widget

| TC# | Test Case | Steps | Expected (verify in each browser) |
|-----|-----------|-------|-----------------------------------|
| AVA-01 | Avatar renders | Load page | 200x200 Memoji-style face visible with hair, eyes, mouth, ears |
| AVA-02 | Idle state | No audio playing | Mouth closed (gentle smile), eyes open, occasional blinking |
| AVA-03 | Speaking animation | Audio playing | Mouth opens/closes, head bobs, purple glow visible |
| AVA-04 | Blinking during speech | Watch during long response | Eyes blink randomly every 2.5-6s |
| AVA-05 | Animation stops | Audio ends or "Stop Speaking" clicked | All animations stop, mouth returns to closed smile |
| AVA-06 | Canvas rendering | Inspect for visual artifacts | No clipping, correct proportions, drop shadow visible |
| AVA-07 | Different window sizes | Resize window | Avatar scales appropriately or maintains fixed size |

### 3.3 Admin Screen

| TC# | Test Case | Steps | Expected (verify in each browser) |
|-----|-----------|-------|-----------------------------------|
| ADM-01 | Navigate to admin | Go to `/admin` | Three tabs visible: Unanswered, Knowledge Base, Sessions |
| ADM-02 | Unanswered tab — empty | No new questions asked | "No unanswered questions" or empty state |
| ADM-03 | Unanswered tab — populated | Ask new questions first, then visit admin | Questions listed with AI-generated responses |
| ADM-04 | Approve AI answer (UI) | Click "Approve" on an unanswered question | Entry moves to Knowledge Base tab, removed from Unanswered |
| ADM-05 | Submit custom answer (UI) | Enter answer text, click Submit | Entry moves to KB with Jack's answer |
| ADM-06 | Delete unanswered (UI) | Click delete on an entry | Entry removed from list |
| ADM-07 | Knowledge Base tab | Switch to KB tab | Lists all approved entries with Q, A, times_asked, source |
| ADM-08 | Add new KB entry (UI) | Click add, fill Q&A, submit | Entry appears in list |
| ADM-09 | Edit KB answer (UI) | Click edit, change answer, save | Answer updated |
| ADM-10 | Delete KB entry (UI) | Click delete on an entry | Entry removed |
| ADM-11 | Sessions tab — upload | Enter title and paste transcript, click Upload | Session appears in list, marked "✓ Processed" |
| ADM-12 | Sessions tab — process | If unprocessed, click Process | Status changes to processed |
| ADM-13 | Sessions tab — delete | Click delete on a session | Session removed |
| ADM-14 | Copy buttons | Click copy on Q or A | Clipboard contains text, snackbar shown |
| ADM-15 | Tab switching state | Switch between tabs rapidly | No data loss, no loading glitches |
| ADM-16 | Bulk delete all (each tab) | Click "Delete All" on each tab | Confirmation → all entries cleared |

---

## SECTION 4: End-to-End Workflow Tests

> These test the complete user journey across multiple steps. **Run each in a fresh incognito session per browser.**

### E2E-01: Full New Question → Mentor Review → Known Question Cycle

| Step | Action | Verification |
|------|--------|-------------|
| 1 | Clear all data (DELETE /api/knowledge/, DELETE /api/admin/unanswered, DELETE /api/sessions/) | All empty |
| 2 | Open Chat screen in Browser A (Chrome incognito) | Page loads |
| 3 | Ask: "What is Kubernetes?" | `answer_type: "new"`, prefix "This is a new question..." |
| 4 | Open Admin screen in Browser B (Firefox incognito) | Unanswered tab shows "What is Kubernetes?" |
| 5 | Jack provides answer: "Kubernetes is an open-source container orchestration platform that automates deployment, scaling, and management of containerized applications." | Entry moves to KB |
| 6 | Go back to Chat in Browser A, ask: "What is Kubernetes?" | `answer_type: "known"`, `times_asked: 1`, answer is Jack's exact answer reformulated |
| 7 | Ask same question in Browser C (Safari incognito) | `answer_type: "known"`, `times_asked: 2` |
| 8 | Ask same question in Browser D (Edge incognito) | `answer_type: "known"`, `times_asked: 3` |

**Cross-browser validation:** times_asked must increment globally (server-side), NOT be cached per browser.

### E2E-02: Session Transcript Enriches General Responses

| Step | Action | Verification |
|------|--------|-------------|
| 1 | Clear all data | Fresh state |
| 2 | Upload the data pipelines transcript via Admin | Session created and processed |
| 3 | Ask: "What is Apache Airflow?" in Chat | `answer_type: "new"`, response should mention "orchestrating pipelines" (from transcript context) |
| 4 | Ask: "How do you handle data quality?" | `answer_type: "new"`, response should reference "Great Expectations", "schema validation" (from transcript) |

### E2E-03: Session Does NOT Override Mentor-Approved Answers

| Step | Action | Verification |
|------|--------|-------------|
| 1 | Add KB entry: Q="What is data quality?" A="Data quality is the measure of data's fitness for its intended use." | Entry created |
| 2 | Upload transcript mentioning data quality (the seed transcript) | Session processed |
| 3 | Ask: "What is data quality?" | `answer_type: "known"`, answer based on KB entry (mentor's answer), NOT session transcript |

### E2E-04: Approve AI Response Flow

| Step | Action | Verification |
|------|--------|-------------|
| 1 | Ask: "What is serverless computing?" | `answer_type: "new"`, general response generated |
| 2 | Open Admin → Unanswered tab | See "What is serverless computing?" with AI general_response |
| 3 | Click "Approve AI Answer" | Entry promoted to KB |
| 4 | Ask: "What is serverless computing?" again | `answer_type: "known"`, `times_asked: 1` |

### E2E-05: Multiple New Questions Queued

| Step | Action | Verification |
|------|--------|-------------|
| 1 | Ask 5 new questions rapidly (different topics) | All get `answer_type: "new"` |
| 2 | Check unanswered queue | All 5 present with status "pending" |
| 3 | Review 2 with custom answers, approve 1, delete 2 | Queue has 0 remaining; KB has 3 new entries |

### E2E-06: Cross-Browser State Consistency

| Step | Action | Verification |
|------|--------|-------------|
| 1 | Seed 10 KB entries | All present |
| 2 | In Chrome: ask "What is an API?" | known, times_asked: 1 |
| 3 | In Firefox: ask "What is an API?" | known, times_asked: 2 (NOT 1) |
| 4 | In Safari: ask "What is an API?" | known, times_asked: 3 (NOT 1) |
| 5 | In Edge: delete "What is an API?" from KB via Admin | Entry removed |
| 6 | In Chrome: ask "What is an API?" | answer_type: "new" (entry was deleted) |

**This confirms NO browser-local caching of KB state.**

---

## SECTION 5: Cross-Browser Specific Tests

### 5.1 Audio Playback

| TC# | Test Case | Chrome | Firefox | Safari | Edge |
|-----|-----------|--------|---------|--------|------|
| XB-01 | First audio plays after user gesture | Test | Test | Test (strict) | Test |
| XB-02 | base64 MP3 plays correctly | Test | Test | Test | Test |
| XB-03 | Sequential sentence audio | Test | Test | Test | Test |
| XB-04 | Stop mid-playback | Test | Test | Test | Test |
| XB-05 | Audio after tab switch and return | Test | Test | Test | Test |

### 5.2 WebSocket Connectivity

| TC# | Test Case | Chrome | Firefox | Safari | Edge |
|-----|-----------|--------|---------|--------|------|
| XB-06 | WS connects | Test | Test | Test | Test |
| XB-07 | WS reconnects after drop | Test | Test | Test | Test |
| XB-08 | WS binary frame support | Test | Test | Test | Test |

### 5.3 SSE (Server-Sent Events)

| TC# | Test Case | Chrome | Firefox | Safari | Edge |
|-----|-----------|--------|---------|--------|------|
| XB-09 | SSE stream received fully | Test | Test | Test | Test |
| XB-10 | SSE concurrent with UI updates | Test | Test | Test | Test |
| XB-11 | SSE with long response (>30s) | Test | Test | Test | Test |

### 5.4 Clipboard

| TC# | Test Case | Chrome | Firefox | Safari | Edge |
|-----|-----------|--------|---------|--------|------|
| XB-12 | Copy message to clipboard | Test | Test | Test (requires gesture) | Test |
| XB-13 | Copy from admin panel | Test | Test | Test | Test |

### 5.5 Rendering

| TC# | Test Case | Chrome | Firefox | Safari | Edge |
|-----|-----------|--------|---------|--------|------|
| XB-14 | Avatar canvas renders | Test | Test | Test | Test |
| XB-15 | Chat bubbles layout | Test | Test | Test | Test |
| XB-16 | Dark theme consistency | Test | Test | Test | Test |
| XB-17 | Admin tabs render | Test | Test | Test | Test |
| XB-18 | Responsive at 1024px width | Test | Test | Test | Test |
| XB-19 | Responsive at 768px width | Test | Test | Test | Test |

---

## SECTION 6: Edge Cases & Stress Tests

| TC# | Test Case | Steps | Expected |
|-----|-----------|-------|----------|
| EDGE-01 | Ask the same new question 10 times | Rapid fire same unknown question | Should not create 10 unanswered entries (or should — verify behavior) |
| EDGE-02 | Ask question while backend is down | Stop backend, send from frontend | Graceful error message, no crash |
| EDGE-03 | Network disconnect during stream | Start streaming, disconnect network | Frontend shows error or partial response, no freeze |
| EDGE-04 | Concurrent admin + chat | One user chats, another reviews in admin simultaneously | No race conditions on times_asked or unanswered queue |
| EDGE-05 | Delete KB entry while being queried | Delete entry while a chat for that question is in-flight | Graceful handling |
| EDGE-06 | 100+ KB entries | Add 100 entries, query | FAISS handles correctly, response time acceptable |
| EDGE-07 | Special chars in KB answer | KB answer contains `<script>alert('xss')</script>` | Rendered as text, NOT executed |
| EDGE-08 | XSS in question field | User asks `<img onerror=alert(1) src=x>` | Sanitized in UI, no script execution |
| EDGE-09 | SQL/NoSQL injection in question | Ask `"; DROP TABLE knowledge; --` | No impact on DynamoDB |
| EDGE-10 | Rapid tab switching (admin) | Switch tabs 20 times quickly | No duplicate API calls, no UI state corruption |
| EDGE-11 | Upload 10 sessions, query | Upload many transcripts, ask related question | All session content available in RAG context |
| EDGE-12 | FAISS rebuild from DB | Delete FAISS index files, restart server | Index rebuilt from DynamoDB, all queries still work |

---

## SECTION 7: Test Questions Organized by Expected Behavior

### Questions That MUST Return "known" (after seeding KB)

| # | Question (verbatim) | Expected times_asked on first ask |
|---|---------------------|----------------------------------|
| 1 | What is machine learning? | 1 |
| 2 | What is Python used for? | 1 |
| 3 | How does a neural network work? | 1 |
| 4 | What is the difference between SQL and NoSQL? | 1 |
| 5 | What is an API? | 1 |
| 6 | What is Docker? | 1 |
| 7 | What is version control? | 1 |
| 8 | What is cloud computing? | 1 |
| 9 | What is agile methodology? | 1 |
| 10 | What is a REST API? | 1 |

### Paraphrased Questions That SHOULD Return "known" (similarity ≥ 0.75)

| # | Paraphrased Question | Target KB Entry |
|---|---------------------|-----------------|
| 1 | Can you explain machine learning to me? | #1 |
| 2 | What are the uses of Python? | #2 |
| 3 | Explain how neural networks function | #3 |
| 4 | SQL vs NoSQL — what's the difference? | #4 |
| 5 | Define API for me | #5 |
| 6 | What does Docker do? | #6 |
| 7 | Tell me about version control systems | #7 |
| 8 | Explain cloud computing | #8 |
| 9 | What is agile in software development? | #9 |
| 10 | How does a REST API work? | #10 |

### Questions That MUST Return "new" (not in KB)

| # | Question | Why It's New |
|---|----------|-------------|
| 1 | What is quantum computing? | Not in KB |
| 2 | How do I bake a sourdough bread? | Completely unrelated domain |
| 3 | What is blockchain technology? | Not in KB |
| 4 | Explain the theory of relativity | Not in KB |
| 5 | What programming language should I learn first? | Meta-question, not direct match |
| 6 | What is Kubernetes? | Not in KB |
| 7 | How does WiFi work? | Not in KB |
| 8 | What is the meaning of life? | Philosophical, not in KB |
| 9 | What is WebAssembly? | Not in KB |
| 10 | How do I set up a CI/CD pipeline? | Not in KB |

### Session-Enriched Questions (after uploading data pipeline transcript)

| # | Question | Expected Source | Should Mention |
|---|----------|----------------|----------------|
| 1 | What is a data pipeline? | Session context | "series of data processing steps" |
| 2 | What is Apache Airflow? | Session context | "orchestrating pipelines" |
| 3 | How do you handle failures in data pipelines? | Session context | "retry logic", "dead-letter queues" |
| 4 | What is Great Expectations? | Session context | "data quality", "validations" |

---

## SECTION 8: Data Integrity Verification Across Browsers

### Test Protocol for Eliminating Local Cache False Positives

**Critical principle:** All state (KB entries, unanswered queue, times_asked, sessions) MUST come from the server (DynamoDB + FAISS). If any browser shows different data, there's a caching bug.

| TC# | Test | Protocol |
|-----|------|----------|
| CACHE-01 | KB state identical across browsers | Add entry in Chrome admin → verify in Firefox admin → verify in Safari admin |
| CACHE-02 | Unanswered state identical | Ask new Q in Chrome → check unanswered in Firefox → check in Safari |
| CACHE-03 | times_asked is global | Ask Q in Chrome (times=1) → ask in Firefox (times=2) → verify in Edge (times=2 via admin) |
| CACHE-04 | Deleted items gone everywhere | Delete in Chrome → refresh in Firefox → item gone |
| CACHE-05 | Session upload visible everywhere | Upload in Safari → see in Chrome admin → see in Edge admin |
| CACHE-06 | No stale data after refresh | Modify data via API → hard refresh in all browsers → all show new data |
| CACHE-07 | Incognito vs normal | Repeat key tests in incognito AND normal mode — results must be identical |
| CACHE-08 | Clear browser data | Clear all site data → reload → app still works (no dependency on localStorage) |

---

## SECTION 9: Automated Test Script (API-level)

Use this `curl` script to quickly verify API behavior. Run from any terminal — results are independent of browser.

```bash
#!/bin/bash
BASE_URL="http://localhost:8000"

echo "=== 1. Health Check ==="
curl -s "$BASE_URL/health" | python3 -m json.tool

echo -e "\n=== 2. Clear All Data ==="
curl -s -X DELETE "$BASE_URL/api/knowledge/"
curl -s -X DELETE "$BASE_URL/api/admin/unanswered"
curl -s -X DELETE "$BASE_URL/api/sessions/"

echo -e "\n=== 3. Seed Knowledge Base ==="
declare -a QUESTIONS=(
  "What is machine learning?"
  "What is Python used for?"
  "How does a neural network work?"
  "What is the difference between SQL and NoSQL?"
  "What is an API?"
  "What is Docker?"
  "What is version control?"
  "What is cloud computing?"
  "What is agile methodology?"
  "What is a REST API?"
)

declare -a ANSWERS=(
  "Machine learning is a branch of artificial intelligence that enables systems to learn and improve from experience without being explicitly programmed. It focuses on algorithms that can access data and use it to learn for themselves."
  "Python is a general-purpose programming language used for web development, data science, machine learning, automation, scripting, and scientific computing. Its readability and large ecosystem make it popular across many domains."
  "A neural network consists of layers of interconnected nodes (neurons). Each connection has a weight. Input data flows through layers, gets multiplied by weights, summed, and passed through activation functions. Through backpropagation, weights are adjusted to minimize prediction error."
  "SQL databases are relational, use structured schemas with tables and rows, and support ACID transactions. NoSQL databases are non-relational, offer flexible schemas (document, key-value, graph, column-family), and are optimized for horizontal scaling and unstructured data."
  "An API (Application Programming Interface) is a set of rules and protocols that allows different software applications to communicate with each other. It defines the methods and data formats for requesting and exchanging information between systems."
  "Docker is a platform for developing, shipping, and running applications in lightweight, portable containers. Containers package an application with its dependencies, ensuring consistent behavior across development, testing, and production environments."
  "Version control is a system that records changes to files over time so you can recall specific versions later. Git is the most popular version control system, enabling collaboration, branching, merging, and tracking the complete history of a codebase."
  "Cloud computing is the delivery of computing services including servers, storage, databases, networking, software, and analytics over the internet. It offers faster innovation, flexible resources, and economies of scale compared to on-premises infrastructure."
  "Agile is an iterative approach to software development that delivers work in small increments called sprints. It emphasizes collaboration, customer feedback, continuous improvement, and the ability to adapt to changing requirements throughout the development process."
  "A REST (Representational State Transfer) API is an architectural style for designing networked applications. It uses standard HTTP methods (GET, POST, PUT, DELETE), is stateless, and resources are identified by URIs. Data is typically exchanged in JSON format."
)

for i in "${!QUESTIONS[@]}"; do
  echo "  Seeding: ${QUESTIONS[$i]}"
  curl -s -X POST "$BASE_URL/api/knowledge/" \
    -H "Content-Type: application/json" \
    -d "{\"question\": \"${QUESTIONS[$i]}\", \"answer\": \"${ANSWERS[$i]}\"}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'    ID: {d.get(\"question_id\", \"ERROR\")}')"
done

echo -e "\n=== 4. Verify KB Count ==="
curl -s "$BASE_URL/api/knowledge/" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Entries: {len(d)}')"

echo -e "\n=== 5. Test KNOWN question ==="
RESPONSE=$(curl -s -X POST "$BASE_URL/api/chat/text" \
  -H "Content-Type: application/json" \
  -d '{"text": "What is machine learning?"}')
echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  answer_type: {d[\"answer_type\"]}')
print(f'  times_asked: {d.get(\"times_asked\")}')
print(f'  text_preview: {d[\"text\"][:100]}...')
print(f'  has_audio: {bool(d.get(\"audio_base64\"))}')
assert d['answer_type'] == 'known', 'FAIL: Expected known!'
print('  ✅ PASS: Known question detected')
"

echo -e "\n=== 6. Test NEW question ==="
RESPONSE=$(curl -s -X POST "$BASE_URL/api/chat/text" \
  -H "Content-Type: application/json" \
  -d '{"text": "What is quantum computing?"}')
echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  answer_type: {d[\"answer_type\"]}')
print(f'  times_asked: {d.get(\"times_asked\")}')
print(f'  text_preview: {d[\"text\"][:100]}...')
assert d['answer_type'] == 'new', 'FAIL: Expected new!'
print('  ✅ PASS: New question detected')
"

echo -e "\n=== 7. Verify unanswered queue ==="
curl -s "$BASE_URL/api/admin/unanswered" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  Unanswered count: {len(d)}')
for item in d:
    print(f'    - {item[\"question\"]} (status: {item[\"status\"]})')
"

echo -e "\n=== 8. Test times_asked increment ==="
for i in 1 2 3; do
  RESPONSE=$(curl -s -X POST "$BASE_URL/api/chat/text" \
    -H "Content-Type: application/json" \
    -d '{"text": "What is Docker?"}')
  TIMES=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('times_asked'))")
  echo "  Ask #$i: times_asked=$TIMES"
done

echo -e "\n=== 9. Upload session transcript ==="
curl -s -X POST "$BASE_URL/api/sessions/upload" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Mentor Session - Data Pipelines",
    "transcript": "Jack: Today let us talk about data pipelines. A data pipeline is a series of data processing steps where the output of one step is the input of the next. They are used to move data from source systems to destinations like data warehouses. Mentee: What tools are commonly used? Jack: Apache Airflow is popular for orchestrating pipelines. You also have Apache Kafka for real-time streaming, and tools like dbt for transforming data in the warehouse."
  }' | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  Session ID: {d.get(\"session_id\", \"ERROR\")}')"

echo -e "\n=== 10. Test session-enriched response ==="
RESPONSE=$(curl -s -X POST "$BASE_URL/api/chat/text" \
  -H "Content-Type: application/json" \
  -d '{"text": "What is Apache Airflow used for?"}')
echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  answer_type: {d[\"answer_type\"]}')
text_lower = d['text'].lower()
if 'pipeline' in text_lower or 'orchestrat' in text_lower:
    print('  ✅ PASS: Session context used in response')
else:
    print('  ⚠️  WARN: Response may not use session context')
print(f'  text_preview: {d[\"text\"][:150]}...')
"

echo -e "\n=== 11. Admin review flow ==="
# Get first unanswered question
Q_ID=$(curl -s "$BASE_URL/api/admin/unanswered" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d: print(d[0]['question_id'])
else: print('NONE')
")
if [ "$Q_ID" != "NONE" ]; then
  echo "  Reviewing question ID: $Q_ID"
  curl -s -X POST "$BASE_URL/api/admin/review" \
    -H "Content-Type: application/json" \
    -d "{\"question_id\": \"$Q_ID\", \"answer\": \"Quantum computing uses quantum bits (qubits) that can exist in superposition, enabling parallel computation for specific problem classes like cryptography and optimization.\"}" \
    | python3 -c "import sys,json; print(f'  Review result: {json.load(sys.stdin)}')"

  echo "  Re-asking reviewed question..."
  RESPONSE=$(curl -s -X POST "$BASE_URL/api/chat/text" \
    -H "Content-Type: application/json" \
    -d '{"text": "What is quantum computing?"}')
  echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  answer_type: {d[\"answer_type\"]}')
print(f'  times_asked: {d.get(\"times_asked\")}')
if d['answer_type'] == 'known':
    print('  ✅ PASS: Reviewed question is now known')
else:
    print('  ❌ FAIL: Should be known after review')
"
fi

echo -e "\n=== 12. Health check (final) ==="
curl -s "$BASE_URL/health" | python3 -m json.tool

echo -e "\n=== DONE ==="
```

---

## SECTION 10: Checklist Summary

### Before Submission, Verify:

- [ ] All 10 seed questions return `answer_type: "known"` in all 4 browsers
- [ ] `times_asked` increments globally across browsers (not per-browser)
- [ ] New questions return `answer_type: "new"` with correct prefix in all browsers
- [ ] New questions appear in admin unanswered queue (visible from any browser)
- [ ] Admin review promotes question to "known" (verifiable from any browser)
- [ ] Admin approve promotes AI response to "known" (verifiable from any browser)
- [ ] Session transcript enriches RAG context (mentioned info appears in general responses)
- [ ] Session content does NOT override mentor-approved KB answers
- [ ] Audio plays in all browsers (after user gesture)
- [ ] Avatar animates during speech in all browsers
- [ ] Stop Speaking works in all browsers
- [ ] No XSS vulnerabilities (special chars rendered as text)
- [ ] No data persists in browser after clearing site data
- [ ] SSE streaming works in all browsers
- [ ] WebSocket works in all browsers
- [ ] Copy to clipboard works in all browsers
- [ ] No console errors in any browser
- [ ] FAISS rebuilds from DB on server restart
