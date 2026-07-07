import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../widgets/common_widgets.dart';

class FingerprintSetupSheet extends StatefulWidget {
  final AppState appState;
  const FingerprintSetupSheet({super.key, required this.appState});

  @override
  State<FingerprintSetupSheet> createState() =>
      _FingerprintSetupSheetState();
}

class _FingerprintSetupSheetState extends State<FingerprintSetupSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.appState.setupFingerprint();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      final errMsg = widget.appState.lastBiometricError ?? '';
      // If error indicates not enrolled, offer settings navigation instead.
      final isEnrollmentError = errMsg.toLowerCase().contains('enroll') ||
          errMsg.toLowerCase().contains('not set') ||
          errMsg.toLowerCase().contains('no finger');
      setState(() {
        _loading = false;
        _error = errMsg.isNotEmpty ? errMsg : 'Registration failed. Try again.';
      });
      if (isEnrollmentError && mounted) {
        _showEnrollmentDialog();
      }
    }
  }

  Future<void> _disable() async {
    await widget.appState.disableFingerprint();
    if (mounted) Navigator.pop(context);
  }

  void _openSecuritySettings() {
    const MethodChannel('cipherguard/settings')
        .invokeMethod('openSecuritySettings')
        .catchError((_) {});
  }

  void _showEnrollmentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kGlassBorder),
        ),
        title: const Text('Enroll a Fingerprint First',
            style:
                TextStyle(color: kText, fontWeight: FontWeight.w700)),
        content: const Text(
          'No fingerprint is enrolled on this device.\n\n'
          'Open device Settings → Security → Fingerprint, '
          'add your fingerprint, then come back and tap Register.',
          style: TextStyle(color: kTextDim, height: 1.6, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE',
                style: TextStyle(color: kTextDim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openSecuritySettings();
            },
            child: const Text('OPEN SETTINGS',
                style: TextStyle(
                    color: kNeon, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    final enrolled = as.fingerprintAvailable;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(28)),
        border:
            Border(top: BorderSide(color: kGlassBorder, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: kGlassBorder)),
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: AppColors.gradientCyan
                      .map((c) => c.withValues(alpha: 0.2))
                      .toList()),
              border: Border.all(
                  color: kCyan.withValues(alpha: 0.6), width: 2),
              boxShadow: [
                BoxShadow(
                    color: kCyan.withValues(alpha: 0.3),
                    blurRadius: 24)
              ],
            ),
            child: const Icon(Icons.fingerprint_rounded,
                color: kCyan, size: 38),
          ),
          const SizedBox(height: 14),
          const NeonText('FINGERPRINT SETUP',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 3),
          const SizedBox(height: 6),
          Text(
            enrolled
                ? 'Use your fingerprint for fast, secure vault access'
                : 'You need to enroll a fingerprint in device settings first',
            style: const TextStyle(color: kTextDim, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // If not enrolled, show settings shortcut as primary action.
          if (!enrolled) ...[
            _infoRow(
              Icons.settings_rounded,
              'Enroll a fingerprint first',
              'Settings → Security → Fingerprint',
            ),
            const SizedBox(height: 8),
            _infoRow(
              Icons.info_outline_rounded,
              'Then come back here',
              'Tap Register after enrolling',
            ),
            const SizedBox(height: 16),
            CyberButton(
              label: 'OPEN DEVICE SETTINGS',
              icon: Icons.open_in_new_rounded,
              onPressed: _openSecuritySettings,
              gradient: AppColors.gradientGold,
              width: double.infinity,
              height: 50,
            ),
            const SizedBox(height: 10),
          ] else ...[
            _infoRow(Icons.speed_rounded, 'Instant unlock',
                'No password typing required'),
            const SizedBox(height: 8),
            _infoRow(Icons.security_rounded, 'Hardware-backed',
                'Fingerprint data stays on your device'),
            const SizedBox(height: 8),
            _infoRow(Icons.password_rounded, 'Password fallback',
                'Password always available as backup'),
            const SizedBox(height: 16),
          ],

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: kError.withValues(alpha: 0.07),
                border:
                    Border.all(color: kError.withValues(alpha: 0.3)),
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
            ),
            const SizedBox(height: 14),
          ],

          if (as.useBiometrics) ...[
            CyberButton(
              label: 'DISABLE FINGERPRINT',
              icon: Icons.no_encryption_rounded,
              onPressed: _loading ? null : _disable,
              gradient: AppColors.gradientFire,
              width: double.infinity,
              height: 50,
            ),
            const SizedBox(height: 10),
          ],

          CyberButton(
            label: _loading
                ? 'WAITING FOR FINGERPRINT...'
                : as.useBiometrics
                    ? 'RE-REGISTER FINGERPRINT'
                    : enrolled
                        ? 'REGISTER FINGERPRINT'
                        : 'TRY REGISTER ANYWAY',
            icon: _loading ? null : Icons.fingerprint_rounded,
            onPressed: _loading ? null : _register,
            gradient: AppColors.gradientCyan,
            width: double.infinity,
            height: 50,
          ),
          const SizedBox(height: 10),
          CyberButton(
            label: 'CLOSE',
            onPressed: () => Navigator.pop(context),
            outlined: true,
            width: double.infinity,
            height: 46,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String subtitle) {
    return GlassCard(
      padding:
          const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: kCyan.withValues(alpha: 0.10),
            ),
            child: Icon(icon, color: kCyan, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        color: kTextDim, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
