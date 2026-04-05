import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Reusable morphing FAB — same visual style as the shell's FAB.
/// Used both in AppShell (for nav tabs) and standalone pages (e.g., Accounts).
class AppFab extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  const AppFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
  });

  @override
  State<AppFab> createState() => _AppFabState();
}

class _AppFabState extends State<AppFab> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _longPressing = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.icon != oldWidget.icon && _longPressing) {
      setState(() => _longPressing = false);
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    setState(() => _longPressing = true);
    _pulseCtrl.repeat(reverse: true);
    HapticFeedback.mediumImpact();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    setState(() => _longPressing = false);
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _longPressing
        ? AppTheme.colorExpense.withValues(alpha: 0.35)
        : AppTheme.colorTransfer.withValues(alpha: 0.3);
    final borderColor = _longPressing
        ? AppTheme.colorExpense.withValues(alpha: 0.4)
        : AppTheme.colorTransfer.withValues(alpha: 0.25);
    final glowColor = _longPressing
        ? AppTheme.colorExpense.withValues(alpha: 0.5)
        : AppTheme.colorTransfer.withValues(alpha: 0.35);

    return GestureDetector(
      onLongPressStart: widget.onLongPress != null ? _onLongPressStart : null,
      onLongPressEnd: widget.onLongPress != null ? _onLongPressEnd : null,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final scale = _longPressing ? 1.0 + (_pulseCtrl.value * 0.12) : 1.0;
          return Transform.scale(
            scale: scale,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: _longPressing ? 24 : 16,
                        spreadRadius: _longPressing ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return RotationTransition(
                          turns: Tween(begin: 0.7, end: 1.0).animate(animation),
                          child: ScaleTransition(scale: animation, child: child),
                        );
                      },
                      child: Icon(
                        _longPressing ? Icons.mic_rounded : widget.icon,
                        key: ValueKey(_longPressing ? Icons.mic_rounded : widget.icon),
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
