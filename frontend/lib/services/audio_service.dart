import 'dart:convert';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

/// Custom AudioSource that serves raw bytes as an MP3 stream.
/// This avoids data: URIs which fail on mobile browsers (iOS Safari).
class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  _BytesAudioSource(this._bytes);

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

class AudioService {
  static AudioPlayer _player = AudioPlayer();

  /// Call once from a user gesture (e.g. first tap) to unlock audio on mobile.
  static Future<void> unlockAudio() async {
    try {
      // Playing silence satisfies the browser autoplay policy
      await _player.setVolume(0);
      await _player.setAudioSource(
        _BytesAudioSource(Uint8List(0)),
        preload: false,
      );
      await _player.play();
      await _player.stop();
      await _player.setVolume(1);
    } catch (_) {}
  }

  static Future<void> playBase64Audio(String base64Audio) async {
    // Stop and dispose previous player to avoid replaying old audio
    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
    _player = AudioPlayer();

    final bytes = base64Decode(base64Audio);
    await _player.setAudioSource(_BytesAudioSource(Uint8List.fromList(bytes)));
    await _player.play();

    // Wait for playback to complete
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
