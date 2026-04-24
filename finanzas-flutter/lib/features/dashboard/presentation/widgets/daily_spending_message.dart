import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/confetti_overlay.dart';
import '../../../transactions/domain/models/transaction.dart' as dom_tx;

/// Mensaje contextual sobre el "no gastaste hoy" — reemplaza el texto
/// hardcoded "🎉 No gastaste nada hoy" que disparaba a las 9am incluso
/// cuando aún no podía existir un gasto.
///
/// Lógica:
///  - antes de las 20hs y sin gastos → "Aún sin gastos hoy" (gris, neutro)
///  - 20hs o más sin gastos → "🎉 Día sin gastos" (verde, sin confetti)
///  - 3+ días consecutivos sin gastar → "🔥 X días sin gastar" + confetti
///  - hay al menos 1 gasto hoy → no muestra nada
class DailySpendingMessage extends StatelessWidget {
  final List<dom_tx.Transaction> transactions;
  const DailySpendingMessage({super.key, required this.transactions});

  static const _maxStreakLookback = 30;

  ({String text, Color color, bool celebrate, int streak}) _decide(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    bool isExpense(dom_tx.Transaction t) =>
        t.type == dom_tx.TransactionType.expense ||
        t.type == dom_tx.TransactionType.transfer;

    final spentToday = transactions.any((t) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      return d == today && isExpense(t);
    });

    if (spentToday) {
      return (text: '', color: Colors.transparent, celebrate: false, streak: 0);
    }

    // Streak de días consecutivos sin gastar (máximo 30 días para perf).
    int streak = 0;
    for (int d = 0; d < _maxStreakLookback; d++) {
      final day = today.subtract(Duration(days: d));
      final hadExpense = transactions.any((t) {
        final tDay = DateTime(t.date.year, t.date.month, t.date.day);
        return tDay == day && isExpense(t);
      });
      if (hadExpense) break;
      streak++;
    }

    if (streak >= 3) {
      return (
        text: '🔥 $streak días sin gastar',
        color: AppTheme.colorIncome,
        celebrate: true,
        streak: streak,
      );
    }
    if (now.hour >= 20) {
      return (
        text: '🎉 Día sin gastos',
        color: AppTheme.colorIncome,
        celebrate: false,
        streak: streak,
      );
    }
    return (
      text: 'Aún sin gastos hoy',
      color: AppTheme.textSecondaryDark,
      celebrate: false,
      streak: streak,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final m = _decide(now);
    if (m.text.isEmpty) return const SizedBox.shrink();

    final messageWidget = Text(
      m.text,
      style: GoogleFonts.inter(
        fontSize: 12,
        color: m.color,
        fontWeight: m.celebrate ? FontWeight.w700 : FontWeight.w500,
      ),
    );

    if (!m.celebrate) {
      return messageWidget;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: messageWidget,
        ),
        const Positioned.fill(
          child: ConfettiOverlay(height: 60, particleCount: 16),
        ),
      ],
    );
  }
}
