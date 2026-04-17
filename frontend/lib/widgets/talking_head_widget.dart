import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Apple Memoji-inspired animated avatar with realistic mouth movements.
/// Uses multiple animation controllers to simulate different mouth shapes
/// (wide "A", round "O", narrow "E") instead of simple open/close.
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
  // Two mouth controllers at different speeds create varied shapes
  late AnimationController _mouthOpenController; // vertical opening
  late AnimationController _mouthStretchController; // horizontal stretch
  late AnimationController _blinkController;
  late AnimationController _bobController;
  late AnimationController _glowController;
  late AnimationController _jawController; // subtle jaw shift
  late Timer _blinkTimer;
  final _random = Random();

  @override
  void initState() {
    super.initState();

    // Primary mouth open (vertical) — medium speed
    _mouthOpenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
    );

    // Mouth width variation — slightly slower, creates shape diversity
    _mouthStretchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
    );

    // Jaw micro-movement
    _jawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 310),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scheduleBlink();
  }

  void _scheduleBlink() {
    final interval = Duration(milliseconds: 2500 + _random.nextInt(3500));
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
      _mouthOpenController.repeat(reverse: true);
      _mouthStretchController.repeat(reverse: true);
      _jawController.repeat(reverse: true);
      _bobController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      for (final c in [
        _mouthOpenController,
        _mouthStretchController,
        _jawController,
        _bobController,
        _glowController,
      ]) {
        c.stop();
        c.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _blinkTimer.cancel();
    _mouthOpenController.dispose();
    _mouthStretchController.dispose();
    _jawController.dispose();
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
        _mouthOpenController,
        _mouthStretchController,
        _jawController,
        _blinkController,
        _bobController,
        _glowController,
      ]),
      builder: (context, _) {
        final mouthOpen = _mouthOpenController.value;
        final mouthStretch = _mouthStretchController.value;
        final jawShift = _jawController.value;
        final blinkAmount = _blinkController.value;
        final bobOffset = _bobController.value * 4.0;
        final glowValue = _glowController.value;

        return Transform.translate(
          offset: Offset(sin(bobOffset) * 1.5, -bobOffset * 0.6),
          child: CustomPaint(
            size: Size(s, s),
            painter: _MemojiPainter(
              mouthOpen: mouthOpen,
              mouthStretch: mouthStretch,
              jawShift: jawShift,
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

class _MemojiPainter extends CustomPainter {
  final double mouthOpen;
  final double mouthStretch;
  final double jawShift;
  final double blinkAmount;
  final bool isSpeaking;
  final double glowValue;

  _MemojiPainter({
    required this.mouthOpen,
    required this.mouthStretch,
    required this.jawShift,
    required this.blinkAmount,
    required this.isSpeaking,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.48;
    final r = size.width * 0.36; // face radius

    // ── Drop shadow ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r + 10),
        width: r * 1.1,
        height: 10,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── Neck ──
    final neckW = r * 0.38;
    final neckGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFFF5D0A9), const Color(0xFFE8BA8A)],
    );
    final neckRect = Rect.fromLTWH(
      cx - neckW,
      cy + r * 0.7,
      neckW * 2,
      r * 0.45,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(neckRect, const Radius.circular(12)),
      Paint()..shader = neckGrad.createShader(neckRect),
    );

    // ── Face — smooth rounded shape ──
    final faceGrad = RadialGradient(
      center: const Alignment(-0.25, -0.3),
      radius: 0.9,
      colors: [
        const Color(0xFFFFF4E6),
        const Color(0xFFFFE4C4),
        const Color(0xFFF5D0A9),
        const Color(0xFFEABF94),
      ],
      stops: const [0.0, 0.35, 0.7, 1.0],
    );
    // Slightly taller oval for Memoji proportions
    final faceRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: r * 2,
      height: r * 2.2,
    );
    canvas.drawOval(
      faceRect,
      Paint()..shader = faceGrad.createShader(faceRect),
    );

    // Subtle face outline
    canvas.drawOval(
      faceRect,
      Paint()
        ..color = const Color(0xFFE0B088).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── Hair ──
    _drawHair(canvas, cx, cy, r);

    // ── Ears (partially behind hair) ──
    for (final side in [-1.0, 1.0]) {
      final ex = cx + side * r * 0.92;
      final ey = cy + r * 0.05;
      final earRect = Rect.fromCenter(
        center: Offset(ex, ey),
        width: r * 0.22,
        height: r * 0.38,
      );
      canvas.drawOval(
        earRect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(side * -0.4, -0.3),
            colors: [const Color(0xFFFFE4C4), const Color(0xFFE0B088)],
          ).createShader(earRect),
      );
      // Inner ear curve
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ex + side * -2, ey),
          width: r * 0.10,
          height: r * 0.22,
        ),
        Paint()..color = const Color(0xFFDEA87A).withValues(alpha: 0.35),
      );
    }

    // ── Eyes — large, expressive Memoji-style ──
    final eyeY = cy - r * 0.10;
    final eyeSpacing = r * 0.32;
    final eyeW = r * 0.26; // wide eyes
    final eyeH = r * 0.22;
    final openH = eyeH * (1 - blinkAmount);

    for (final side in [-1.0, 1.0]) {
      final ex = cx + side * eyeSpacing;

      // Eye white
      final whiteRect = Rect.fromCenter(
        center: Offset(ex, eyeY),
        width: eyeW,
        height: max(openH, 1),
      );
      canvas.drawOval(whiteRect, Paint()..color = Colors.white);

      if (openH > 2) {
        // Iris — vivid blue-green gradient
        final irisR = eyeW * 0.42;
        final irisRect = Rect.fromCenter(
          center: Offset(ex, eyeY),
          width: irisR * 2,
          height: min(irisR * 2, openH * 0.95),
        );
        canvas.drawOval(
          irisRect,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.15, -0.15),
              colors: [
                const Color(0xFF4A90D9), // bright blue center
                const Color(0xFF2E6DB4), // mid blue
                const Color(0xFF1B4F72), // dark blue edge
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(irisRect),
        );

        // Pupil
        canvas.drawCircle(
          Offset(ex, eyeY),
          irisR * 0.42,
          Paint()..color = const Color(0xFF0D1B2A),
        );

        // Large specular highlight (Apple-style)
        canvas.drawCircle(
          Offset(ex - irisR * 0.3, eyeY - irisR * 0.3),
          irisR * 0.28,
          Paint()..color = Colors.white.withValues(alpha: 0.90),
        );
        // Secondary small highlight
        canvas.drawCircle(
          Offset(ex + irisR * 0.2, eyeY + irisR * 0.2),
          irisR * 0.10,
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );

        // Upper eyelid shadow
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(ex, eyeY),
            width: eyeW + 2,
            height: openH + 2,
          ),
          pi + 0.3,
          pi - 0.6,
          false,
          Paint()
            ..color = const Color(0xFFDEA87A).withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      }

      // Eyelashes (subtle thick top line)
      if (blinkAmount < 0.9) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(ex, eyeY),
            width: eyeW + 3,
            height: max(openH + 3, 4),
          ),
          pi + 0.2,
          pi - 0.4,
          false,
          Paint()
            ..color = const Color(0xFF3D2B1F).withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── Eyebrows — smooth arched ──
    final browY = eyeY - r * 0.20;
    for (final side in [-1.0, 1.0]) {
      final bx = cx + side * eyeSpacing;
      final brow = Path()
        ..moveTo(bx - side * r * 0.16, browY + 2)
        ..quadraticBezierTo(bx, browY - 5, bx + side * r * 0.16, browY + 1);
      canvas.drawPath(
        brow,
        Paint()
          ..color = const Color(0xFF4A3728)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Nose — minimal Memoji style ──
    final noseY = cy + r * 0.15;
    final nosePath = Path()
      ..moveTo(cx - r * 0.05, noseY)
      ..quadraticBezierTo(cx, noseY + r * 0.06, cx + r * 0.05, noseY);
    canvas.drawPath(
      nosePath,
      Paint()
        ..color = const Color(0xFFDEA87A).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // ── Mouth — realistic multi-shape ──
    _drawMouth(canvas, cx, cy + r * 0.38, r);

    // ── Cheek blush ──
    final blushPaint = Paint()
      ..color = const Color(0xFFFF9999).withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(
      Offset(cx - r * 0.50, cy + r * 0.15),
      r * 0.16,
      blushPaint,
    );
    canvas.drawCircle(
      Offset(cx + r * 0.50, cy + r * 0.15),
      r * 0.16,
      blushPaint,
    );

    // ── Speaking glow ──
    if (isSpeaking) {
      final a = 0.10 + glowValue * 0.18;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: r * 2 + 14,
          height: r * 2.2 + 14,
        ),
        Paint()
          ..color = const Color(0xFF6C63FF).withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Sound wave arcs to the right
      for (var i = 1; i <= 3; i++) {
        final waveAlpha = 0.22 - i * 0.06;
        if (waveAlpha <= 0) continue;
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(cx + r + 6, cy),
            radius: 8.0 + i * 9.0 + glowValue * 5,
          ),
          -pi / 3.5,
          pi / 1.75,
          false,
          Paint()
            ..color = const Color(0xFF6C63FF).withValues(alpha: waveAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _drawHair(Canvas canvas, double cx, double cy, double r) {
    // Dark styled hair on top of head
    final hairColor = const Color(0xFF2C1810);
    final hairHighlight = const Color(0xFF4A3728);

    // Main hair volume — covers top of head
    final hairPath = Path()
      ..moveTo(cx - r * 0.95, cy - r * 0.15)
      ..quadraticBezierTo(
        cx - r * 1.05,
        cy - r * 0.8,
        cx - r * 0.5,
        cy - r * 1.15,
      )
      ..quadraticBezierTo(cx, cy - r * 1.35, cx + r * 0.5, cy - r * 1.15)
      ..quadraticBezierTo(
        cx + r * 1.05,
        cy - r * 0.8,
        cx + r * 0.95,
        cy - r * 0.15,
      )
      ..quadraticBezierTo(
        cx + r * 0.85,
        cy - r * 0.5,
        cx + r * 0.6,
        cy - r * 0.75,
      )
      ..quadraticBezierTo(cx, cy - r * 1.0, cx - r * 0.6, cy - r * 0.75)
      ..quadraticBezierTo(
        cx - r * 0.85,
        cy - r * 0.5,
        cx - r * 0.95,
        cy - r * 0.15,
      )
      ..close();

    // Hair gradient
    final hairRect = Rect.fromLTWH(
      cx - r * 1.1,
      cy - r * 1.4,
      r * 2.2,
      r * 1.3,
    );
    canvas.drawPath(
      hairPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [hairHighlight, hairColor],
        ).createShader(hairRect),
    );

    // Hair shine streak
    final shinePath = Path()
      ..moveTo(cx - r * 0.2, cy - r * 1.1)
      ..quadraticBezierTo(cx, cy - r * 1.2, cx + r * 0.3, cy - r * 1.05);
    canvas.drawPath(
      shinePath,
      Paint()
        ..color = const Color(0xFF6B4F3A).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Side hair covering ears slightly
    for (final side in [-1.0, 1.0]) {
      final sideHair = Path()
        ..moveTo(cx + side * r * 0.9, cy - r * 0.3)
        ..quadraticBezierTo(
          cx + side * r * 1.05,
          cy,
          cx + side * r * 0.85,
          cy + r * 0.15,
        );
      canvas.drawPath(
        sideHair,
        Paint()
          ..color = hairColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.18
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Realistic mouth using two independent parameters:
  /// [mouthOpen] controls vertical opening (0=closed, 1=wide)
  /// [mouthStretch] controls horizontal width variation
  /// Combined they produce "A" (open+wide), "O" (open+narrow),
  /// "E" (slight open+wide), and closed shapes.
  void _drawMouth(Canvas canvas, double cx, double my, double r) {
    final baseWidth = r * 0.28;
    // Stretch varies width: 0.7x to 1.3x
    final widthMul = 0.7 + mouthStretch * 0.6;
    final mw = baseWidth * widthMul;
    // Jaw shift moves mouth slightly down
    final jawY = my + jawShift * r * 0.03;

    if (mouthOpen > 0.06) {
      // Height inversely related to stretch for realism:
      // wide stretch = flatter opening, narrow = rounder
      final stretchFactor = 1.3 - mouthStretch * 0.6;
      final openH = r * 0.16 * mouthOpen * stretchFactor;

      // Mouth interior (dark, rounded rect shape via path)
      final interiorPath = Path();
      final mouthRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, jawY),
          width: mw * 1.7,
          height: max(openH * 2.0, 2),
        ),
        Radius.circular(openH * 1.2),
      );
      interiorPath.addRRect(mouthRect);
      canvas.drawPath(
        interiorPath,
        Paint()
          ..shader =
              RadialGradient(
                colors: [const Color(0xFF1A0505), const Color(0xFF3D0A0A)],
              ).createShader(
                Rect.fromCenter(
                  center: Offset(cx, jawY),
                  width: mw * 1.7,
                  height: openH * 2,
                ),
              ),
      );

      // Teeth row — visible when moderately open
      if (mouthOpen > 0.3) {
        final teethH = openH * 0.35 * min(mouthOpen * 1.5, 1.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, jawY - openH * 0.3),
              width: mw * 1.2,
              height: teethH,
            ),
            Radius.circular(teethH * 0.3),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        // Tooth divider lines (subtle)
        if (mouthOpen > 0.5) {
          final toothCount = 4;
          final toothW = mw * 1.2 / toothCount;
          for (var i = 1; i < toothCount; i++) {
            final tx = cx - mw * 0.6 + i * toothW;
            canvas.drawLine(
              Offset(tx, jawY - openH * 0.3 - teethH * 0.4),
              Offset(tx, jawY - openH * 0.3 + teethH * 0.4),
              Paint()
                ..color = const Color(0xFFE0D8D0).withValues(alpha: 0.4)
                ..strokeWidth = 0.7,
            );
          }
        }
      }

      // Tongue hint for wide opening
      if (mouthOpen > 0.5 && mouthStretch < 0.6) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, jawY + openH * 0.4),
            width: mw * 0.7,
            height: openH * 0.45,
          ),
          Paint()..color = const Color(0xFFCC6666).withValues(alpha: 0.5),
        );
      }

      // Upper lip with cupid's bow
      final ulPath = Path()
        ..moveTo(cx - mw * 0.85, jawY - openH * 0.15)
        ..cubicTo(
          cx - mw * 0.4,
          jawY - openH * 0.9,
          cx + mw * 0.4,
          jawY - openH * 0.9,
          cx + mw * 0.85,
          jawY - openH * 0.15,
        );
      canvas.drawPath(
        ulPath,
        Paint()
          ..color = const Color(0xFFD4817A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      // Lower lip — fuller curve
      final llPath = Path()
        ..moveTo(cx - mw * 0.80, jawY + openH * 0.2)
        ..cubicTo(
          cx - mw * 0.3,
          jawY + openH * 1.2,
          cx + mw * 0.3,
          jawY + openH * 1.2,
          cx + mw * 0.80,
          jawY + openH * 0.2,
        );
      canvas.drawPath(
        llPath,
        Paint()
          ..color = const Color(0xFFCC7070)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );
    } else {
      // Closed mouth — gentle smile
      final smilePath = Path()
        ..moveTo(cx - mw * 0.85, jawY)
        ..cubicTo(
          cx - mw * 0.3,
          jawY - r * 0.03,
          cx + mw * 0.3,
          jawY - r * 0.03,
          cx + mw * 0.85,
          jawY,
        );
      canvas.drawPath(
        smilePath,
        Paint()
          ..color = const Color(0xFFCC8080)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      // Lower lip hint
      final lowerHint = Path()
        ..moveTo(cx - mw * 0.65, jawY + 1.5)
        ..quadraticBezierTo(cx, jawY + r * 0.06, cx + mw * 0.65, jawY + 1.5);
      canvas.drawPath(
        lowerHint,
        Paint()
          ..color = const Color(0xFFCC8080).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MemojiPainter oldDelegate) {
    return oldDelegate.mouthOpen != mouthOpen ||
        oldDelegate.mouthStretch != mouthStretch ||
        oldDelegate.jawShift != jawShift ||
        oldDelegate.blinkAmount != blinkAmount ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.glowValue != glowValue;
  }
}
