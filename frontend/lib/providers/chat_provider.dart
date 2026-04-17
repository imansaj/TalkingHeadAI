import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

/// A sentence with its paired audio for synchronized playback.
class _SyncedChunk {
  final String text;
  final String audioBase64;
  _SyncedChunk({required this.text, required this.audioBase64});
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _isStreaming = false;
  int _audioGeneration = 0;

  /// Queue of synced text+audio chunks waiting to be played.
  final Queue<_SyncedChunk> _syncQueue = Queue();
  bool _isPlayingQueue = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSpeaking => _isSpeaking;
  bool get isStreaming => _isStreaming;

  Future<void> stopSpeaking() async {
    _audioGeneration++;
    _syncQueue.clear();
    _isPlayingQueue = false;
    await AudioService.stop();
    _isSpeaking = false;
    _isStreaming = false;
    notifyListeners();
  }

  /// Play queued chunks: reveal sentence text, then play its audio.
  Future<void> _processSyncQueue(
    int generation,
    StringBuffer textBuffer,
  ) async {
    if (_isPlayingQueue) return;
    _isPlayingQueue = true;

    while (_syncQueue.isNotEmpty && _audioGeneration == generation) {
      final chunk = _syncQueue.removeFirst();

      // Reveal this sentence's text
      textBuffer.write(chunk.text);
      final idx = _messages.length - 1;
      _messages[idx] = ChatMessage(
        text: textBuffer.toString(),
        isUser: false,
        answerType: _messages[idx].answerType,
        timesAsked: _messages[idx].timesAsked,
      );
      _isSpeaking = true;
      _isLoading = false;
      notifyListeners();

      // Play this sentence's audio
      await AudioService.playBase64Audio(chunk.audioBase64);
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

    // Placeholder for streaming response
    _messages.add(ChatMessage(text: '', isUser: false));

    final myGeneration = ++_audioGeneration;
    _syncQueue.clear();

    // Text revealed so far (synced with audio playback)
    final textBuffer = StringBuffer();

    try {
      final stream = ApiService.chatStream(text);

      await for (final event in stream) {
        if (_audioGeneration != myGeneration) break;

        switch (event.type) {
          case 'meta':
            final answerType = event.data['answer_type'] as String?;
            final timesAsked = event.data['times_asked'] as int?;
            final idx = _messages.length - 1;
            _messages[idx] = ChatMessage(
              text: _messages[idx].text,
              isUser: false,
              answerType: answerType,
              timesAsked: timesAsked,
            );
            notifyListeners();

          case 'sentence':
            final sentenceText = event.data['text'] as String? ?? '';
            final audioB64 = event.data['audio_base64'] as String? ?? '';
            if (sentenceText.isNotEmpty && audioB64.isNotEmpty) {
              _syncQueue.add(
                _SyncedChunk(text: sentenceText, audioBase64: audioB64),
              );
              // Start playing if not already
              _processSyncQueue(myGeneration, textBuffer);
            }

          case 'done':
            final answerType = event.data['answer_type'] as String?;
            final timesAsked = event.data['times_asked'] as int?;
            final fullText =
                event.data['full_text'] as String? ?? textBuffer.toString();
            // Wait for audio queue to finish before finalizing
            // (the queue runner will keep going in the background)
            // Update metadata on the message
            final idx = _messages.length - 1;
            _messages[idx] = ChatMessage(
              text: _messages[idx].text.isEmpty
                  ? fullText
                  : _messages[idx].text,
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

  Future<void> sendVoice(Uint8List audioBytes) async {
    final userMsg = ChatMessage(text: '🎤 Voice message', isUser: true);
    _messages.add(userMsg);
    _isLoading = true;
    notifyListeners();

    final myGeneration = ++_audioGeneration;
    _syncQueue.clear();

    try {
      final response = await ApiService.chatVoice(audioBytes);

      if (_audioGeneration != myGeneration) return;

      // Update the user bubble with the transcribed question
      if (response.transcript != null && response.transcript!.isNotEmpty) {
        final idx = _messages.indexOf(userMsg);
        if (idx != -1) {
          _messages[idx] = ChatMessage(
            text: '🎤 ${response.transcript}',
            isUser: true,
          );
        }
      }

      _messages.add(
        ChatMessage(
          text: response.text,
          isUser: false,
          answerType: response.answerType,
          timesAsked: response.timesAsked,
        ),
      );
      notifyListeners();

      if (response.audioBase64 != null && response.audioBase64!.isNotEmpty) {
        _isSpeaking = true;
        notifyListeners();
        await AudioService.playBase64Audio(response.audioBase64!);
        if (_audioGeneration == myGeneration) {
          _isSpeaking = false;
          notifyListeners();
        }
      }
    } catch (e) {
      _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
