import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// A simple 2D animated talking head.
/// Mouth opens/closes when [isSpeaking] is true.
/// Eyes blink periodically. Head bobs slightly when speaking.
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
  late Timer _blinkTimer;

  @override
  void initState() {
    super.initState();

    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Random blinking
    _blinkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _blinkController.forward().then((_) => _blinkController.reverse());
    });
  }

  @override
  void didUpdateWidget(covariant TalkingHeadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _mouthController.repeat(reverse: true);
      _bobController.repeat(reverse: true);
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _mouthController.stop();
      _mouthController.value = 0;
      _bobController.stop();
      _bobController.value = 0;
    }
  }

  @override
  void dispose() {
    _blinkTimer.cancel();
    _mouthController.dispose();
    _blinkController.dispose();
    _bobController.dispose();
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
      ]),
      builder: (context, _) {
        final mouthOpen = _mouthController.value;
        final blinkAmount = _blinkController.value;
        final bobOffset = _bobController.value * 4.0;

        return Transform.translate(
          offset: Offset(0, -bobOffset),
          child: CustomPaint(
            size: Size(s, s),
            painter: _HeadPainter(
              mouthOpen: mouthOpen,
              blinkAmount: blinkAmount,
              isSpeaking: widget.isSpeaking,
            ),
          ),
        );
      },
    );
  }
}

class _HeadPainter extends CustomPainter {
  final double mouthOpen;
  final double blinkAmount;
  final bool isSpeaking;

  _HeadPainter({
    required this.mouthOpen,
    required this.blinkAmount,
    required this.isSpeaking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.38;

    // Face circle
    final facePaint = Paint()
      ..color = const Color(0xFFFFDBAC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius, facePaint);

    // Face outline
    final outlinePaint = Paint()
      ..color = const Color(0xFFD4A574)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(cx, cy), radius, outlinePaint);

    // Eyes
    final eyeY = cy - radius * 0.15;
    final eyeSpacing = radius * 0.35;
    final eyeRadius = radius * 0.09;
    final eyeHeight = eyeRadius * 2 * (1 - blinkAmount);

    final eyePaint = Paint()
      ..color = const Color(0xFF3D3D3D)
      ..style = PaintingStyle.fill;

    // Left eye
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - eyeSpacing, eyeY),
        width: eyeRadius * 2,
        height: max(eyeHeight, 1),
      ),
      eyePaint,
    );

    // Right eye
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + eyeSpacing, eyeY),
        width: eyeRadius * 2,
        height: max(eyeHeight, 1),
      ),
      eyePaint,
    );

    // Eyebrows
    final browPaint = Paint()
      ..color = const Color(0xFF6B4226)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final browY = eyeY - radius * 0.18;
    final browW = radius * 0.18;
    canvas.drawLine(
      Offset(cx - eyeSpacing - browW, browY + 2),
      Offset(cx - eyeSpacing + browW, browY),
      browPaint,
    );
    canvas.drawLine(
      Offset(cx + eyeSpacing - browW, browY),
      Offset(cx + eyeSpacing + browW, browY + 2),
      browPaint,
    );

    // Nose
    final nosePaint = Paint()
      ..color = const Color(0xFFD4A574)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final noseY = cy + radius * 0.08;
    canvas.drawLine(
      Offset(cx, noseY - radius * 0.08),
      Offset(cx - radius * 0.05, noseY),
      nosePaint,
    );
    canvas.drawLine(
      Offset(cx - radius * 0.05, noseY),
      Offset(cx + radius * 0.05, noseY),
      nosePaint,
    );

    // Mouth
    final mouthY = cy + radius * 0.35;
    final mouthWidth = radius * 0.35;
    final mouthHeight = radius * 0.12 * mouthOpen;

    if (mouthOpen > 0.05) {
      // Open mouth
      final mouthPaint = Paint()
        ..color = const Color(0xFF8B0000)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, mouthY),
          width: mouthWidth * 2,
          height: max(mouthHeight * 2, 2),
        ),
        mouthPaint,
      );
    } else {
      // Closed mouth — smile
      final smilePaint = Paint()
        ..color = const Color(0xFFC47A5A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final smilePath = Path()
        ..moveTo(cx - mouthWidth, mouthY)
        ..quadraticBezierTo(cx, mouthY + radius * 0.1, cx + mouthWidth, mouthY);
      canvas.drawPath(smilePath, smilePaint);
    }

    // Speaking indicator
    if (isSpeaking) {
      final wavePaint = Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (var i = 1; i <= 3; i++) {
        canvas.drawCircle(
          Offset(cx, cy),
          radius + (i * 8.0) + (mouthOpen * 4),
          wavePaint
            ..color = wavePaint.color.withValues(alpha: 0.5 - (i * 0.12)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeadPainter oldDelegate) {
    return oldDelegate.mouthOpen != mouthOpen ||
        oldDelegate.blinkAmount != blinkAmount ||
        oldDelegate.isSpeaking != isSpeaking;
  }
}
