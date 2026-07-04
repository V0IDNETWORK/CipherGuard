import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/particle_system.dart';
import '../widgets/master_password_setup_sheet.dart';
import '../widgets/biometric_setup_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  final AppState appState;
  const OnboardingScreen({super.key, required this.appState});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 50, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _showPasswordSetup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MasterPasswordSetupSheet(appState: widget.appState),
    );
  }

  Future<void> _showBiometricSetup() async {
    if (!widget.appState.biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.appState.lastBiometricError ??
                'Biometric authentication is not available on this device.',
            style: const TextStyle(color: kText),
          ),
          backgroundColor: kSurface2,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BiometricSetupSheet(appState: widget.appState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridPainter(1.0))),
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
          ParticleSystem(child: const SizedBox.expand(), count: 50),
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fadeIn, _slideUp]),
              builder: (_, __) => FadeTransition(
                opacity: _fadeIn,
                child: Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: _buildHeader(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _buildSectionTitle(
                                  as.tr('select_auth')),
                              const SizedBox(height: 16),
                              _buildPasswordCard(as),
                              const SizedBox(height: 12),
                              _buildBiometricCard(as),
                              const SizedBox(height: 24),
                              _buildStatusPanel(as),
                              const SizedBox(height: 24),
                              _buildInitButton(as),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                  color: kPrimary.withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 4),
              BoxShadow(
                  color: kNeon.withValues(alpha: 0.2),
                  blurRadius: 70,
                  spreadRadius: 10),
            ],
            border: Border.all(color: kNeon.withValues(alpha: 0.4), width: 2),
          ),
          child: const Icon(Icons.security_rounded, color: kText, size: 40),
        ),
        const SizedBox(height: 16),
        const NeonText('CHOOSE YOUR\nPROTECTION',
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            gradient: true,
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text('Enable one or both authentication methods',
            style: TextStyle(color: kTextDim, fontSize: 12, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style:
            const TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3));
  }

  Widget _buildPasswordCard(AppState as) {
    final enabled = as.hasMasterPassword;
    return GestureDetector(
      onTap: _showPasswordSetup,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: enabled
                ? AppColors.gradientPrimary
                    .map((c) => c.withValues(alpha: 0.18))
                    .toList()
                : [kGlass, kGlass2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: enabled ? kPrimary : kGlassBorder2,
              width: enabled ? 1.5 : 1),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: kPrimary.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 0)
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                    colors: enabled
                        ? AppColors.gradientPrimary
                        : [kSurface3, kSurface2]),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                            color: kPrimary.withValues(alpha: 0.4),
                            blurRadius: 16)
                      ]
                    : [],
              ),
              child: Icon(Icons.lock_outline_rounded,
                  color: enabled ? kText : kTextDim, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Master Password',
                    style: TextStyle(
                        color: enabled ? kText : kTextDim,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    enabled
                        ? 'Password configured — tap to change'
                        : 'Set a strong master password',
                    style: TextStyle(
                        color: enabled ? kNeon : kTextMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? kSuccess.withValues(alpha: 0.15)
                    : kSurface3,
                border: Border.all(
                    color: enabled
                        ? kSuccess.withValues(alpha: 0.5)
                        : kGlassBorder2),
              ),
              child: Icon(
                  enabled ? Icons.check_rounded : Icons.add_rounded,
                  color: enabled ? kSuccess : kTextDim,
                  size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricCard(AppState as) {
    final enabled = as.useBiometrics;
    final available = as.biometricAvailable;
    final hasFace = as.availableBiometrics.contains(BiometricType.face);
    final hasFingerprint =
        as.availableBiometrics.contains(BiometricType.fingerprint);

    String subtitle;
    IconData icon;
    if (!available) {
      subtitle = 'Not available on this device';
      icon = Icons.fingerprint_rounded;
    } else if (enabled) {
      subtitle = 'Biometric configured — tap to manage';
      icon = hasFace ? Icons.face_rounded : Icons.fingerprint_rounded;
    } else {
      subtitle = hasFace
          ? 'Use Face ID to unlock'
          : hasFingerprint
              ? 'Use fingerprint to unlock'
              : 'Use biometrics to unlock';
      icon = hasFace ? Icons.face_rounded : Icons.fingerprint_rounded;
    }

    return GestureDetector(
      onTap: available ? _showBiometricSetup : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: enabled
                ? AppColors.gradientCyan
                    .map((c) => c.withValues(alpha: 0.15))
                    .toList()
                : [kGlass, kGlass2],
          ),
          border: Border.all(
              color: enabled
                  ? kCyan
                  : available
                      ? kGlassBorder2
                      : kGlassBorder2.withValues(alpha: 0.5),
              width: enabled ? 1.5 : 1),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: kCyan.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 0)
                ]
              : [],
        ),
        child: Opacity(
          opacity: available ? 1.0 : 0.5,
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                      colors: enabled
                          ? AppColors.gradientCyan
                          : [kSurface3, kSurface2]),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                              color: kCyan.withValues(alpha: 0.4),
                              blurRadius: 16)
                        ]
                      : [],
                ),
                child: Icon(icon,
                    color: enabled ? kText : kTextDim, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          hasFace ? 'Face ID' : 'Fingerprint',
                          style: TextStyle(
                              color: enabled ? kText : kTextDim,
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                        ),
                        if (!available) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: kSurface3,
                            ),
                            child: const Text('UNAVAILABLE',
                                style: TextStyle(
                                    color: kTextMuted,
                                    fontSize: 8,
                                    letterSpacing: 1)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: enabled ? kCyan : kTextMuted,
                            fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled
                      ? kSuccess.withValues(alpha: 0.15)
                      : kSurface3,
                  border: Border.all(
                      color: enabled
                          ? kSuccess.withValues(alpha: 0.5)
                          : kGlassBorder2),
                ),
                child: Icon(
                    enabled ? Icons.check_rounded : Icons.add_rounded,
                    color: enabled ? kSuccess : kTextDim,
                    size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPanel(AppState as) {
    final hasAny = as.hasMasterPassword || as.useBiometrics;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: hasAny
            ? kSuccess.withValues(alpha: 0.06)
            : kWarning.withValues(alpha: 0.06),
        border: Border.all(
            color: hasAny
                ? kSuccess.withValues(alpha: 0.25)
                : kWarning.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                hasAny ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: hasAny ? kSuccess : kWarning,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasAny
                      ? 'Authentication configured'
                      : 'Configure at least one method to continue',
                  style: TextStyle(
                      color: hasAny ? kSuccess : kWarning,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          if (as.hasMasterPassword || as.useBiometrics) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (as.hasMasterPassword) ...[
                  _authBadge(Icons.lock_rounded, 'Password', kPrimary),
                  const SizedBox(width: 8),
                ],
                if (as.useBiometrics)
                  _authBadge(Icons.fingerprint_rounded, 'Biometric', kCyan),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _authBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildInitButton(AppState as) {
    final canProceed = as.hasMasterPassword || as.useBiometrics;
    return CyberButton(
      label: as.tr('initialize'),
      icon: Icons.rocket_launch_rounded,
      onPressed: canProceed
          ? () {
              as.lock();
            }
          : null,
      gradient: AppColors.gradientNeon,
      width: double.infinity,
      height: 56,
    );
  }
}
