import 'package:flutter/material.dart';
import '../../core/config/constants.dart';
import '../../core/services/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../auth/widgets/master_password_setup_sheet.dart';
import '../auth/widgets/biometric_setup_sheet.dart';

class SecurityCenterPage extends StatefulWidget {
  final AppState appState;
  const SecurityCenterPage({super.key, required this.appState});

  @override
  State<SecurityCenterPage> createState() => _SecurityCenterPageState();
}

class _SecurityCenterPageState extends State<SecurityCenterPage> {
  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: as,
        builder: (_, __) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _securityStatusCard(as)),
            SliverToBoxAdapter(child: _authMethodsCard(context, as)),
            SliverToBoxAdapter(child: _userProfileCard(as)),
            SliverToBoxAdapter(child: _languageCard(as)),
            SliverToBoxAdapter(child: _threatAnalysis(as)),
            SliverToBoxAdapter(child: _encryptionCard()),
            SliverToBoxAdapter(child: _auditLogSection(as)),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ENTERPRISE GRADE',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          SizedBox(height: 4),
          NeonText('Security Center',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              gradient: true),
        ],
      ),
    );
  }

  Widget _securityStatusCard(AppState as) {
    final score = as.securityScore;
    final color =
        score >= 80 ? kSuccess : score >= 50 ? kWarning : kError;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GlassCard(
        borderColor: color.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security_rounded, color: color, size: 22),
                const SizedBox(width: 10),
                const Text('SECURITY STATUS',
                    style: TextStyle(
                        color: kTextMuted,
                        fontSize: 10,
                        letterSpacing: 2)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: color.withValues(alpha: 0.12),
                    border:
                        Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    score >= 80
                        ? 'SECURE'
                        : score >= 50
                            ? 'MODERATE'
                            : 'AT RISK',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: kSurface3,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$score / 100',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                Text('${100 - score} points to perfect',
                    style:
                        const TextStyle(color: kTextDim, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _authMethodsCard(BuildContext context, AppState as) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AUTHENTICATION',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) =>
                  MasterPasswordSetupSheet(appState: as),
            ),
            child: _secItem(
              Icons.lock_rounded,
              'Master Password',
              as.hasMasterPassword ? 'Configured — tap to change' : 'Not set — tap to configure',
              as.hasMasterPassword,
              AppColors.gradientPrimary,
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: kTextMuted, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: as.biometricAvailable
                ? () => showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) =>
                          BiometricSetupSheet(appState: as),
                    )
                : null,
            child: _secItem(
              Icons.fingerprint,
              'Biometric Auth',
              as.useBiometrics
                  ? 'Active — tap to manage'
                  : as.biometricAvailable
                      ? 'Available — tap to enable'
                      : 'Not supported on this device',
              as.useBiometrics,
              AppColors.gradientNeon,
              trailing: as.biometricAvailable
                  ? const Icon(Icons.chevron_right_rounded,
                      color: kTextMuted, size: 20)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          _secItem(
            Icons.timer_rounded,
            'Auto-lock',
            'After 5 minutes of inactivity',
            true,
            AppColors.gradientCyan,
          ),
          const SizedBox(height: 8),
          _secItem(
            Icons.shield_rounded,
            'Brute Force Protection',
            'Lockout after 5 failed attempts',
            true,
            AppColors.gradientSuccess,
          ),
        ],
      ),
    );
  }

  Widget _secItem(
    IconData icon,
    String title,
    String status,
    bool active,
    List<Color> grad, {
    Widget? trailing,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: active
          ? grad.first.withValues(alpha: 0.25)
          : kGlassBorder2,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: active ? LinearGradient(colors: grad) : null,
              color: active ? null : kSurface3,
            ),
            child: Icon(icon,
                color: active ? kText : kTextMuted, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(status,
                    style: TextStyle(
                        color: active ? kSuccess : kTextMuted,
                        fontSize: 11)),
              ],
            ),
          ),
          trailing ??
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: active ? kSuccess : kTextMuted,
                size: 20,
              ),
        ],
      ),
    );
  }

  Widget _userProfileCard(AppState as) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('USER PROFILE',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: AppColors.gradientNeon),
                    boxShadow: [
                      BoxShadow(
                          color: kNeon.withValues(alpha: 0.3),
                          blurRadius: 16)
                    ],
                  ),
                  child: Center(
                    child: Text(
                      as.fullName.isNotEmpty
                          ? as.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: kText,
                          fontSize: 20,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          as.fullName.isNotEmpty
                              ? as.fullName
                              : 'Unknown',
                          style: const TextStyle(
                              color: kText,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text(
                          as.country.isNotEmpty
                              ? as.country
                              : 'Country not set',
                          style: const TextStyle(
                              color: kTextDim, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: kSuccess.withValues(alpha: 0.1),
                    border: Border.all(
                        color: kSuccess.withValues(alpha: 0.3)),
                  ),
                  child: const Text('ON-DEVICE',
                      style: TextStyle(
                          color: kSuccess,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageCard(AppState as) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LANGUAGE',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SELECT LANGUAGE',
                    style: TextStyle(
                        color: kTextMuted,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kSupportedLanguages.map((lang) {
                    final selected =
                        as.preferredLanguage == lang['code'];
                    return GestureDetector(
                      onTap: () =>
                          as.updateLanguage(lang['code']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: selected
                              ? const LinearGradient(
                                  colors: AppColors.gradientNeon)
                              : null,
                          color: selected ? null : kSurface3,
                          border: Border.all(
                              color: selected
                                  ? kNeon
                                  : kGlassBorder2,
                              width: selected ? 1.5 : 1),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                      color:
                                          kNeon.withValues(alpha: 0.3),
                                      blurRadius: 10)
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(lang['flag']!,
                                style:
                                    const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(lang['native']!,
                                style: TextStyle(
                                    color: selected
                                        ? kText
                                        : kTextDim,
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _threatAnalysis(AppState as) {
    final weak = as.weakPasswordCount;
    final dupe = as.duplicatePasswordCount;
    final total = as.vault.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('THREAT ANALYSIS',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                _threatRow('Weak Passwords', weak, total, kWarning),
                const SizedBox(height: 12),
                _threatRow(
                    'Duplicate Passwords', dupe, total, kError),
                const SizedBox(height: 12),
                _threatRow(
                    'At-Risk Items',
                    weak + dupe,
                    total,
                    (weak + dupe) > 0 ? kError : kSuccess),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _threatRow(
      String label, int count, int total, Color color) {
    final frac = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(color: kTextDim, fontSize: 12)),
            Text('$count / $total',
                style: TextStyle(
                    color: count > 0 ? color : kSuccess,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac.clamp(0.0, 1.0),
            backgroundColor: kSurface3,
            valueColor: AlwaysStoppedAnimation<Color>(
                count > 0 ? color : kSuccess),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _encryptionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ENCRYPTION DETAILS',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                _encRow('Algorithm', 'AES-256-GCM',
                    Icons.lock_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow('Key Derivation',
                    'PBKDF2-HMAC-SHA256 (100k iter)', Icons.key_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow('Salt Size', '256-bit (32 bytes)',
                    Icons.grain_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow(
                    'IV Size', '96-bit (12 bytes)', Icons.shuffle_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow('Storage', 'Flutter Secure Storage / Keychain',
                    Icons.storage_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow('Zero-Knowledge',
                    'Yes — keys never leave device',
                    Icons.visibility_off_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _encRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kNeon, size: 16),
        const SizedBox(width: 12),
        Text(label,
            style:
                const TextStyle(color: kTextDim, fontSize: 12)),
        const Spacer(),
        Flexible(
          child: Text(value,
              style: const TextStyle(
                  color: kText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _auditLogSection(AppState as) {
    final events = as.auditLog.take(10).toList();
    if (events.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AUDIT LOG',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: events.map((e) {
                final color = e.action == 'AUTH'
                    ? kCyan
                    : e.action == 'SECURITY'
                        ? kError
                        : e.action == 'FILES'
                            ? kWarning
                            : kNeon;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(color: color, blurRadius: 6)
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.detail,
                            style: const TextStyle(
                                color: kTextDim, fontSize: 11)),
                      ),
                      Text(
                        _fmtTime(e.timestamp),
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 10),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
