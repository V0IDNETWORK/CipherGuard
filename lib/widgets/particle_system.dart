import 'dart:math';
import 'package:flutter/material.dart';
import '../core/config/constants.dart';

class GridPainter extends CustomPainter {
  final double opacity;
  const GridPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kNeon.withValues(alpha: 0.025 * opacity)
      ..strokeWidth = 0.5;
    const step = 48.0;
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

class _Dot {
  double x, y, vx, vy, opacity;
  int life, maxLife;
  _Dot(this.x, this.y, this.vx, this.vy, this.opacity, this.life)
      : maxLife = life;
}

class _DotPainter extends CustomPainter {
  final List<_Dot> dots;
  final Color color;
  const _DotPainter(this.dots, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final d in dots) {
      paint.color =
          color.withValues(alpha: d.opacity * (d.life / d.maxLife) * 0.5);
      canvas.drawCircle(
          Offset(d.x * size.width, d.y * size.height), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => true;
}

class ParticleSystem extends StatefulWidget {
  final Widget child;
  final int count;
  final Color color;

  const ParticleSystem({
    super.key,
    required this.child,
    this.count = 18,
    this.color = kNeon,
  });

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _ParticleSystemState extends State<ParticleSystem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Dot> _dots = [];
  final Random _rng = Random();
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    final cap = widget.count.clamp(0, 24);
    for (int i = 0; i < cap; i++) {
      _dots.add(_newDot());
    }
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 66),
    )
      ..addListener(_update)
      ..repeat();
  }

  _Dot _newDot() {
    final life = 80 + _rng.nextInt(100);
    return _Dot(
      _rng.nextDouble(),
      _rng.nextDouble(),
      (_rng.nextDouble() - 0.5) * 0.0003,
      -0.0002 - _rng.nextDouble() * 0.0003,
      0.1 + _rng.nextDouble() * 0.3,
      life,
    );
  }

  void _update() {
    _tick++;
    if (_tick % 2 != 0) return;
    for (int i = 0; i < _dots.length; i++) {
      final d = _dots[i];
      d.x += d.vx;
      d.y += d.vy;
      d.life--;
      if (d.life <= 0 || d.y < -0.05 || d.x < -0.05 || d.x > 1.05) {
        _dots[i] = _newDot();
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => CustomPaint(
          painter: _DotPainter(_dots, widget.color),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
