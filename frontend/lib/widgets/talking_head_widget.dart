import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// A 3D-styled animated talking head with lip-sync driven by audio.
/// Mouth opens/closes when [isSpeaking] is true, simulating speech.
/// Eyes blink periodically. Head sways gently when speaking.
class TalkingHeadWidget extends StatefulWidget {
  final bool isSpeaking;
  final double size;

  const TalkingHeadWidget({
    super.key,
    this.isSpeaking = false,
    this.size = 250,
  });

  @override
  State<TalkingHeadWidget> createState() => _TalkingHeadWidgetState();
}

class _TalkingHeadWidgetState extends State<TalkingHeadWidget>
    with TickerProviderStateMixin {
  late AnimationController _mouthController;
  late AnimationController _blinkController;
  late AnimationController _bobController;
  late AnimationController _glowController;
  late Timer _blinkTimer;
  final _random = Random();

  @override
  void initState() {
    super.initState();

    // Mouth: varied speed to simulate natural speech rhythm
    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Random blinking at varying intervals
    _scheduleBlink();
  }

  void _scheduleBlink() {
    final interval = Duration(milliseconds: 2000 + _random.nextInt(3000));
    _blinkTimer = Timer(interval, () {
      if (mounted) {
        _blinkController.forward().then((_) {
          if (mounted) {
            _blinkController.reverse();
            _scheduleBlink();
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant TalkingHeadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _mouthController.repeat(reverse: true);
      _bobController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _mouthController.stop();
      _mouthController.value = 0;
      _bobController.stop();
      _bobController.value = 0;
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _blinkTimer.cancel();
    _mouthController.dispose();
    _blinkController.dispose();
    _bobController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: Listenable.merge([
        _mouthController,
        _blinkController,
        _bobController,
        _glowController,
      ]),
      builder: (context, _) {
        final mouthOpen = _mouthController.value;
        final blinkAmount = _blinkController.value;
        final bobOffset = _bobController.value * 5.0;
        final glowValue = _glowController.value;

        return Transform.translate(
          offset: Offset(sin(bobOffset) * 2, -bobOffset),
          child: CustomPaint(
            size: Size(s, s),
            painter: _HeadPainter3D(
              mouthOpen: mouthOpen,
              blinkAmount: blinkAmount,
              isSpeaking: widget.isSpeaking,
              glowValue: glowValue,
            ),
          ),
        );
      },
    );
  }
}

class _HeadPainter3D extends CustomPainter {
  final double mouthOpen;
  final double blinkAmount;
  final bool isSpeaking;
  final double glowValue;

  _HeadPainter3D({
    required this.mouthOpen,
    required this.blinkAmount,
    required this.isSpeaking,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.38;

    // ── Shadow beneath head ──
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 2, cy + radius + 8),
        width: radius * 1.2,
        height: 14,
      ),
      shadowPaint,
    );

    // ── Neck ──
    final neckGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFE8BA8A),
        const Color(0xFFD4A06A),
      ],
    );
    final neckRect = Rect.fromLTWH(cx - radius * 0.25, cy + radius * 0.6, radius * 0.5, radius * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(neckRect, const Radius.circular(8)),
      Paint()..shader = neckGradient.createShader(neckRect),
    );
    // Neck shadow
    canvas.drawRect(
      Rect.fromLTWH(cx - radius * 0.25, cy + radius * 0.6, radius * 0.5, 6),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );

    // ── Face (3D sphere gradient) ──
    final faceGradient = RadialGradient(
      center: const Alignment(-0.3, -0.35),
      radius: 0.85,
      colors: [
        const Color(0xFFFFF0DC), // highlight
        const Color(0xFFFFDBAC), // main skin
        const Color(0xFFE8BA8A), // shadow edge
        const Color(0xFFD4A574), // deep shadow
      ],
      stops: const [0.0, 0.4, 0.75, 1.0],
    );
    final faceRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()..shader = faceGradient.createShader(faceRect),
    );

    // Face rim light (subtle)
    final rimPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.4, 0.3),
        radius: 0.9,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.08),
        ],
      ).createShader(faceRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), radius, rimPaint);

    // ── Ears ──
    _drawEar(canvas, cx - radius * 0.95, cy, radius * 0.15, false);
    _drawEar(canvas, cx + radius * 0.95, cy, radius * 0.15, true);

    // ── Eyes with 3D depth ──
    final eyeY = cy - radius * 0.15;
    final eyeSpacing = radius * 0.35;
    final eyeRadius = radius * 0.11;
    final eyeHeight = eyeRadius * 2 * (1 - blinkAmount);

    // Eye sockets (subtle shadow)
    final socketPaint = Paint()
      ..color = const Color(0xFFD4A574).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - eyeSpacing, eyeY - 2),
        width: eyeRadius * 3.2,
        height: eyeRadius * 2.8,
      ),
      socketPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + eyeSpacing, eyeY - 2),
        width: eyeRadius * 3.2,
        height: eyeRadius * 2.8,
      ),
      socketPaint,
    );

    // Eye whites
    final eyeWhitePaint = Paint()..color = const Color(0xFFFAFAFA);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - eyeSpacing, eyeY),
        width: eyeRadius * 2.6,
        height: max(eyeHeight * 1.3, 1),
      ),
      eyeWhitePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + eyeSpacing, eyeY),
        width: eyeRadius * 2.6,
        height: max(eyeHeight * 1.3, 1),
      ),
      eyeWhitePaint,
    );

    // Irises with gradient
    if (eyeHeight > 2) {
      final irisSize = eyeRadius * 0.9;
      for (final xOff in [cx - eyeSpacing, cx + eyeSpacing]) {
        final irisRect = Rect.fromCenter(
          center: Offset(xOff, eyeY),
          width: irisSize * 2,
          height: min(irisSize * 2, eyeHeight * 1.1),
        );
        final irisGrad = RadialGradient(
          center: const Alignment(-0.2, -0.2),
          colors: [
            const Color(0xFF5B3A1A), // lighter brown center
            const Color(0xFF3D2B1F), // dark brown
            const Color(0xFF1A1A1A), // near-black edge
          ],
          stops: const [0.0, 0.6, 1.0],
        );
        canvas.drawOval(
          irisRect,
          Paint()..shader = irisGrad.createShader(irisRect),
        );

        // Pupil
        canvas.drawCircle(
          Offset(xOff, eyeY),
          irisSize * 0.4,
          Paint()..color = const Color(0xFF0A0A0A),
        );

        // Eye shine / specular highlight
        canvas.drawCircle(
          Offset(xOff - irisSize * 0.25, eyeY - irisSize * 0.3),
          irisSize * 0.2,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          Offset(xOff + irisSize * 0.15, eyeY + irisSize * 0.15),
          irisSize * 0.08,
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );
      }

      // Eyelid lines
      final lidPaint = Paint()
        ..color = const Color(0xFFD4A574).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final xOff in [cx - eyeSpacing, cx + eyeSpacing]) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(xOff, eyeY),
            width: eyeRadius * 2.8,
            height: eyeRadius * 2.0,
          ),
          pi,
          pi,
          false,
          lidPaint,
        );
      }
    }

    // ── Eyebrows (thicker, shaped) ──
    final browPaint = Paint()
      ..color = const Color(0xFF5B3A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final browY = eyeY - radius * 0.22;
    final browW = radius * 0.2;

    final leftBrow = Path()
      ..moveTo(cx - eyeSpacing - browW, browY + 3)
      ..quadraticBezierTo(cx - eyeSpacing, browY - 3, cx - eyeSpacing + browW, browY + 1);
    canvas.drawPath(leftBrow, browPaint);

    final rightBrow = Path()
      ..moveTo(cx + eyeSpacing - browW, browY + 1)
      ..quadraticBezierTo(cx + eyeSpacing, browY - 3, cx + eyeSpacing + browW, browY + 3);
    canvas.drawPath(rightBrow, browPaint);

    // ── Nose (3D with shading) ──
    final noseY = cy + radius * 0.08;
    // Nose bridge shadow
    final noseShadow = Paint()
      ..color = const Color(0xFFD4A574).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(
      Offset(cx + 1, cy - radius * 0.08),
      Offset(cx + 1, noseY),
      noseShadow..strokeWidth = 4,
    );
    // Nose shape
    final nosePath = Path()
      ..moveTo(cx, cy - radius * 0.06)
      ..lineTo(cx - radius * 0.07, noseY + radius * 0.02)
      ..quadraticBezierTo(cx, noseY + radius * 0.06, cx + radius * 0.07, noseY + radius * 0.02)
      ..lineTo(cx, cy - radius * 0.06);
    canvas.drawPath(
      nosePath,
      Paint()
        ..color = const Color(0xFFD4A574).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    // Nostril dots
    canvas.drawCircle(
      Offset(cx - radius * 0.04, noseY + radius * 0.01),
      1.5,
      Paint()..color = const Color(0xFFD4A574).withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      Offset(cx + radius * 0.04, noseY + radius * 0.01),
      1.5,
      Paint()..color = const Color(0xFFD4A574).withValues(alpha: 0.5),
    );

    // ── Mouth (lip-sync driven) ──
    final mouthY = cy + radius * 0.35;
    final mouthWidth = radius * 0.32;

    if (mouthOpen > 0.05) {
      // Open mouth — 3D with lips
      final openHeight = radius * 0.18 * mouthOpen;

      // Dark mouth interior
      final mouthInterior = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          colors: [
            const Color(0xFF2D0000),
            const Color(0xFF5C0000),
          ],
        ).createShader(Rect.fromCenter(
          center: Offset(cx, mouthY),
          width: mouthWidth * 1.8,
          height: openHeight * 2,
        ));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, mouthY),
          width: mouthWidth * 1.8,
          height: max(openHeight * 2, 2),
        ),
        mouthInterior,
      );

      // Tongue hint
      if (mouthOpen > 0.4) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, mouthY + openHeight * 0.4),
            width: mouthWidth * 0.8,
            height: openHeight * 0.5,
          ),
          Paint()..color = const Color(0xFFCC5555).withValues(alpha: 0.6),
        );
      }

      // Upper lip
      final upperLip = Path()
        ..moveTo(cx - mouthWidth, mouthY - openHeight * 0.2)
        ..quadraticBezierTo(cx - mouthWidth * 0.5, mouthY - openHeight * 0.8, cx, mouthY - openHeight * 0.5)
        ..quadraticBezierTo(cx + mouthWidth * 0.5, mouthY - openHeight * 0.8, cx + mouthWidth, mouthY - openHeight * 0.2);
      canvas.drawPath(
        upperLip,
        Paint()
          ..color = const Color(0xFFCC7777)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      // Lower lip
      final lowerLip = Path()
        ..moveTo(cx - mouthWidth * 0.9, mouthY + openHeight * 0.3)
        ..quadraticBezierTo(cx, mouthY + openHeight * 1.1, cx + mouthWidth * 0.9, mouthY + openHeight * 0.3);
      canvas.drawPath(
        lowerLip,
        Paint()
          ..color = const Color(0xFFCC6666)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );

      // Teeth hint for wide open
      if (mouthOpen > 0.6) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, mouthY - openHeight * 0.15),
            width: mouthWidth * 1.0,
            height: openHeight * 0.3,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
      }
    } else {
      // Closed mouth — natural lips
      final lipColor = const Color(0xFFCC8888);

      // Upper lip with cupid's bow
      final upperLip = Path()
        ..moveTo(cx - mouthWidth, mouthY)
        ..quadraticBezierTo(cx - mouthWidth * 0.4, mouthY - radius * 0.04, cx, mouthY - radius * 0.02)
        ..quadraticBezierTo(cx + mouthWidth * 0.4, mouthY - radius * 0.04, cx + mouthWidth, mouthY);
      canvas.drawPath(
        upperLip,
        Paint()
          ..color = lipColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );

      // Lower lip
      final lowerLip = Path()
        ..moveTo(cx - mouthWidth * 0.85, mouthY + 1)
        ..quadraticBezierTo(cx, mouthY + radius * 0.07, cx + mouthWidth * 0.85, mouthY + 1);
      canvas.drawPath(
        lowerLip,
        Paint()
          ..color = lipColor.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );

      // Lip line
      canvas.drawLine(
        Offset(cx - mouthWidth * 0.9, mouthY),
        Offset(cx + mouthWidth * 0.9, mouthY),
        Paint()
          ..color = const Color(0xFFC47A5A).withValues(alpha: 0.5)
          ..strokeWidth = 1.0,
      );
    }

    // ── Cheek blush ──
    final blushPaint = Paint()
      ..color = const Color(0xFFFFAAAA).withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(cx - radius * 0.5, cy + radius * 0.15), radius * 0.15, blushPaint);
    canvas.drawCircle(Offset(cx + radius * 0.5, cy + radius * 0.15), radius * 0.15, blushPaint);

    // ── Speaking glow indicator ──
    if (isSpeaking) {
      final alpha = 0.15 + glowValue * 0.2;
      final glowPaint = Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(cx, cy), radius + 6, glowPaint);

      // Sound waves
      final wavePaint = Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: 0.2 + glowValue * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var i = 1; i <= 3; i++) {
        final waveRadius = radius + 10 + (i * 10.0) + (glowValue * 6);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: waveRadius),
          -pi / 3,
          pi * 2 / 3,
          false,
          wavePaint..color = wavePaint.color.withValues(alpha: 0.25 - (i * 0.06)),
        );
      }
    }
  }

  void _drawEar(Canvas canvas, double x, double y, double earRadius, bool isRight) {
    final earGrad = RadialGradient(
      center: isRight ? const Alignment(-0.5, -0.3) : const Alignment(0.5, -0.3),
      colors: [
        const Color(0xFFFFDBAC),
        const Color(0xFFD4A574),
      ],
    );
    final earRect = Rect.fromCenter(
      center: Offset(x, y),
      width: earRadius * 2,
      height: earRadius * 3,
    );
    canvas.drawOval(
      earRect,
      Paint()..shader = earGrad.createShader(earRect),
    );
    // Inner ear
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + (isRight ? -2 : 2), y),
        width: earRadius * 1.0,
        height: earRadius * 1.8,
      ),
      Paint()..color = const Color(0xFFD4A574).withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(covariant _HeadPainter3D oldDelegate) {
    return oldDelegate.mouthOpen != mouthOpen ||
        oldDelegate.blinkAmount != blinkAmount ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.glowValue != glowValue;
  }
}
