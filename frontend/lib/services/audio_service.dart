import 'dart:convert';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static AudioPlayer _player = AudioPlayer();

  static Future<void> playBase64Audio(String base64Audio) async {
    // Stop and dispose previous player to avoid replaying old audio
    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
    _player = AudioPlayer();

    final dataUri = 'data:audio/mpeg;base64,$base64Audio';
    await _player.setUrl(dataUri);
    await _player.play();

    // Wait for playback to complete — wrapped in try-catch because
    // if stop()/dispose() is called externally, the stream closes and throws
    try {
      await _player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed,
      );
    } catch (_) {
      // Stream closed or player disposed — ignore gracefully
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
    _player = AudioPlayer();
  }

  static bool get isPlaying => _player.playing;

  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;
}
