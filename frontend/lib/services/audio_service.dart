import 'dart:convert';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static AudioPlayer _player = AudioPlayer();

  static Future<void> playBase64Audio(String base64Audio) async {
    // Stop and dispose previous player to avoid replaying old audio
    await _player.stop();
    await _player.dispose();
    _player = AudioPlayer();

    final dataUri = 'data:audio/mpeg;base64,$base64Audio';
    await _player.setUrl(dataUri);
    await _player.play();

    // Wait for playback to actually complete
    // Use orElse to avoid "Bad state: No element" if stream closes early (e.g. stop() called)
    await _player.processingStateStream.firstWhere(
      (state) => state == ProcessingState.completed,
      orElse: () => ProcessingState.idle,
    );
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  static bool get isPlaying => _player.playing;

  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;
}
