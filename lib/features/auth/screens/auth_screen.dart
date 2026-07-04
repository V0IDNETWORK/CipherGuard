import 'dart:math';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/particle_system.dart';

class AuthScreen extends StatefulWidget {
  final AppState appState;
  const AuthScreen({super.key, required this.appState});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _pulseCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _rotateCtrl;
  late Animation<double> _pulse;
  late Animation<double> _shake;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
    _pulse = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _shake = Tween<double>(begin: -1.0, end: 1.0)
        .animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _rotate = Tween<double>(begin: 0, end: 1).animate(_rotateCtrl);

    if (widget.appState.useBiometrics && !widget.appState.hasMasterPassword) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryPassword() async {
    final pwd = _pwCtrl.text;
    if (pwd.isEmpty) return;
    if (widget.appState.isLockedOut) {
      setState(() => _error = 'Too many failed attempts. Wait 5 minutes.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.appState.authenticateWithPassword(pwd);
    if (!mounted) return;
    if (ok) {
      await widget.appState.storeSessionKey(pwd);
      setState(() => _loading = false);
    } else {
      _pwCtrl.clear();
      _shakeCtrl.forward(from: 0);
      setState(() {
        _loading = false;
        _error = widget.appState.isLockedOut
            ? 'Too many failed attempts. Wait 5 minutes.'
            : 'Incorrect password. ${5 - widget.appState.failedAttempts} attempts remaining.';
      });
    }
  }

  Future<void> _tryBiometric() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.appState.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) {
        _error = widget.appState.lastBiometricError;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.4,
                  colors: [Color(0xFF1A0030), Color(0xFF050505)],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: GridPainter(0.8))),
          ParticleSystem(child: const SizedBox.expand(), count: 40),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(as),
                    const SizedBox(height: 40),
                    _buildAuthCard(as),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(AppState as) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _rotate]),
      builder: (_, __) => Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _rotate.value * 2 * pi,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kNeon.withValues(alpha: 0.12 * _pulse.value),
                        width: 1),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -_rotate.value * 2 * pi * 0.6,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kPrimary.withValues(alpha: 0.25 * _pulse.value),
                        width: 1.5),
                  ),
                ),
              ),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: AppColors.gradientPrimary,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: kPrimary.withValues(alpha: 0.6 * _pulse.value),
                        blurRadius: 40,
                        spreadRadius: 4),
                    BoxShadow(
                        color: kNeon.withValues(alpha: 0.2 * _pulse.value),
                        blurRadius: 70,
                        spreadRadius: 10),
                  ],
                  border: Border.all(
                      color: kNeon.withValues(alpha: 0.6 * _pulse.value),
                      width: 2),
                ),
                child: const Icon(Icons.shield_rounded, color: kText, size: 42),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const NeonText('CIPHERGUARD',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              gradient: true),
          const SizedBox(height: 4),
          Text(
            as.fullName.isNotEmpty
                ? 'WELCOME BACK, ${as.fullName.split(' ').first.toUpperCase()}'
                : as.tr('auth_required'),
            style: const TextStyle(
                color: kTextDim, fontSize: 10, letterSpacing: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard(AppState as) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) => Transform.translate(
        offset: Offset(_error != null ? _shake.value * 8 : 0, 0),
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient:
              const LinearGradient(colors: [Color(0x12FFFFFF), Color(0x06FFFFFF)]),
          border: Border.all(
              color: _error != null
                  ? kError.withValues(alpha: 0.5)
                  : kGlassBorder,
              width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AUTHENTICATION REQUIRED',
                style: TextStyle(
                    color: kTextMuted, fontSize: 10, letterSpacing: 3)),
            const SizedBox(height: 20),
            if (as.useBiometrics) ...[
              _buildBiometricButton(as),
              if (as.hasMasterPassword) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: Divider(color: kGlassBorder2.withValues(alpha: 0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR',
                        style: TextStyle(
                            color: kTextMuted.withValues(alpha: 0.6),
                            fontSize: 10,
                            letterSpacing: 3)),
                  ),
                  Expanded(
                      child: Divider(color: kGlassBorder2.withValues(alpha: 0.5))),
                ]),
                const SizedBox(height: 16),
              ],
            ],
            if (as.hasMasterPassword) ...[
              _buildPasswordField(as),
              const SizedBox(height: 16),
              _buildUnlockButton(as),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildError(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricButton(AppState as) {
    return GestureDetector(
      onTap: _loading ? null : _tryBiometric,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
              colors: AppColors.gradientCyan
                  .map((c) => c.withValues(alpha: 0.12))
                  .toList()),
          border: Border.all(color: kCyan.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: kCyan.withValues(alpha: 0.15), blurRadius: 20)
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              as.availableBiometrics.contains(BiometricType.face)
                  ? Icons.face_rounded
                  : Icons.fingerprint_rounded,
              color: kCyan,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              as.availableBiometrics.contains(BiometricType.face)
                  ? 'USE FACE ID'
                  : 'USE FINGERPRINT',
              style: const TextStyle(
                  color: kCyan,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(AppState as) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _error != null ? kError.withValues(alpha: 0.4) : kGlassBorder),
        gradient:
            const LinearGradient(colors: [Color(0x10FFFFFF), Color(0x06FFFFFF)]),
      ),
      child: TextField(
        controller: _pwCtrl,
        obscureText: _obscure,
        onSubmitted: (_) => _loading ? null : _tryPassword(),
        style: const TextStyle(color: kText, fontSize: 15),
        decoration: InputDecoration(
          hintText: as.tr('master_password'),
          hintStyle: const TextStyle(color: kTextMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon:
              const Icon(Icons.lock_outline_rounded, color: kNeon, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: kTextDim,
                size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockButton(AppState as) {
    return CyberButton(
      label: _loading ? as.tr('authenticating') : as.tr('unlock_vault'),
      icon: _loading ? null : Icons.lock_open_rounded,
      onPressed: _loading ? null : _tryPassword,
      gradient: AppColors.gradientPrimary,
      width: double.infinity,
      height: 54,
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: kError.withValues(alpha: 0.08),
        border: Border.all(color: kError.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: kError, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_error!,
                  style: const TextStyle(color: kError, fontSize: 12))),
        ],
      ),
    );
  }
}
