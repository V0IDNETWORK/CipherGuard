import 'package:flutter/material.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../widgets/common_widgets.dart';

class AuthScreen extends StatefulWidget {
  final AppState appState;
  const AuthScreen({super.key, required this.appState});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _shakeCtrl;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _shake = Tween<double>(begin: -1.0, end: 1.0).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    // Auto-trigger fingerprint only when it's the sole auth method.
    if (widget.appState.useBiometrics &&
        !widget.appState.hasMasterPassword) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _tryFingerprint());
    }
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Password auth ──────────────────────────────────────────────────────────
  Future<void> _tryPassword() async {
    final pwd = _pwCtrl.text.trim();
    if (pwd.isEmpty) return;

    if (widget.appState.isLockedOut) {
      setState(() =>
          _error = 'Too many failed attempts. Wait 5 minutes.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok =
        await widget.appState.authenticateWithPassword(pwd);
    if (!mounted) return;

    if (ok) {
      await widget.appState.storeSessionKey(pwd);
      setState(() => _loading = false);
    } else {
      _pwCtrl.clear();
      _shakeCtrl.forward(from: 0);
      final remaining = 5 - widget.appState.failedAttempts;
      setState(() {
        _loading = false;
        _error = widget.appState.isLockedOut
            ? 'Too many failed attempts. Wait 5 minutes.'
            : 'Incorrect password. $remaining attempt${remaining == 1 ? '' : 's'} remaining.';
      });
    }
  }

  // ── Fingerprint auth ───────────────────────────────────────────────────────
  Future<void> _tryFingerprint() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok =
        await widget.appState.authenticateWithFingerprint();
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (!ok) {
        _error = widget.appState.lastBiometricError;
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.4,
            colors: [Color(0xFF180030), kBg],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: mq.viewInsets.bottom + 16,
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            height: mq.size.height * 0.08),
                        _buildLogo(as),
                        const SizedBox(height: 36),
                        _buildCard(as),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(AppState as) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(
                  color: kPrimary.withValues(alpha: 0.5),
                  blurRadius: 32,
                  spreadRadius: 2),
            ],
            border: Border.all(
                color: kNeon.withValues(alpha: 0.4), width: 2),
          ),
          child:
              const Icon(Icons.shield_rounded, color: kText, size: 38),
        ),
        const SizedBox(height: 16),
        const NeonText('CIPHERGUARD',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 7,
            gradient: true),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: widget.appState,
          builder: (_, __) {
            final name = widget.appState.fullName;
            return Text(
              name.isNotEmpty
                  ? 'WELCOME BACK, ${name.split(' ').first.toUpperCase()}'
                  : 'AUTHENTICATION REQUIRED',
              style: const TextStyle(
                  color: kTextDim,
                  fontSize: 10,
                  letterSpacing: 3),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCard(AppState as) {
    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(_error != null ? _shake.value * 7 : 0, 0),
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: kSurface2,
          border: Border.all(
            color: _error != null
                ? kError.withValues(alpha: 0.45)
                : kGlassBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('UNLOCK VAULT',
                style: TextStyle(
                    color: kTextMuted,
                    fontSize: 10,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),

            // Fingerprint button — shown when enrolled.
            if (as.useBiometrics && as.fingerprintAvailable)
              ..._buildFingerprintSection(as),

            // Password section.
            if (as.hasMasterPassword) ...[
              if (as.useBiometrics && as.fingerprintAvailable) ...[
                const SizedBox(height: 14),
                _buildDivider(),
                const SizedBox(height: 14),
              ],
              _buildPasswordField(as),
              const SizedBox(height: 12),
              _buildUnlockButton(as),
            ],

            // Error banner.
            if (_error != null) ...[
              const SizedBox(height: 14),
              _buildError(),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFingerprintSection(AppState as) {
    return [
      GestureDetector(
        onTap: _loading ? null : _tryFingerprint,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: AppColors.gradientCyan
                    .map((c) => c.withValues(alpha: 0.10))
                    .toList()),
            border: Border.all(
                color: _loading
                    ? kCyan.withValues(alpha: 0.2)
                    : kCyan.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fingerprint_rounded,
                  color: _loading ? kTextMuted : kCyan, size: 30),
              const SizedBox(width: 12),
              Text(
                _loading ? 'SCANNING...' : 'USE FINGERPRINT',
                style: TextStyle(
                    color: _loading ? kTextMuted : kCyan,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(
          child:
              Divider(color: kGlassBorder2.withValues(alpha: 0.4))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('OR',
            style: TextStyle(
                color: kTextMuted.withValues(alpha: 0.5),
                fontSize: 10,
                letterSpacing: 3)),
      ),
      Expanded(
          child:
              Divider(color: kGlassBorder2.withValues(alpha: 0.4))),
    ]);
  }

  Widget _buildPasswordField(AppState as) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
            color: _error != null
                ? kError.withValues(alpha: 0.4)
                : kGlassBorder),
        color: kSurface3,
      ),
      child: TextField(
        controller: _pwCtrl,
        obscureText: _obscure,
        onSubmitted: (_) => _loading ? null : _tryPassword(),
        style: const TextStyle(color: kText, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Master Password',
          hintStyle: const TextStyle(color: kTextMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: kNeon, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: kTextDim,
                size: 20),
            onPressed: () =>
                setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockButton(AppState as) {
    return CyberButton(
      label: _loading ? 'VERIFYING...' : 'UNLOCK VAULT',
      icon: _loading ? null : Icons.lock_open_rounded,
      onPressed: _loading ? null : _tryPassword,
      gradient: AppColors.gradientPrimary,
      width: double.infinity,
      height: 52,
    );
  }

  Widget _buildError() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: kError.withValues(alpha: 0.07),
        border:
            Border.all(color: kError.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: kError, size: 16),
          const SizedBox(width: 9),
          Expanded(
              child: Text(_error!,
                  style: const TextStyle(
                      color: kError, fontSize: 12))),
        ],
      ),
    );
  }
}
