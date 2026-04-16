import 'dart:convert';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playBase64Audio(String base64Audio) async {
    final bytes = base64Decode(base64Audio);
    final dataUri = 'data:audio/mpeg;base64,$base64Audio';
    await _player.setUrl(dataUri);
    await _player.play();
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  static bool get isPlaying => _player.playing;

  static Stream<Duration> get positionStream => _player.positionStream;
  static Stream<Duration?> get durationStream => _player.durationStream;
  static Stream<PlayerState> get playerStateStream => _player.playerStateStream;
}
