import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import 'package:google_fonts/google_fonts.dart';

class CardAlertBanner extends StatelessWidget {
  final String cardName;
  final double amount;
  final DateTime dueDate;
  final DateTime closingDate;

  final bool isClosingSoon;

  const CardAlertBanner({
    super.key,
    required this.cardName,
    required this.amount,
    required this.dueDate,
    required this.closingDate,
    this.isClosingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysToDue = dueDate.difference(now).inDays;
    final color = isClosingSoon ? AppTheme.colorWarning : (daysToDue <= 3 ? AppTheme.colorExpense : AppTheme.colorWarning);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.credit_card_rounded, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClosingSoon ? 'Cierre de tarjeta: $cardName' : 'Vencimiento de pago: $cardName',
                  style: GoogleFonts.inter(
                    color: isClosingSoon ? AppTheme.colorWarning : AppTheme.colorExpense,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                   isClosingSoon 
                      ? 'Cierra en ${closingDate.difference(now).inDays} días (${closingDate.day}/${closingDate.month})'
                      : daysToDue == 0 
                          ? 'Vence HOY' 
                          : 'Vence en $daysToDue días (${dueDate.day}/${dueDate.month})',
                  style: TextStyle(color: (isClosingSoon ? AppTheme.colorWarning : AppTheme.colorExpense).withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            formatAmount(amount),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
