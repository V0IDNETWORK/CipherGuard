import 'package:flutter/material.dart';
import '../../../core/config/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400))
      ..forward();
    _fade = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _progress = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.1, 0.95, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
            colors: [Color(0xFF180030), kBg],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: AppColors.gradientPrimary,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        boxShadow: [
                          BoxShadow(
                              color: kPrimary.withValues(alpha: 0.55),
                              blurRadius: 40,
                              spreadRadius: 4),
                        ],
                        border: Border.all(
                            color: kNeon.withValues(alpha: 0.4),
                            width: 2),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: kText, size: 44),
                    ),
                    const SizedBox(height: 32),
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [kNeon, kCyan, kNeon],
                        stops: [0, 0.5, 1],
                      ).createShader(b),
                      child: const Text(
                        'CIPHERGUARD',
                        style: TextStyle(
                          color: kText,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('SECURITY SUITE v3.0',
                        style: TextStyle(
                            color: kTextDim,
                            fontSize: 10,
                            letterSpacing: 4)),
                    const SizedBox(height: 44),
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) => Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progress.value,
                              backgroundColor:
                                  kSurface2,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      kNeon),
                              minHeight: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('INITIALIZING',
                              style: TextStyle(
                                  color: kTextMuted,
                                  fontSize: 9,
                                  letterSpacing: 4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
