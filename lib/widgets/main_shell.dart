import 'package:flutter/material.dart';
import '../core/config/constants.dart';
import '../core/services/app_state.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/vault/screens/vault_page.dart';
import '../features/security/security_center_page.dart';
import '../features/info/info_page.dart';
import 'floating_nav_bar.dart';
import 'particle_system.dart';

class MainShell extends StatefulWidget {
  final AppState appState;
  const MainShell({super.key, required this.appState});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _bgAnim =
        CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);

    _pages = [
      DashboardPage(appState: widget.appState),
      VaultPage(appState: widget.appState),
      SecurityCenterPage(appState: widget.appState),
      InfoPage(appState: widget.appState),
    ];
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    return Listener(
      onPointerDown: (_) => as.resetTimer(),
      child: Scaffold(
        backgroundColor: kBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgAnim,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                          0, -0.3 + _bgAnim.value * 0.1),
                      radius: 1.4,
                      colors: [
                        Color.lerp(const Color(0xFF0E0020),
                            const Color(0xFF150030),
                            _bgAnim.value)!,
                        kBg,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: GridPainter(0.5)),
            ),
            ParticleSystem(
              child: const SizedBox.expand(),
              count: 20,
              color: kNeon,
            ),
            AnimatedBuilder(
              animation: as,
              builder: (_, __) => IndexedStack(
                index: as.activeTab,
                children: _pages,
              ),
            ),
            AnimatedBuilder(
              animation: as,
              builder: (_, __) => FloatingNavBar(
                activeIndex: as.activeTab,
                onTap: as.setActiveTab,
                labels: [
                  as.tr('dashboard'),
                  as.tr('vault'),
                  as.tr('security'),
                  as.tr('info'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
