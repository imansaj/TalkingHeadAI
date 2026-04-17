import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static AudioPlayer _player = AudioPlayer();
  static bool _unlocked = false;

  /// Call once from a user gesture to unlock audio on mobile browsers.
  static Future<void> unlockAudio() async {
    if (_unlocked) return;
    _unlocked = true;
    try {
      // Play a tiny silent WAV to satisfy autoplay policy
      // Minimal WAV: 44-byte header + 1 sample of silence
      const silentWavB64 =
          'UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YQAAAAA=';
      await _player.play(BytesSource(base64Decode(silentWavB64)), volume: 0);
      await _player.stop();
    } catch (_) {}
  }

  static Future<void> playBase64Audio(String base64Audio) async {
    try {
      await _player.stop();
      await _player.release();
    } catch (_) {}
    _player = AudioPlayer();

    final completer = Completer<void>();

    // Listen for completion or error
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
      if (!completer.isCompleted) completer.complete();
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
      await _player.release();
    } catch (_) {}
    _player = AudioPlayer();
  }

  static bool get isPlaying => _player.state == PlayerState.playing;
}
