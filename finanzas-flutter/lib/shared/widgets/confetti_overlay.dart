import 'dart:math';
import 'package:flutter/material.dart';

/// Confetti chiquito que cae 1.6s y se autoborra. Pensado para celebrar logros
/// puntuales (ej: streak de días sin gastar).
///
/// Respeta `MediaQuery.disableAnimationsOf(context)` — si está activo, no se
/// renderiza nada.
class ConfettiOverlay extends StatefulWidget {
  final double height;
  final int particleCount;
  const ConfettiOverlay({super.key, this.height = 60, this.particleCount = 20});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    final rand = Random();
    _particles = List.generate(
      widget.particleCount,
      (_) => _Particle(
        x: rand.nextDouble(),
        delay: rand.nextDouble() * 0.4,
        speed: 0.6 + rand.nextDouble() * 0.5,
        rot: rand.nextDouble() * 360,
        color: _palette[rand.nextInt(_palette.length)],
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _palette = [
    Color(0xFF6C63FF),
    Color(0xFFFFD166),
    Color(0xFFEF476F),
    Color(0xFF06D6A0),
    Color(0xFF118AB2),
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _ConfettiPainter(_particles, _ctrl.value),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double x;
  final double delay;
  final double speed;
  final double rot;
  final Color color;
  _Particle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.rot,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final progress = ((t - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (progress <= 0) continue;
      final dx = p.x * size.width;
      final dy = progress * size.height * p.speed;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate((p.rot + progress * 360) * pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -1.5, 6, 3),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
