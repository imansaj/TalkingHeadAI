import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models.dart';

class ApiService {
  static final String _base = AppConfig.baseUrl;

  // ── Chat ──────────────────────────────────────────

  static Future<ChatResponse> chatText(String text) async {
    final resp = await http.post(
      Uri.parse('$_base/api/chat/text'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Chat failed: ${resp.statusCode}');
    }
    return ChatResponse.fromJson(jsonDecode(resp.body));
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
