import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/mock_data_provider.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/transactions/domain/models/transaction.dart';

enum _FilterType { all, income, expense, shared }

final _filterProvider = StateProvider<_FilterType>((ref) => _FilterType.all);

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTxs = ref.watch(mockTransactionsProvider);
    final filter = ref.watch(_filterProvider);
    final cs = Theme.of(context).colorScheme;

    final filtered = allTxs.where((tx) {
      switch (filter) {
        case _FilterType.all:
          return true;
        case _FilterType.income:
          return tx.type == TransactionType.income;
        case _FilterType.expense:
          return tx.type == TransactionType.expense;
        case _FilterType.shared:
          return tx.isShared;
      }
    }).toList();

    // Agrupar por fecha
    final grouped = <String, List<Transaction>>{};
    for (final tx in filtered) {
      final key = formatDate(tx.date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: cs.onSurface),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: cs.onSurface),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _FilterChips(),
        ),
      ),
      body: grouped.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: grouped.length,
              itemBuilder: (context, groupIndex) {
                final dateKey = grouped.keys.elementAt(groupIndex);
                final txList = grouped[dateKey]!;
                final dayTotal = txList.fold<double>(0, (sum, tx) {
                  if (tx.type == TransactionType.income) return sum + tx.amount;
                  return sum - tx.realExpense;
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateKey,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '${dayTotal >= 0 ? '+' : ''}${formatAmount(dayTotal)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: dayTotal >= 0
                                  ? AppTheme.colorIncome
                                  : AppTheme.colorExpense,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...txList.map((tx) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TxRow(transaction: tx),
                        )),
                  ],
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Filter chips
// ─────────────────────────────────────────────────────
class _FilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_filterProvider);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _FilterType.values.map((f) {
            final selected = f == current;
            final label = switch (f) {
              _FilterType.all => 'Todos',
              _FilterType.income => 'Ingresos',
              _FilterType.expense => 'Gastos',
              _FilterType.shared => 'Compartidos',
            };
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) =>
                    ref.read(_filterProvider.notifier).state = f,
                selectedColor: cs.primary.withValues(alpha: 0.2),
                checkmarkColor: cs.primary,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Fila de transacción
// ─────────────────────────────────────────────────────
class _TxRow extends StatelessWidget {
  final Transaction transaction;
  const _TxRow({required this.transaction});

  static const _icons = {
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
    final emoji = _icons[transaction.categoryId] ?? '💳';
    final displayAmount =
        transaction.isShared ? transaction.realExpense : transaction.amount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  children: [
                    if (transaction.isShared)
                      _Tag(
                          label: 'Compartido',
                          color: AppTheme.colorWarning),
                    if (transaction.groupId != null)
                      _Tag(
                          label: 'Grupo',
                          color: AppTheme.colorTransfer),
                  ],
                ),
              ],
            ),
          ),
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
                  '↩ ${formatAmount(transaction.pendingToRecover, compact: true)}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
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

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Sin movimientos',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
