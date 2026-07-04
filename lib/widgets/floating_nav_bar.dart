import 'package:flutter/material.dart';
import '../core/config/constants.dart';

class FloatingNavBar extends StatefulWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;

  const FloatingNavBar({
    super.key,
    required this.activeIndex,
    required this.onTap,
    required this.labels,
  });

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleCtrl;

  static const _icons = [
    Icons.dashboard_rounded,
    Icons.lock_rounded,
    Icons.security_rounded,
    Icons.info_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: kSurface2,
          border: Border.all(color: kGlassBorder, width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 32,
                offset: const Offset(0, 8)),
            BoxShadow(
                color: kNeon.withValues(alpha: 0.06),
                blurRadius: 20),
          ],
        ),
        child: Row(
          children: List.generate(4, (i) => Expanded(child: _navItem(i))),
        ),
      ),
    );
  }

  Widget _navItem(int index) {
    final isActive = widget.activeIndex == index;
    return GestureDetector(
      onTap: () {
        _rippleCtrl.forward(from: 0);
        widget.onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isActive
              ? const LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: kPrimary.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 0),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _icons[index],
                key: ValueKey('${index}_$isActive'),
                color: isActive ? kText : kTextMuted,
                size: isActive ? 22 : 20,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 2),
              Text(
                widget.labels[index].toUpperCase(),
                style: const TextStyle(
                  color: kText,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
