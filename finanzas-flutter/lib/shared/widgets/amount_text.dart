import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/format_utils.dart';
import '../../core/theme/app_theme.dart';

/// Muestra un monto con color y signo según tipo
class AmountText extends StatelessWidget {
  final double amount;
  final bool isIncome;
  final bool isNeutral;
  final double fontSize;
  final FontWeight fontWeight;

  const AmountText({
    super.key,
    required this.amount,
    this.isIncome = false,
    this.isNeutral = false,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    final color = isNeutral
        ? Theme.of(context).colorScheme.onSurface
        : isIncome
            ? AppTheme.colorIncome
            : AppTheme.colorExpense;

    return Text(
      formatAmount(amount),
      style: GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );
  }
}
