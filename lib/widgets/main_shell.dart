import 'package:flutter/material.dart';
import '../core/config/constants.dart';
import '../core/services/app_state.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/vault/screens/vault_page.dart';
import '../features/security/security_center_page.dart';
import '../features/info/info_page.dart';
import 'floating_nav_bar.dart';

class MainShell extends StatefulWidget {
  final AppState appState;
  const MainShell({super.key, required this.appState});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: widget.appState.activeTab);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    widget.appState.setActiveTab(index);
    _pageCtrl.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    final mq = MediaQuery.of(context);
    return Listener(
      onPointerDown: (_) => as.resetTimer(),
      child: Scaffold(
        backgroundColor: kBg,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 1.4,
                    colors: [Color(0xFF0E0020), kBg],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: const _GridPainter(),
                ),
              ),
            ),
            Positioned.fill(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  DashboardPage(appState: as),
                  VaultPage(appState: as),
                  SecurityCenterPage(appState: as),
                  InfoPage(appState: as),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: as,
                builder: (_, __) => FloatingNavBar(
                  activeIndex: as.activeTab,
                  onTap: _onTabTapped,
                  labels: [
                    as.tr('dashboard'),
                    as.tr('vault'),
                    as.tr('security'),
                    as.tr('info'),
                  ],
                  bottomPadding: mq.padding.bottom,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x06CC66FF)
      ..strokeWidth = 0.5;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
