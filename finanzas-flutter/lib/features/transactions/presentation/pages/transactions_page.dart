import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/transactions/domain/models/transaction.dart';

enum _FilterType { all, income, expense, shared }

final _filterProvider = StateProvider<_FilterType>((ref) => _FilterType.all);

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(transactionsStreamProvider);
    final filterValue = ref.watch(_filterProvider);
    final cs = Theme.of(context).colorScheme;

    return txsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error DB: $err'))),
      data: (allTxs) {
        final filtered = allTxs.where((tx) {
          final matchesSearch = tx.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                               (tx.note?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          if (!matchesSearch) return false;

          switch (filterValue) {
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
            title: _isSearching 
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Buscar movimiento...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => setState(() => _searchQuery = val),
                )
              : const Text('Movimientos'),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: cs.onSurface),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      _isSearching = false;
                      _searchQuery = '';
                      _searchController.clear();
                    } else {
                      _isSearching = true;
                    }
                  });
                },
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
      },
    );
  }
}

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

class _TxRow extends StatelessWidget {
  final Transaction transaction;
  const _TxRow({required this.transaction});

  static const _icons = {
    'food': '🍔',
    'cat_food': '🍔',
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
    'cat_super': '🛒',
    'cat_financial': '💳',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? AppTheme.colorIncome : AppTheme.colorExpense;
    final emoji = _icons[transaction.categoryId] ?? '💳';
    final displayAmount =
        transaction.isShared ? transaction.realExpense : transaction.amount;

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.colorExpense.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.colorExpense),
      ),
      onDismissed: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimiento eliminado')),
        );
      },
      child: InkWell(
        onLongPress: () => _showTransactionOptions(context, transaction),
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
                          _Tag(label: 'Compartido', color: AppTheme.colorWarning),
                        if (transaction.groupId != null)
                          _Tag(label: 'Grupo', color: AppTheme.colorTransfer),
                        if (transaction.isExtraordinary)
                          _Tag(label: 'Extraordinario', color: Colors.purpleAccent),
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
        ),
      ),
    );
  }

  void _showTransactionOptions(BuildContext context, Transaction tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.colorTransfer),
              title: const Text('Editar Movimiento', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white54),
              title: const Text('Duplicar', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.colorExpense),
              title: const Text('Eliminar permanentemente', style: TextStyle(color: AppTheme.colorExpense)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
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
