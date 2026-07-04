import 'dart:math';
import 'package:flutter/material.dart';
import '../core/config/constants.dart';

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  double life;
  double maxLife;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.life,
    required this.maxLife,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color color;

  ParticlePainter({required this.particles, this.color = kNeon});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = color.withValues(alpha: p.opacity * (p.life / p.maxLife))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) => true;
}

class ParticleSystem extends StatefulWidget {
  final Widget child;
  final int count;
  final Color color;

  const ParticleSystem({
    super.key,
    required this.child,
    this.count = 30,
    this.color = kNeon,
  });

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _ParticleSystemState extends State<ParticleSystem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<Particle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _initParticles();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_update)
      ..repeat();
  }

  void _initParticles() {
    for (int i = 0; i < widget.count; i++) {
      _particles.add(_newParticle());
    }
  }

  Particle _newParticle() {
    final life = 60 + _rng.nextDouble() * 120;
    return Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      vx: (_rng.nextDouble() - 0.5) * 0.0004,
      vy: -0.0003 - _rng.nextDouble() * 0.0004,
      size: 0.5 + _rng.nextDouble() * 1.5,
      opacity: 0.1 + _rng.nextDouble() * 0.4,
      life: life,
      maxLife: life,
    );
  }

  void _update() {
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life--;
      if (p.life <= 0 || p.y < -0.05 || p.x < -0.05 || p.x > 1.05) {
        _particles[i] = _newParticle();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => CustomPaint(
        painter: ParticlePainter(particles: _particles, color: widget.color),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class GridPainter extends CustomPainter {
  final double opacity;

  GridPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kNeon.withValues(alpha: 0.03 * opacity)
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) => old.opacity != opacity;
}
