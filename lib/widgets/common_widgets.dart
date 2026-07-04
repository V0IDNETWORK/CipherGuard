import 'package:flutter/material.dart';
import '../core/config/constants.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.gradientColors,
    this.onTap,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: gradientColors ?? [kGlass, kGlass2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: borderColor ?? kGlassBorder, width: 1),
      ),
      child: child,
    );

    if (onTap != null) {
      return _PressEffect(onTap: onTap!, child: card);
    }
    return card;
  }
}

class _PressEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressEffect({required this.child, required this.onTap});

  @override
  State<_PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<_PressEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale =
        Tween<double>(begin: 1.0, end: 0.97).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class NeonText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final Color color;
  final bool gradient;
  final TextAlign textAlign;

  const NeonText(
    this.text, {
    super.key,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing = 0,
    this.color = kNeon,
    this.gradient = false,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        color: gradient ? kText : color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      ),
    );

    if (!gradient) return textWidget;

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [kNeon, kCyan, kNeon],
        stops: [0, 0.5, 1],
      ).createShader(bounds),
      child: textWidget,
    );
  }
}

class CyberButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final List<Color>? gradient;
  final IconData? icon;
  final bool outlined;
  final double? width;
  final double height;
  final double fontSize;

  const CyberButton({
    super.key,
    required this.label,
    this.onPressed,
    this.gradient,
    this.icon,
    this.outlined = false,
    this.width,
    this.height = 52,
    this.fontSize = 13,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 1.0, end: 0.4).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grad = widget.gradient ?? AppColors.gradientPrimary;
    final enabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => _ctrl.forward() : null,
      onTapUp: enabled
          ? (_) {
              _ctrl.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => _ctrl.reverse() : null,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => ScaleTransition(
          scale: _scale,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: widget.outlined
                    ? null
                    : LinearGradient(
                        colors: grad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                border: widget.outlined
                    ? Border.all(color: kNeon, width: 1.5)
                    : Border.all(
                        color: grad.first.withValues(alpha: 0.4), width: 1),
                boxShadow: !enabled
                    ? []
                    : [
                        BoxShadow(
                            color: grad.first
                                .withValues(alpha: 0.45 * _glow.value),
                            blurRadius: 24,
                            spreadRadius: 0),
                        BoxShadow(
                            color: grad.last
                                .withValues(alpha: 0.2 * _glow.value),
                            blurRadius: 48,
                            spreadRadius: 0),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon,
                        color: widget.outlined ? kNeon : kText, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.outlined ? kNeon : kText,
                        fontWeight: FontWeight.w800,
                        fontSize: widget.fontSize,
                        letterSpacing: 1.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CyberTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const CyberTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGlassBorder),
        gradient:
            const LinearGradient(colors: [Color(0x10FFFFFF), Color(0x06FFFFFF)]),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        onChanged: onChanged,
        keyboardType: keyboardType,
        maxLines: maxLines,
        autofocus: autofocus,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: kText, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(color: kTextDim, fontSize: 12, letterSpacing: 1),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: Icon(prefixIcon, color: kNeon, size: 20),
          suffix: suffix,
        ),
      ),
    );
  }
}

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: Color.lerp(kSurface2, kSurface3, _anim.value),
        ),
      ),
    );
  }
}
