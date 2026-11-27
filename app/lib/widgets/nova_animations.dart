import 'dart:math' as math;

import 'package:flutter/material.dart';

const _novaColors = <Color>[
  Color(0xFF28D7FF),
  Color(0xFF397BFF),
  Color(0xFF8A5CFF),
  Color(0xFFE04DFF),
  Color(0xFF35F0C5),
  Color(0xFFFF5EB8),
];

/// Thousands of luminous particles converge into the NOVA wordmark.
class NovaParticleLogo extends StatefulWidget {
  const NovaParticleLogo({super.key, this.size = 220});

  final double size;

  @override
  State<NovaParticleLogo> createState() => _NovaParticleLogoState();
}

class _NovaParticleLogoState extends State<NovaParticleLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _NovaParticlesPainter(_controller.value),
        ),
      );
}

class _NovaParticlesPainter extends CustomPainter {
  _NovaParticlesPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final unit = side / 112;
    final random = math.Random(731);
    final points = <Offset>[];

    void line(double x1, double y1, double x2, double y2, int count) {
      for (var i = 0; i < count; i++) {
        final t = random.nextDouble();
        final jitter = (random.nextDouble() - .5) * 1.5;
        points.add(Offset(
          x1 + (x2 - x1) * t + jitter,
          y1 + (y2 - y1) * t + jitter,
        ));
      }
    }

    // N
    line(7, 25, 7, 87, 200);
    line(7, 25, 25, 87, 210);
    line(25, 87, 25, 25, 200);
    // O
    for (var i = 0; i < 460; i++) {
      final a = random.nextDouble() * math.pi * 2;
      points.add(Offset(43 + math.cos(a) * 12, 56 + math.sin(a) * 31));
    }
    // V
    line(61, 25, 75, 87, 220);
    line(75, 87, 89, 25, 220);
    // A
    line(92, 87, 101, 25, 200);
    line(101, 25, 110, 87, 200);
    line(95, 65, 107, 65, 130);

    final glowPaint = Paint()
      ..color = const Color(0xFF398CFF).withValues(alpha: .10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, side * .37, glowPaint);

    final phase = Curves.easeInOutCubic.transform(progress);
    for (var i = 0; i < points.length; i++) {
      final target = points[i];
      final angle = (i * 2.399) + progress * math.pi * 2;
      final spread = (1 - phase) * (8 + (i % 17) * .72);
      final wobble = math.sin(progress * math.pi * 2 + i * .13) * .8;
      final p = Offset(
        center.dx + (target.dx - 56) * unit + math.cos(angle) * spread * unit,
        center.dy + (target.dy - 56) * unit + math.sin(angle) * spread * unit,
      );
      final color = _novaColors[i % _novaColors.length];
      final radius = (.65 + (i % 5) * .13 + wobble.abs() * .12) * unit * .48;
      final paint = Paint()
        ..color = color.withValues(alpha: .70 + .30 * phase)
        ..maskFilter = i % 7 == 0
            ? const MaskFilter.blur(BlurStyle.normal, 2.2)
            : null;
      canvas.drawCircle(p, radius, paint);
    }


    // Four luminous neon rings orbit the NOVA core at different angles.
    const ringColors = <Color>[
      Color(0xFF28D7FF),
      Color(0xFF477BFF),
      Color(0xFFB35CFF),
      Color(0xFFFF55B8),
    ];
    for (var i = 0; i < ringColors.length; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation * (i.isEven ? 1 : -0.72) + i * 0.72);
      final ringRect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * (2.10 + i * 0.13),
        height: radius * (0.46 + i * 0.055),
      );
      final ringGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = ringColors[i].withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(ringRect, ringGlow);
      final ringLine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = ringColors[i].withValues(alpha: 0.82);
      canvas.drawOval(ringRect, ringLine);
      canvas.restore();
    }

    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF123B70),
          Color(0xFF0A1C35),
          Color(0x000A1C35),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.58));
    canvas.drawCircle(center, radius * 0.58, corePaint);
    final coreOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF44DFFF).withValues(alpha: 0.68);
    canvas.drawCircle(center, radius * 0.49, coreOutline);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF2ACFFF).withValues(alpha: .24);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: side * .92, height: side * .30),
      orbitPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NovaParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Bright, lightweight orbital animation for the connecting screen.
class NovaOrbitAnimation extends StatefulWidget {
  const NovaOrbitAnimation({super.key, this.size = 250});

  final double size;

  @override
  State<NovaOrbitAnimation> createState() => _NovaOrbitAnimationState();
}

class _NovaOrbitAnimationState extends State<NovaOrbitAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _NovaOrbitPainter(_controller.value),
        ),
      );
}

class _NovaOrbitPainter extends CustomPainter {
  _NovaOrbitPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height).toDouble() * .36;
    final rotation = progress * math.pi * 2;

    final glow = Paint()
      ..color = const Color(0xFF278CFF).withValues(alpha: .13)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, radius * 1.12, glow);

    // A rotating field of luminous points forms a 3D globe, echoing the
    // reference connection animation while keeping NOVA's own palette.
    const latitudeSteps = 15;
    const longitudeSteps = 48;
    for (var latIndex = 0; latIndex <= latitudeSteps; latIndex++) {
      final latitude = -math.pi / 2 +
          math.pi * latIndex / latitudeSteps;
      final latitudeRadius = math.cos(latitude);
      for (var lonIndex = 0; lonIndex < longitudeSteps; lonIndex++) {
        final longitude =
            math.pi * 2 * lonIndex / longitudeSteps + rotation;
        final x = latitudeRadius * math.cos(longitude);
        final y = math.sin(latitude);
        final depth = latitudeRadius * math.sin(longitude);
        final perspective = .82 + depth * .18;
        final point = Offset(
          center.dx + x * radius * perspective,
          center.dy + y * radius * .78 * perspective,
        );
        final front = depth >= 0;
        final alpha = front ? .88 : .22;
        final palette = (latIndex + lonIndex ~/ 8) % 3;
        final color = switch (palette) {
          0 => const Color(0xFF31D8FF),
          1 => const Color(0xFF438CFF),
          _ => const Color(0xFF8A68FF),
        };
        final dotRadius = (front ? 1.25 : .85) +
            .35 * (1 + math.sin(rotation * 2 + lonIndex * .31)) / 2;
        final paint = Paint()..color = color.withValues(alpha: alpha);
        canvas.drawCircle(point, dotRadius, paint);
      }
    }

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF39CFFF).withValues(alpha: .32);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2.28,
        height: radius * .62,
      ),
      orbitPaint,
    );

    final text = TextPainter(
      text: const TextSpan(
        text: 'NOVA',
        style: TextStyle(
          color: Color(0xFF65E8FF),
          fontSize: 27,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.7,
          shadows: [
            Shadow(color: Color(0xFF2B8CFF), blurRadius: 16),
            Shadow(color: Color(0xFF8D4DFF), blurRadius: 22),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(covariant _NovaOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
