import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class AudioService {
  /// Web Audio API context — once unlocked from a user gesture, stays unlocked
  /// for all subsequent playback. This is the reliable way to play sequential
  /// audio on all mobile browsers including Chrome iOS.
  static web.AudioContext? _audioCtx;
  static web.AudioBufferSourceNode? _currentSource;
  static bool _unlocked = false;
  static bool _playing = false;

  /// Call once from a user gesture to unlock AudioContext on mobile browsers.
  static Future<void> unlockAudio() async {
    if (_unlocked) return;
    _unlocked = true;
    try {
      _audioCtx = web.AudioContext();
      // Resume the context (required by autoplay policy on mobile)
      await _audioCtx!.resume().toDart;
      // Play a tiny silent buffer to fully unlock
      final buffer = _audioCtx!.createBuffer(1, 1, 22050);
      final source = _audioCtx!.createBufferSource();
      source.buffer = buffer;
      source.connect(_audioCtx!.destination);
      source.start();
      debugPrint('[AudioService] AudioContext unlocked successfully');
    } catch (e) {
      debugPrint('[AudioService] AudioContext unlock failed: $e');
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

      // Ensure context exists
      _audioCtx ??= web.AudioContext();
      final ctx = _audioCtx!;

      // Resume context if it's suspended (e.g. after tab switch)
      if (ctx.state == 'suspended') {
        await ctx.resume().toDart;
      }

      // Decode MP3 bytes into an AudioBuffer
      final jsBytes = bytes.buffer.toJS;
      final audioBuffer = await ctx.decodeAudioData(jsBytes).toDart;

      _playing = true;

      // Create a source node and play
      final source = ctx.createBufferSource();
      _currentSource = source;
      source.buffer = audioBuffer;
      source.connect(ctx.destination);

      source.onEnded.listen((_) {
        debugPrint('[AudioService] onEnded fired');
        _playing = false;
        _currentSource = null;
        if (!completer.isCompleted) completer.complete();
      });

      source.start();

      // Timeout safety
      await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('[AudioService] Playback timed out');
          _playing = false;
          try {
            source.stop();
          } catch (_) {}
          _currentSource = null;
        },
      );
    } catch (e) {
      debugPrint('[AudioService] playBase64Audio failed: $e');
      _playing = false;
      _currentSource = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  static Future<void> stop() async {
    try {
      final source = _currentSource;
      if (source != null) {
        source.stop();
        _currentSource = null;
      }
      _playing = false;
    } catch (_) {}
  }

  static bool get isPlaying => _playing;
}
