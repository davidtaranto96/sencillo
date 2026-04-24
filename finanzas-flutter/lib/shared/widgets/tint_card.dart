import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Card con tinte de color en gradient suave — estilo del prototipo de Claude Design.
///
/// Patrón: `linear-gradient(155deg, color@13% → color@4% → surface@80%)` con borde
/// `color@20%`. Da un look "tinted glass" cohesivo cuando varios cards comparten
/// la pantalla con colores semánticos distintos (income, expense, primary, etc.).
class TintCard extends StatelessWidget {
  /// Color base del tinte. Suele ser semántico:
  /// `colorIncome`, `colorExpense`, `colorTransfer`, `colorWarning`, `cs.primary`.
  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  const TintCard({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // 155° en el proto ≈ topRight → bottomLeft en Flutter
          begin: const Alignment(0.4, -1),
          end: const Alignment(-0.4, 1),
          colors: [
            color.withValues(alpha: 0.13),
            color.withValues(alpha: 0.04),
            cs.surfaceContainerHigh.withValues(alpha: 0.80),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}

/// Variante "elevated" para hero principal del Home.
class TintCardHero extends StatelessWidget {
  final Color color;
  final Widget child;
  const TintCardHero({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
            cs.surfaceContainerHigh.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Helper para colorear según el tipo común de card del Home.
class TintColors {
  TintColors._();
  static Color get income => AppTheme.colorIncome;
  static Color get expense => AppTheme.colorExpense;
  static Color get transfer => AppTheme.colorTransfer;
  static Color get warning => AppTheme.colorWarning;
}
