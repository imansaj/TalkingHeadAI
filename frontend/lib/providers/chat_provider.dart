import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _isStreaming = false;
  int _audioGeneration = 0;

  /// Queue of base64 audio chunks to play sequentially.
  final Queue<String> _audioQueue = Queue();
  bool _isPlayingQueue = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSpeaking => _isSpeaking;
  bool get isStreaming => _isStreaming;

  Future<void> stopSpeaking() async {
    _audioGeneration++;
    _audioQueue.clear();
    await AudioService.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  /// Play queued audio chunks one after another.
  Future<void> _processAudioQueue(int generation) async {
    if (_isPlayingQueue) return;
    _isPlayingQueue = true;

    while (_audioQueue.isNotEmpty && _audioGeneration == generation) {
      final chunk = _audioQueue.removeFirst();
      _isSpeaking = true;
      notifyListeners();
      await AudioService.playBase64Audio(chunk);
    }

    if (_audioGeneration == generation) {
      _isSpeaking = false;
      notifyListeners();
    }
    _isPlayingQueue = false;
  }

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;

    _messages.add(ChatMessage(text: text, isUser: true));
    _isLoading = true;
    _isStreaming = true;
    notifyListeners();

    // Add a placeholder message for the streaming response
    final botMessage = ChatMessage(text: '', isUser: false);
    _messages.add(botMessage);

    final myGeneration = ++_audioGeneration;
    _audioQueue.clear();

    try {
      final stream = ApiService.chatStream(text);
      final textBuffer = StringBuffer();

      await for (final event in stream) {
        if (_audioGeneration != myGeneration) break; // stopped

        switch (event.type) {
          case 'text_chunk':
            final chunk = event.data['text'] as String? ?? '';
            textBuffer.write(chunk);
            // Update the bot message in-place
            final idx = _messages.length - 1;
            _messages[idx] = ChatMessage(
              text: textBuffer.toString(),
              isUser: false,
              answerType: _messages[idx].answerType,
              timesAsked: _messages[idx].timesAsked,
            );
            _isLoading = false; // Got first text — stop showing "Thinking..."
            notifyListeners();

          case 'audio_chunk':
            final audioB64 = event.data['audio_base64'] as String? ?? '';
            if (audioB64.isNotEmpty) {
              _audioQueue.add(audioB64);
              // Start playing if not already
              _processAudioQueue(myGeneration);
            }

          case 'done':
            final answerType = event.data['answer_type'] as String?;
            final timesAsked = event.data['times_asked'] as int?;
            final fullText =
                event.data['full_text'] as String? ?? textBuffer.toString();
            final idx = _messages.length - 1;
            _messages[idx] = ChatMessage(
              text: fullText,
              isUser: false,
              answerType: answerType,
              timesAsked: timesAsked,
            );
            notifyListeners();

          case 'error':
            final detail = event.data['detail'] as String? ?? 'Unknown error';
            final idx = _messages.length - 1;
            _messages[idx] = ChatMessage(text: 'Error: $detail', isUser: false);
            notifyListeners();
        }
      }
    } catch (e) {
      // If no text was streamed yet, update the placeholder
      final idx = _messages.length - 1;
      if (_messages[idx].text.isEmpty) {
        _messages[idx] = ChatMessage(text: 'Error: $e', isUser: false);
      }
    } finally {
      _isLoading = false;
      _isStreaming = false;
      notifyListeners();
    }
  }
}
