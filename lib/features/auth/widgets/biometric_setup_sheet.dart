import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../widgets/common_widgets.dart';

class BiometricSetupSheet extends StatefulWidget {
  final AppState appState;
  const BiometricSetupSheet({super.key, required this.appState});

  @override
  State<BiometricSetupSheet> createState() => _BiometricSetupSheetState();
}

class _BiometricSetupSheetState extends State<BiometricSetupSheet>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.appState.setupBiometrics();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _loading = false;
        _error = widget.appState.lastBiometricError ??
            'Biometric registration failed. Try again.';
      });
    }
  }

  Future<void> _disable() async {
    await widget.appState.disableBiometrics();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    final hasFace = as.availableBiometrics.contains(BiometricType.face);
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 28,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: kGlassBorder, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: kGlassBorder)),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: AppColors.gradientCyan
                        .map((c) => c.withValues(alpha: 0.25))
                        .toList()),
                border: Border.all(
                    color: kCyan.withValues(alpha: _pulse.value * 0.8),
                    width: 2),
                boxShadow: [
                  BoxShadow(
                      color: kCyan.withValues(alpha: 0.4 * _pulse.value),
                      blurRadius: 30,
                      spreadRadius: 4),
                ],
              ),
              child: Icon(
                hasFace ? Icons.face_rounded : Icons.fingerprint_rounded,
                color: kCyan,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          NeonText(hasFace ? 'FACE ID SETUP' : 'FINGERPRINT SETUP',
              fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3),
          const SizedBox(height: 6),
          Text(
            hasFace
                ? 'Use Face ID for fast, secure vault access'
                : 'Use your fingerprint for fast, secure vault access',
            style: const TextStyle(color: kTextDim, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildInfoRow(
              Icons.speed_rounded, 'Instant unlock', 'No password typing needed'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.security_rounded, 'Device-bound',
              'Biometric data never leaves your device'),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.layers_rounded, 'Works alongside password',
              'Use either method to unlock'),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: kError.withValues(alpha: 0.08),
                border: Border.all(color: kError.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: kError, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: kError, fontSize: 12))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (as.useBiometrics) ...[
            CyberButton(
              label: 'DISABLE BIOMETRIC',
              icon: Icons.no_encryption_rounded,
              onPressed: _loading ? null : _disable,
              gradient: AppColors.gradientFire,
              width: double.infinity,
              height: 54,
            ),
            const SizedBox(height: 12),
          ],
          CyberButton(
            label: _loading
                ? 'SCANNING...'
                : as.useBiometrics
                    ? 'RE-REGISTER BIOMETRIC'
                    : 'REGISTER BIOMETRIC',
            icon: _loading
                ? null
                : hasFace
                    ? Icons.face_rounded
                    : Icons.fingerprint_rounded,
            onPressed: _loading ? null : _register,
            gradient: AppColors.gradientCyan,
            width: double.infinity,
            height: 54,
          ),
          const SizedBox(height: 12),
          CyberButton(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(context),
            outlined: true,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: kCyan.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: kCyan, size: 18),
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
                    style: const TextStyle(color: kTextDim, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
