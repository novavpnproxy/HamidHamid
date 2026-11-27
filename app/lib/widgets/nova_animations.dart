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
      oldDelegate.progress != progress || oldDelegate.lightTheme != lightTheme;
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
          color: Color(0xFFE8F7FF),
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


/// Particle-built NOVA VPN wordmark: three seconds of convergence, then one
/// second of stillness so the completed lettering can be read.
class NovaWordParticleAnimation extends StatefulWidget {
  const NovaWordParticleAnimation({super.key, required this.width, this.lightTheme = false});

  final double width;
  final bool lightTheme;

  @override
  State<NovaWordParticleAnimation> createState() =>
      _NovaWordParticleAnimationState();
}

class _NovaWordParticleAnimationState extends State<NovaWordParticleAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size(widget.width, 126),
          painter: _NovaWordParticlesPainter(_controller.value, lightTheme: widget.lightTheme),
        ),
      );
}

class _NovaWordParticlesPainter extends CustomPainter {
  _NovaWordParticlesPainter(this.progress, {required this.lightTheme});

  final double progress;
  final bool lightTheme;

  static const Map<String, List<String>> _glyphs = {
    'N': ['10001','11001','11001','10101','10011','10011','10001'],
    'O': ['01110','10001','10001','10001','10001','10001','01110'],
    'V': ['10001','10001','10001','10001','01010','01010','00100'],
    'A': ['01110','10001','10001','11111','10001','10001','10001'],
    'P': ['11110','10001','10001','11110','10000','10000','10000'],
    ' ': ['00000','00000','00000','00000','00000','00000','00000'],
  };

  @override
  void paint(Canvas canvas, Size size) {
    const word = 'NOVA VPN';
    const columns = 47;
    const rows = 7;
    final cell = math.min(size.width / columns, size.height / rows) * .91;
    final wordWidth = columns * cell;
    final wordHeight = rows * cell;
    final left = (size.width - wordWidth) / 2;
    final top = (size.height - wordHeight) / 2;
    final targets = <Offset>[];

    var columnOffset = 0;
    for (final character in word.split('')) {
      final glyph = _glyphs[character]!;
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < 5; x++) {
          if (glyph[y][x] == '1') {
            // Several small particles per lit pixel create a dense neon word.
            for (var dot = 0; dot < 3; dot++) {
              final jitter = (dot - 1) * cell * .16;
              targets.add(Offset(
                left + (columnOffset + x + .5) * cell + jitter,
                top + (y + .5) * cell - jitter,
              ));
            }
          }
        }
      }
      columnOffset += 6;
    }

    final random = math.Random(26071366);
    final phase = Curves.easeInOutCubic.transform(
      (progress / .75).clamp(0.0, 1.0),
    );
    final palette = [
      const Color(0xFF28D7FF),
      const Color(0xFF397BFF),
      const Color(0xFF8A5CFF),
      const Color(0xFFE04DFF),
      const Color(0xFF35F0C5),
      const Color(0xFFFF5EB8),
    ];

    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final start = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final point = Offset.lerp(start, target, phase)!;
      final twinkle = .78 + .22 * math.sin(progress * math.pi * 8 + i * .31).abs();
      final color = palette[i % palette.length];
      final halo = Paint()
        ..color = color.withValues(alpha: lightTheme ? .34 : .52)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.2);
      canvas.drawCircle(point, cell * .23, halo);
      final paint = Paint()
        ..color = color.withValues(alpha: twinkle)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
      canvas.drawCircle(point, cell * .15, paint);
      final core = Paint()..color = color.withValues(alpha: 1);
      canvas.drawCircle(point, cell * .075, core);
    }
  }

  @override
  bool shouldRepaint(covariant _NovaWordParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Rotating neon trails orbit the NOVA letter N, matching the lower emblem
/// animation from the approved loading-page reference.
class NovaOrbitNAnimation extends StatefulWidget {
  const NovaOrbitNAnimation({super.key, this.size = 104, this.lightTheme = false});

  final double size;
  final bool lightTheme;

  @override
  State<NovaOrbitNAnimation> createState() => _NovaOrbitNAnimationState();
}

class _NovaOrbitNAnimationState extends State<NovaOrbitNAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
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
          painter: _NovaOrbitNPainter(_controller.value, lightTheme: widget.lightTheme),
        ),
      );
}

class _NovaOrbitNPainter extends CustomPainter {
  _NovaOrbitNPainter(this.progress, {required this.lightTheme});

  final double progress;
  final bool lightTheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final side = math.min(size.width, size.height);
    final glow = Paint()
      ..color = const Color(0xFF16BFFF).withValues(alpha: lightTheme ? .18 : .38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(center, side * .39, glow);

    final letter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          fontSize: side * .58,
          fontWeight: FontWeight.w900,
          color: lightTheme ? const Color(0xFF123B68) : const Color(0xFFF0FCFF),
          shadows: [
            Shadow(color: const Color(0xFF28D7FF), blurRadius: 18),
            Shadow(color: const Color(0xFF8A5CFF), blurRadius: 27),
            Shadow(color: const Color(0xFFFFFFFF).withValues(alpha: .55), blurRadius: 7),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    letter.paint(canvas, center - Offset(letter.width / 2, letter.height / 2));

    const colors = [
      Color(0xFF20E5FF), Color(0xFF8A5CFF),
      Color(0xFFFF4DB8), Color(0xFF35F0C5),
    ];
    for (var i = 0; i < colors.length; i++) {
      final direction = i.isEven ? 1.0 : -1.0;
      final speed = 1.0 + i * .24;
      final angle = progress * math.pi * 2 * direction * speed + i * .72;
      final width = side * (.91 - i * .055);
      final height = side * (.25 + i * .045);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((i - 1.5) * .34 + math.sin(progress * math.pi * 2 + i) * .10);
      final ringRect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
      final glowRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.2
        ..color = colors[i].withValues(alpha: .48)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawOval(ringRect, glowRing);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.15
        ..color = colors[i].withValues(alpha: .98);
      canvas.drawOval(ringRect, ring);
      final orbitX = math.cos(angle) * width * .5;
      final orbitY = math.sin(angle) * height * .5;
      final cometGlow = Paint()
        ..color = colors[i].withValues(alpha: .82)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(orbitX, orbitY), 5.2, cometGlow);
      final cometCore = Paint()..color = Colors.white.withValues(alpha: .98);
      canvas.drawCircle(Offset(orbitX, orbitY), 2.0, cometCore);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _NovaOrbitNPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.lightTheme != lightTheme;
}
