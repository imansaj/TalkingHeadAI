import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class AudioService {
  static web.HTMLAudioElement? _currentAudio;
  static bool _unlocked = false;
  static bool _playing = false;

  /// Call once from a user gesture to unlock audio on mobile browsers.
  static Future<void> unlockAudio() async {
    if (_unlocked) return;
    _unlocked = true;
    try {
      final audio = web.HTMLAudioElement();
      // Tiny silent WAV to satisfy autoplay policy
      audio.src =
          'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';
      audio.volume = 0.01;
      await audio.play().toDart;
      audio.pause();
      audio.remove();
      debugPrint('[AudioService] Audio unlocked successfully');
    } catch (e) {
      debugPrint('[AudioService] Audio unlock failed: $e');
      _unlocked = false;
    }
  }

  static Future<void> playBase64Audio(String base64Audio) async {
    // Stop any current playback
    await stop();

    final completer = Completer<void>();

    try {
      final bytes = base64Decode(base64Audio);
      debugPrint('[AudioService] Playing ${bytes.length} bytes of audio');

      // Create a Blob URL — more reliable than data URIs on web
      final jsArray = bytes.toJS;
      final blob = web.Blob(
        [jsArray].toJS,
        web.BlobPropertyBag(type: 'audio/mpeg'),
      );
      final blobUrl = web.URL.createObjectURL(blob);

      final audio = web.HTMLAudioElement();
      _currentAudio = audio;
      _playing = true;
      audio.src = blobUrl;

      audio.onEnded.listen((_) {
        web.URL.revokeObjectURL(blobUrl);
        _playing = false;
        _currentAudio = null;
        if (!completer.isCompleted) completer.complete();
      });

      audio.onError.listen((_) {
        debugPrint(
          '[AudioService] Audio error: code=${audio.error?.code}, message=${audio.error?.message}',
        );
        web.URL.revokeObjectURL(blobUrl);
        _playing = false;
        _currentAudio = null;
        if (!completer.isCompleted) completer.complete();
      });

      await audio.play().toDart;

      // Timeout safety
      await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('[AudioService] Playback timed out');
          web.URL.revokeObjectURL(blobUrl);
          _playing = false;
          audio.pause();
          _currentAudio = null;
        },
      );
    } catch (e) {
      debugPrint('[AudioService] playBase64Audio failed: $e');
      _playing = false;
      _currentAudio = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  static Future<void> stop() async {
    try {
      final audio = _currentAudio;
      if (audio != null) {
        audio.pause();
        audio.src = '';
        _currentAudio = null;
      }
      _playing = false;
    } catch (_) {}
  }

  static bool get isPlaying => _playing;
}
