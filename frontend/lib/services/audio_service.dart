import 'dart:convert';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playBase64Audio(String base64Audio) async {
    final bytes = base64Decode(base64Audio);
    final source = _Base64AudioSource(bytes);
    await _player.setAudioSource(source);
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

class _Base64AudioSource extends StreamAudioSource {
  final Uint8List _bytes;

  _Base64AudioSource(Uint8List bytes) : _bytes = bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
