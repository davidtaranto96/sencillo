import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../features/transactions/domain/models/transaction.dart';
import '../../../../features/transactions/presentation/widgets/add_transaction_bottom_sheet.dart' show kCategoryEmojis, AddTransactionBottomSheet;
import '../../../../core/utils/format_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIncome = transaction.type == TransactionType.income || transaction.type == TransactionType.loanReceived;
    final color = colorForType(transaction.type);
    final emoji = kCategoryEmojis[transaction.categoryId] ?? _emojiForType(transaction.type);
    // For shared expenses show the TOTAL paid — the person owes you back their portion
    final displayAmount = transaction.isShared
        ? (transaction.sharedTotalAmount ?? transaction.amount)
        : transaction.amount;

    return InkWell(
      onTap: () => context.push('/transactions/${transaction.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        formatDate(transaction.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                      if (transaction.isShared) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.colorWarning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Compartido',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.colorWarning),
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
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                ),
                if (transaction.isShared && (transaction.sharedOtherAmount ?? 0) > 0)
                  Text(
                    'Prestado: ${formatAmount(transaction.sharedOtherAmount!, compact: true)}',
                    style: GoogleFonts.inter(fontSize: 9, color: AppTheme.colorWarning),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _emojiForType(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return '💰';
      case TransactionType.expense:
        return '💸';
      case TransactionType.transfer:
        return '🔄';
      case TransactionType.loanGiven:
        return '👆';
      case TransactionType.loanReceived:
        return '👇';
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      variant: EmptyStateVariant.compact,
      icon: Icons.auto_awesome_rounded,
      title: 'Registrá tu primer gasto con IA',
      description: 'Tocá el botón violeta y escribí en lenguaje natural.',
      extraContent: const EmptyStateExampleChip(
        text: 'café 3500',
        leadingIcon: Icons.coffee_rounded,
      ),
      ctaLabel: 'Abrir IA',
      ctaIcon: Icons.auto_awesome_rounded,
      onCta: () => AddTransactionBottomSheet.show(context),
    );
  }
}
