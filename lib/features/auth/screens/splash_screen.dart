import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/config/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _progressCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..forward();
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_rotateCtrl);
    _progressAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1A0A2E), Color(0xFF050505)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([_pulseAnim, _rotateAnim, _progressAnim]),
              builder: (_, __) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: _rotateAnim.value * 2 * pi,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: kNeon.withValues(alpha: 0.15), width: 1),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: -_rotateAnim.value * 2 * pi * 0.7,
                        child: Container(
                          width: 115,
                          height: 115,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: kPrimary.withValues(alpha: 0.3),
                                width: 1.5),
                          ),
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            kAccent.withValues(alpha: 0.4),
                            Colors.transparent
                          ]),
                          boxShadow: [
                            BoxShadow(
                                color: kPrimary
                                    .withValues(alpha: 0.5 * _pulseAnim.value),
                                blurRadius: 50,
                                spreadRadius: 10),
                            BoxShadow(
                                color: kNeon
                                    .withValues(alpha: 0.2 * _pulseAnim.value),
                                blurRadius: 80,
                                spreadRadius: 20),
                          ],
                          border: Border.all(
                              color: kNeon
                                  .withValues(alpha: _pulseAnim.value * 0.7),
                              width: 2),
                        ),
                        child: Icon(Icons.shield_rounded,
                            color: kNeon.withValues(alpha: _pulseAnim.value),
                            size: 44),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [kNeon, kCyan, kNeon],
                      stops: [0, 0.5, 1],
                    ).createShader(b),
                    child: const Text(
                      'CIPHERGUARD',
                      style: TextStyle(
                        color: kText,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('SECURITY SUITE v3.0',
                      style: TextStyle(
                          color: kTextDim, fontSize: 10, letterSpacing: 5)),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 220,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progressAnim.value,
                            backgroundColor: kSurface2,
                            valueColor: AlwaysStoppedAnimation<Color>(kNeon
                                .withValues(
                                    alpha: _pulseAnim.value * 0.8 + 0.2)),
                            minHeight: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('INITIALIZING SECURITY CORE',
                            style: TextStyle(
                                color: kTextMuted, fontSize: 9, letterSpacing: 3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
