import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _unlocked = false;

  /// Call once from a user gesture to unlock audio on mobile browsers.
  /// Must be awaited within the gesture handler for best results.
  static Future<void> unlockAudio() async {
    if (_unlocked) return;
    _unlocked = true;
    try {
      // Play a tiny silent WAV at low (non-zero) volume to satisfy autoplay policy.
      // Volume must be > 0 for some browsers to count it as a real play.
      const silentWavB64 =
          'UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';
      await _player.play(BytesSource(base64Decode(silentWavB64)), volume: 0.01);
      // Brief delay to let the browser register the play and unlock AudioContext
      await Future.delayed(const Duration(milliseconds: 50));
      await _player.stop();
      await _player.setVolume(1.0);
      debugPrint('[AudioService] Audio unlocked successfully');
    } catch (e) {
      debugPrint('[AudioService] Audio unlock failed: $e');
      _unlocked = false; // Allow retry on next gesture
    }
  }

  static Future<void> playBase64Audio(String base64Audio) async {
    // Stop any current playback but REUSE the same player instance.
    // Creating a new player loses the user-gesture context on mobile.
    try {
      await _player.stop();
    } catch (_) {}

    final completer = Completer<void>();

    late StreamSubscription sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      sub.cancel();
    });

    try {
      final bytes = base64Decode(base64Audio);
      await _player.play(BytesSource(Uint8List.fromList(bytes)));
      await completer.future;
    } catch (e) {
      debugPrint('[AudioService] playBase64Audio failed: $e');
      if (!completer.isCompleted) completer.complete();
      sub.cancel();
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  static bool get isPlaying => _player.state == PlayerState.playing;
}
