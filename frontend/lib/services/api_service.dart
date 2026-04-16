import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models.dart';

/// Parsed SSE event from the streaming chat endpoint.
class ChatStreamEvent {
  final String type; // "text_chunk", "audio_chunk", "done", "error"
  final Map<String, dynamic> data;

  ChatStreamEvent({required this.type, required this.data});
}

class ApiService {
  static final String _base = AppConfig.baseUrl;

  // ── Chat ──────────────────────────────────────────

  static Future<ChatResponse> chatText(String text) async {
    final resp = await http
        .post(
          Uri.parse('$_base/api/chat/text'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 120));
    if (resp.statusCode != 200) {
      final body = resp.body;
      throw Exception('Chat failed (${resp.statusCode}): $body');
    }
    return ChatResponse.fromJson(jsonDecode(resp.body));
  }

  /// Streaming chat via SSE — returns a stream of events.
  /// Events: text_chunk, audio_chunk, done, error.
  static Stream<ChatStreamEvent> chatStream(String text) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$_base/api/chat/stream'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode({'text': text});

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Stream failed (${response.statusCode})');
      }

      // Parse SSE from byte stream
      String buffer = '';
      String? currentEvent;
      String currentData = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // Process complete lines
        while (buffer.contains('\n')) {
          final newlineIdx = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIdx).trimRight();
          buffer = buffer.substring(newlineIdx + 1);

          if (line.startsWith('event: ')) {
            currentEvent = line.substring(7);
          } else if (line.startsWith('data: ')) {
            currentData = line.substring(6);
          } else if (line.isEmpty && currentEvent != null) {
            // End of event — emit it
            try {
              final data = jsonDecode(currentData) as Map<String, dynamic>;
              yield ChatStreamEvent(type: currentEvent, data: data);
            } catch (_) {
              // Skip malformed events
            }
            currentEvent = null;
            currentData = '';
          }
        }
      }
    } finally {
      client.close();
    }
  }

  // ── Knowledge Base ────────────────────────────────

  static Future<List<KnowledgeEntry>> listKnowledge() async {
    final resp = await http.get(Uri.parse('$_base/api/knowledge/'));
    if (resp.statusCode != 200) throw Exception('Failed to fetch knowledge');
    final list = jsonDecode(resp.body) as List;
    return list.map((e) => KnowledgeEntry.fromJson(e)).toList();
  }

  static Future<void> createKnowledge(String question, String answer) async {
    final resp = await http.post(
      Uri.parse('$_base/api/knowledge/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question, 'answer': answer}),
    );
    if (resp.statusCode != 200) throw Exception('Failed to create entry');
  }

  static Future<void> updateKnowledge(String questionId, String answer) async {
    final resp = await http.put(
      Uri.parse('$_base/api/knowledge/$questionId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'answer': answer}),
    );
    if (resp.statusCode != 200) throw Exception('Failed to update entry');
  }

  // ── Admin / Unanswered ────────────────────────────

  static Future<List<UnansweredEntry>> listUnanswered() async {
    final resp = await http.get(Uri.parse('$_base/api/admin/unanswered'));
    if (resp.statusCode != 200) throw Exception('Failed to fetch unanswered');
    final list = jsonDecode(resp.body) as List;
    return list.map((e) => UnansweredEntry.fromJson(e)).toList();
  }

  static Future<void> reviewQuestion(String questionId, String answer) async {
    final resp = await http.post(
      Uri.parse('$_base/api/admin/review'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'question_id': questionId, 'answer': answer}),
    );
    if (resp.statusCode != 200) throw Exception('Failed to review question');
  }

  // ── Sessions ──────────────────────────────────────

  static Future<void> uploadTranscript(String title, String transcript) async {
    final resp = await http.post(
      Uri.parse('$_base/api/sessions/upload'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'transcript': transcript}),
    );
    if (resp.statusCode != 200) throw Exception('Failed to upload transcript');
  }
}
