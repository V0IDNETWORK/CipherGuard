import 'package:flutter/material.dart';
import '../../core/config/constants.dart';
import '../../core/services/app_state.dart';
import '../../core/crypto/crypto_engine.dart';
import '../../data/models/vault_entry.dart';
import '../../widgets/common_widgets.dart';

class DashboardPage extends StatefulWidget {
  final AppState appState;
  const DashboardPage({super.key, required this.appState});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _fadeIn =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fadeIn,
        child: AnimatedBuilder(
          animation: as,
          builder: (_, __) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(as)),
              SliverToBoxAdapter(child: _buildSecurityScore(as)),
              SliverToBoxAdapter(child: _buildStatsRow(as)),
              SliverToBoxAdapter(child: _buildHealthCards(as)),
              SliverToBoxAdapter(child: _buildCategoryBreakdown(as)),
              SliverToBoxAdapter(child: _buildRecentActivity(as)),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppState as) {
    final greeting = as.fullName.isNotEmpty
        ? '${as.tr('greeting')}, ${as.fullName.split(' ').first}'
        : as.tr('greeting');
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(as.tr('security_overview'),
                    style: const TextStyle(
                        color: kTextMuted, fontSize: 10, letterSpacing: 3)),
                const SizedBox(height: 4),
                NeonText(greeting,
                    fontSize: 26, fontWeight: FontWeight.w900, gradient: true),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => as.lock(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kError.withValues(alpha: 0.1),
                border: Border.all(color: kError.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.lock_rounded, color: kError, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityScore(AppState as) {
    final score = as.securityScore;
    final color = score >= 80
        ? kSuccess
        : score >= 50
            ? kWarning
            : kError;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        gradientColors: [
          color.withValues(alpha: 0.08),
          kSurface2.withValues(alpha: 0.5)
        ],
        borderColor: color.withValues(alpha: 0.3),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    backgroundColor: kSurface3,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeWidth: 5,
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SECURITY SCORE',
                      style: TextStyle(
                          color: kTextMuted, fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(
                    score >= 80
                        ? 'EXCELLENT'
                        : score >= 60
                            ? 'GOOD'
                            : score >= 40
                                ? 'MODERATE'
                                : 'AT RISK',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${as.vault.length} items protected',
                    style: const TextStyle(color: kTextDim, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(AppState as) {
    final favoriteCount = as.vault.where((e) => e.isFavorite).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: _statCard('${as.vault.length}', 'VAULT\nITEMS',
                  Icons.key_rounded, AppColors.gradientPrimary)),
          const SizedBox(width: 12),
          Expanded(
              child: _statCard('$favoriteCount', 'FAVORITE\nITEMS',
                  Icons.star_rounded, AppColors.gradientGold)),
          const SizedBox(width: 12),
          Expanded(
              child: _statCard(
                  '${as.weakPasswordCount}',
                  'WEAK\nPASSWORDS',
                  Icons.warning_rounded,
                  as.weakPasswordCount > 0
                      ? AppColors.gradientFire
                      : AppColors.gradientSuccess)),
        ],
      ),
    );
  }

  Widget _statCard(
      String value, String label, IconData icon, List<Color> grad) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: grad.first.withValues(alpha: 0.25),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(colors: grad),
            ),
            child: Icon(icon, color: kText, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: grad.first,
                  fontWeight: FontWeight.w900,
                  fontSize: 24)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: kTextDim, fontSize: 9, letterSpacing: 1),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHealthCards(AppState as) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VAULT HEALTH',
              style:
                  TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          _healthRow(
            Icons.content_copy_rounded,
            'Duplicate Passwords',
            '${as.duplicatePasswordCount} found',
            as.duplicatePasswordCount > 0 ? kError : kSuccess,
          ),
          const SizedBox(height: 8),
          _healthRow(
            Icons.lock_open_rounded,
            'Weak Passwords',
            '${as.weakPasswordCount} need attention',
            as.weakPasswordCount > 0 ? kWarning : kSuccess,
          ),
          const SizedBox(height: 8),
          _healthRow(
            as.useBiometrics || as.hasMasterPassword
                ? Icons.verified_rounded
                : Icons.error_rounded,
            'Authentication',
            _authStatusLabel(as),
            as.useBiometrics || as.hasMasterPassword ? kSuccess : kError,
          ),
        ],
      ),
    );
  }

  String _authStatusLabel(AppState as) {
    if (as.hasMasterPassword && as.useBiometrics) {
      return 'Password + Biometric';
    }
    if (as.useBiometrics) return 'Biometric enabled';
    if (as.hasMasterPassword) return 'Master password set';
    return 'Not configured';
  }

  Widget _healthRow(
      IconData icon, String title, String status, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: color.withValues(alpha: 0.2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 18),
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
                Text(status, style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: kTextMuted.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(AppState as) {
    final breakdown = as.categoryBreakdown;
    if (breakdown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CATEGORY BREAKDOWN',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: breakdown.entries.map((e) {
              final grad = e.key.gradient;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                      colors: grad
                          .map((c) => c.withValues(alpha: 0.15))
                          .toList()),
                  border: Border.all(
                      color: grad.first.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(e.key.icon, color: grad.first, size: 14),
                    const SizedBox(width: 6),
                    Text('${e.key.label}  ${e.value}',
                        style: TextStyle(
                            color: grad.first,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(AppState as) {
    final events = as.auditLog.take(5).toList();
    if (events.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECENT ACTIVITY',
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
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(color: color, blurRadius: 8)
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.detail,
                                style: const TextStyle(
                                    color: kText, fontSize: 12)),
                            Text(
                              _formatTime(e.timestamp),
                              style: const TextStyle(
                                  color: kTextMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: color.withValues(alpha: 0.12),
                        ),
                        child: Text(e.action,
                            style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
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

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
