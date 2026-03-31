import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../features/transactions/domain/models/transaction.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/theme/app_theme.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  const RecentTransactionsList({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const _EmptyState();
    }
    return Column(
      children: transactions
          .map((tx) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TransactionTile(transaction: tx),
              ))
          .toList(),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  const _TransactionTile({required this.transaction});

  static const _categoryIcons = {
    'food': '🍔',
    'transport': '🚗',
    'health': '🏥',
    'entertainment': '🎬',
    'shopping': '🛍️',
    'home': '🏠',
    'education': '📚',
    'salary': '💼',
    'freelance': '💻',
    'investment_income': '📈',
    'other_expense': '💸',
    'other_income': '💰',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIncome = transaction.type == TransactionType.income;
    final color = colorForType(transaction.type);
    final emoji = _categoryIcons[transaction.categoryId] ?? '💳';
    final displayAmount = transaction.isShared
        ? transaction.realExpense
        : transaction.amount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          // Emoji icono
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),

          // Título + detalle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      formatDate(transaction.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                    ),
                    if (transaction.isShared) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.colorWarning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Compartido',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.colorWarning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Monto
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${formatAmount(displayAmount)}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (transaction.isShared && transaction.pendingToRecover > 0)
                Text(
                  'Recuperar: ${formatAmount(transaction.pendingToRecover, compact: true)}',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: AppTheme.colorWarning,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Sin movimientos aún',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
