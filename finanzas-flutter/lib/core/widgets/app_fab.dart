import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/feedback_provider.dart';
import '../theme/app_theme.dart';

/// Reusable morphing FAB — same visual style as the shell's FAB.
/// Used both in AppShell (for nav tabs) and standalone pages (e.g., Accounts).
///
/// Cuando [label] es != null, el FAB se expande mostrando el ícono + texto
/// (estilo "extended FAB" de Material 3). [semanticLabel] se usa siempre para
/// accessibility (screen readers).
class AppFab extends ConsumerStatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final String? label;
  final String? semanticLabel;

  const AppFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.onDoubleTap,
    this.label,
    this.semanticLabel,
  });

  @override
  ConsumerState<AppFab> createState() => _AppFabState();
}

class _AppFabState extends ConsumerState<AppFab> with SingleTickerProviderStateMixin {
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
    appHaptic(ref, type: HapticType.medium);
    appSound(ref, type: SoundType.tap);
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

    final hasLabel = widget.label != null && !_longPressing;
    final semantic = widget.semanticLabel ?? widget.label ?? 'Acción rápida';

    return Semantics(
      label: semantic,
      button: true,
      child: GestureDetector(
        onLongPressStart: widget.onLongPress != null ? _onLongPressStart : null,
        onLongPressEnd: widget.onLongPress != null ? _onLongPressEnd : null,
        onTap: widget.onPressed,
        onDoubleTap: widget.onDoubleTap,
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
                    padding: hasLabel
                        ? const EdgeInsets.symmetric(horizontal: 18)
                        : EdgeInsets.zero,
                    // Constraints SIEMPRE finitos para que BoxConstraints.lerp pueda
                    // interpolar entre estados (con/sin label). Si el max es infinito
                    // tira "Cannot interpolate between finite and unbounded".
                    constraints: BoxConstraints(
                      minWidth: 56,
                      maxWidth: hasLabel ? 240 : 56,
                      minHeight: 56,
                      maxHeight: 56,
                    ),
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
                    child: ClipRect(
                      // ClipRect evita que el contenido se vea fuera del container
                      // durante el morph entre extended (con label) e icon-only.
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
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
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                          if (hasLabel) ...[
                            const SizedBox(width: 8),
                            // Flexible permite que el texto se comprima durante
                            // el morph cuando los constraints se reducen.
                            Flexible(
                              child: Text(
                                widget.label!,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
