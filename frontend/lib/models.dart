class ChatMessage {
  final String text;
  final bool isUser;
  final String? answerType; // "new" | "known"
  final int? timesAsked;
  final String? audioBase64;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.answerType,
    this.timesAsked,
    this.audioBase64,
  });
}

class ChatResponse {
  final String answerType;
  final String text;
  final String? audioBase64;
  final int? timesAsked;

  ChatResponse({
    required this.answerType,
    required this.text,
    this.audioBase64,
    this.timesAsked,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answerType: json['answer_type'] as String,
      text: json['text'] as String,
      audioBase64: json['audio_base64'] as String?,
      timesAsked: json['times_asked'] as int?,
    );
  }
}

class KnowledgeEntry {
  final String questionId;
  final String question;
  final String answer;
  final int timesAsked;
  final String source;

  KnowledgeEntry({
    required this.questionId,
    required this.question,
    required this.answer,
    required this.timesAsked,
    required this.source,
  });

  factory KnowledgeEntry.fromJson(Map<String, dynamic> json) {
    return KnowledgeEntry(
      questionId: json['question_id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      timesAsked: (json['times_asked'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? 'mentor',
    );
  }
}

class UnansweredEntry {
  final String questionId;
  final String question;
  final String generalResponse;
  final String createdAt;

  UnansweredEntry({
    required this.questionId,
    required this.question,
    required this.generalResponse,
    required this.createdAt,
  });

  factory UnansweredEntry.fromJson(Map<String, dynamic> json) {
    return UnansweredEntry(
      questionId: json['question_id'] as String,
      question: json['question'] as String,
      generalResponse: json['general_response'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}
