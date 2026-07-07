import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../widgets/common_widgets.dart';
import '../widgets/master_password_setup_sheet.dart';
import '../widgets/fingerprint_setup_sheet.dart';

class OnboardingScreen extends StatelessWidget {
  final AppState appState;
  const OnboardingScreen({super.key, required this.appState});

  void _showPasswordSetup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MasterPasswordSetupSheet(appState: appState),
    );
  }

  void _showFingerprintSetup(BuildContext context) {
    // Always open the sheet when hardware is present — even if not enrolled.
    // The sheet will trigger the system prompt, which handles enrollment flow.
    if (!appState.fingerprintHardwarePresent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'This device does not support fingerprint authentication.',
        ),
        backgroundColor: kSurface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    // If hardware present but not enrolled, offer to open device settings.
    if (!appState.fingerprintAvailable) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kSurface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kGlassBorder),
          ),
          title: const Text('Fingerprint Not Set Up',
              style: TextStyle(color: kText, fontWeight: FontWeight.w700)),
          content: const Text(
            'You haven\'t enrolled a fingerprint on this device yet.\n\n'
            'Go to Settings → Security → Fingerprint, add your fingerprint, '
            'then come back and tap this card again.',
            style: TextStyle(color: kTextDim, fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('LATER',
                  style: TextStyle(color: kTextDim)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Open device security settings so user can enroll.
                const MethodChannel('cipherguard/settings')
                    .invokeMethod('openSecuritySettings')
                    .catchError((_) {});
              },
              child: const Text('OPEN SETTINGS',
                  style: TextStyle(
                      color: kNeon, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FingerprintSetupSheet(appState: appState),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.5,
            colors: [Color(0xFF180030), kBg],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: appState,
            builder: (context, _) => Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildHeader(),
                        const SizedBox(height: 28),
                        _buildSectionLabel('SELECT AUTHENTICATION METHODS'),
                        const SizedBox(height: 14),
                        _buildPasswordCard(context),
                        const SizedBox(height: 10),
                        _buildFingerprintCard(context),
                        const SizedBox(height: 20),
                        _buildStatusPanel(),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: _buildInitButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: AppColors.gradientPrimary),
            boxShadow: [
              BoxShadow(
                  color: kPrimary.withValues(alpha: 0.5),
                  blurRadius: 28,
                  spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.security_rounded, color: kText, size: 32),
        ),
        const SizedBox(height: 16),
        const NeonText('CHOOSE YOUR\nPROTECTION',
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            gradient: true),
        const SizedBox(height: 6),
        const Text('Enable one or both methods',
            style: TextStyle(color: kTextDim, fontSize: 13)),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            color: kTextMuted, fontSize: 9, letterSpacing: 3));
  }

  Widget _buildPasswordCard(BuildContext context) {
    final enabled = appState.hasMasterPassword;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: enabled ? kPrimary.withValues(alpha: 0.5) : kGlassBorder2,
      gradientColors: enabled
          ? AppColors.gradientPrimary
              .map((c) => c.withValues(alpha: 0.12))
              .toList()
          : null,
      onTap: () => _showPasswordSetup(context),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                  colors: enabled
                      ? AppColors.gradientPrimary
                      : [kSurface3, kSurface2]),
            ),
            child: Icon(Icons.lock_outline_rounded,
                color: enabled ? kText : kTextDim, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Master Password',
                    style: TextStyle(
                        color: enabled ? kText : kTextDim,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                    enabled
                        ? 'Configured — tap to change'
                        : 'Set a strong master password',
                    style: TextStyle(
                        color: enabled ? kNeon : kTextMuted, fontSize: 11)),
              ],
            ),
          ),
          _statusDot(enabled),
        ],
      ),
    );
  }

  Widget _buildFingerprintCard(BuildContext context) {
    final enabled = appState.useBiometrics;
    final enrolled = appState.fingerprintAvailable;
    final hardwarePresent = appState.fingerprintHardwarePresent;

    // Card is always tappable when hardware is present.
    // Even "not enrolled" state is actionable — tap opens settings dialog.
    final tappable = hardwarePresent;
    final dimmed = !hardwarePresent;

    String subtitle;
    Color subtitleColor;
    if (!hardwarePresent) {
      subtitle = 'No fingerprint hardware on this device';
      subtitleColor = kTextMuted;
    } else if (enabled) {
      subtitle = 'Active — tap to manage';
      subtitleColor = kCyan;
    } else if (!enrolled) {
      subtitle = 'Tap to set up fingerprint in settings';
      subtitleColor = kWarning;
    } else {
      subtitle = 'Tap to enable fingerprint unlock';
      subtitleColor = kTextMuted;
    }

    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderColor: enabled
            ? kCyan.withValues(alpha: 0.5)
            : enrolled
                ? kGlassBorder2
                : hardwarePresent
                    ? kWarning.withValues(alpha: 0.3)
                    : kGlassBorder2,
        gradientColors: enabled
            ? AppColors.gradientCyan
                .map((c) => c.withValues(alpha: 0.10))
                .toList()
            : null,
        onTap: tappable ? () => _showFingerprintSetup(context) : null,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                    colors: enabled
                        ? AppColors.gradientCyan
                        : enrolled
                            ? [kSurface3, kSurface2]
                            : [kSurface3, kSurface2]),
              ),
              child: Icon(Icons.fingerprint_rounded,
                  color: enabled
                      ? kText
                      : hardwarePresent
                          ? (enrolled ? kTextDim : kWarning)
                          : kTextMuted,
                  size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Fingerprint',
                          style: TextStyle(
                              color: enabled ? kText : kTextDim,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      if (hardwarePresent && !enrolled && !enabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: kWarning.withValues(alpha: 0.12),
                            border: Border.all(
                                color: kWarning.withValues(alpha: 0.4)),
                          ),
                          child: const Text('SETUP NEEDED',
                              style: TextStyle(
                                  color: kWarning,
                                  fontSize: 8,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                      if (!hardwarePresent) ...[
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
                                  letterSpacing: 0.8)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: subtitleColor, fontSize: 11)),
                ],
              ),
            ),
            _statusDot(enabled),
          ],
        ),
      ),
    );
  }

  Widget _statusDot(bool active) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? kSuccess.withValues(alpha: 0.14) : kSurface3,
        border: Border.all(
            color: active ? kSuccess.withValues(alpha: 0.5) : kGlassBorder2),
      ),
      child: Icon(active ? Icons.check_rounded : Icons.add_rounded,
          color: active ? kSuccess : kTextDim, size: 16),
    );
  }

  Widget _buildStatusPanel() {
    final hasAny = appState.hasMasterPassword || appState.useBiometrics;
    final hardwarePresent = appState.fingerprintHardwarePresent;
    final enrolled = appState.fingerprintAvailable;

    String message;
    Color color;
    IconData icon;

    if (hasAny) {
      message = 'Authentication ready — tap Initialize to continue';
      color = kSuccess;
      icon = Icons.verified_rounded;
    } else if (hardwarePresent && !enrolled) {
      message = 'Set a master password, or enroll a fingerprint in device settings first';
      color = kWarning;
      icon = Icons.info_outline_rounded;
    } else {
      message = 'Set a master password to continue';
      color = kWarning;
      icon = Icons.info_outline_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ),
            ],
          ),
          if (appState.hasMasterPassword || appState.useBiometrics) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (appState.hasMasterPassword)
                  _badge(Icons.lock_rounded, 'Password', kPrimary),
                if (appState.hasMasterPassword && appState.useBiometrics)
                  const SizedBox(width: 8),
                if (appState.useBiometrics)
                  _badge(Icons.fingerprint_rounded, 'Fingerprint', kCyan),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildInitButton() {
    // Only require master password OR fingerprint actually enabled.
    // "hardware present but not enrolled" still blocks — user must complete setup.
    final canProceed = appState.hasMasterPassword || appState.useBiometrics;
    return CyberButton(
      label: 'INITIALIZE CIPHERGUARD',
      icon: Icons.rocket_launch_rounded,
      onPressed: canProceed ? appState.lock : null,
      gradient: AppColors.gradientNeon,
      width: double.infinity,
      height: 54,
    );
  }
}
