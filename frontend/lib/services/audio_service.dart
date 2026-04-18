import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class AudioService {
  /// Single persistent audio element — reused across all playback to satisfy
  /// mobile browser autoplay policies (new elements are blocked unless created
  /// directly inside a user-gesture call-stack).
  static web.HTMLAudioElement? _persistentAudio;
  static bool _unlocked = false;
  static bool _playing = false;
  static String? _currentBlobUrl;
  static StreamSubscription? _endedSub;
  static StreamSubscription? _errorSub;

  /// Call once from a user gesture to unlock audio on mobile browsers.
  static Future<void> unlockAudio() async {
    if (_unlocked) return;
    _unlocked = true;
    try {
      final audio = web.HTMLAudioElement();
      // Attach to DOM — some mobile browsers (Chrome iOS) require this
      audio.style.display = 'none';
      web.document.body?.append(audio);
      audio.preload = 'auto';

      // Tiny silent WAV to satisfy autoplay policy
      audio.src =
          'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';
      audio.volume = 0.01;
      await audio.play().toDart;
      audio.pause();
      // Keep the element for reuse instead of disposing it
      _persistentAudio = audio;
      audio.volume = 1.0;
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
      _currentBlobUrl = blobUrl;

      // Reuse persistent element if available (mobile); fallback to new one
      final audio = _persistentAudio ?? web.HTMLAudioElement();
      if (_persistentAudio == null) {
        audio.style.display = 'none';
        audio.preload = 'auto';
        web.document.body?.append(audio);
        _persistentAudio = audio;
      }
      _playing = true;

      // Cancel previous listeners before adding new ones
      _endedSub?.cancel();
      _errorSub?.cancel();

      _endedSub = audio.onEnded.listen((_) {
        debugPrint('[AudioService] onEnded fired');
        _revokeBlobUrl();
        _playing = false;
        if (!completer.isCompleted) completer.complete();
      });

      _errorSub = audio.onError.listen((_) {
        debugPrint(
          '[AudioService] Audio error: code=${audio.error?.code}, message=${audio.error?.message}',
        );
        _revokeBlobUrl();
        _playing = false;
        if (!completer.isCompleted) completer.complete();
      });

      // Set source and play. Do NOT call load() — it can reset the
      // autoplay blessing on Chrome iOS.
      audio.src = blobUrl;

      try {
        await audio.play().toDart;
      } catch (playError) {
        // play() can reject on mobile — log it and complete so the queue
        // doesn't get stuck.
        debugPrint('[AudioService] play() rejected: $playError');
        _revokeBlobUrl();
        _playing = false;
        if (!completer.isCompleted) completer.complete();
        return;
      }

      // Timeout safety
      await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('[AudioService] Playback timed out');
          _revokeBlobUrl();
          _playing = false;
          audio.pause();
        },
      );
    } catch (e) {
      debugPrint('[AudioService] playBase64Audio failed: $e');
      _playing = false;
      if (!completer.isCompleted) completer.complete();
    }
  }

  static void _revokeBlobUrl() {
    if (_currentBlobUrl != null) {
      web.URL.revokeObjectURL(_currentBlobUrl!);
      _currentBlobUrl = null;
    }
  }

  static Future<void> stop() async {
    try {
      _endedSub?.cancel();
      _errorSub?.cancel();
      final audio = _persistentAudio;
      if (audio != null) {
        audio.pause();
        audio.currentTime = 0;
      }
      _revokeBlobUrl();
      _playing = false;
    } catch (_) {}
  }

  static bool get isPlaying => _playing;
}
