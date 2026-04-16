import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSpeaking = false;
  int _audioGeneration = 0; // Track which audio session is active

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSpeaking => _isSpeaking;

  Future<void> stopSpeaking() async {
    _audioGeneration++; // Invalidate current audio session
    await AudioService.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;

    _messages.add(ChatMessage(text: text, isUser: true));
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.chatText(text);

      _messages.add(
        ChatMessage(
          text: response.text,
          isUser: false,
          answerType: response.answerType,
          timesAsked: response.timesAsked,
          audioBase64: response.audioBase64,
        ),
      );

      _isLoading = false;

      // Play audio with lip-sync
      if (response.audioBase64 != null && response.audioBase64!.isNotEmpty) {
        final myGeneration = ++_audioGeneration;
        _isSpeaking = true;
        notifyListeners();
        await AudioService.playBase64Audio(response.audioBase64!);
        // Only clear speaking state if no newer audio started
        if (_audioGeneration == myGeneration) {
          _isSpeaking = false;
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    } catch (e) {
      _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
      _isLoading = false;
      _isSpeaking = false;
      notifyListeners();
    }
  }
}
