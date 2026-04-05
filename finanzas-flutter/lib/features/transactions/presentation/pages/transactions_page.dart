import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/transaction_service.dart';
import '../../../../core/providers/shell_providers.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/transactions/domain/models/transaction.dart';
import '../widgets/add_transaction_bottom_sheet.dart' show kCategoryEmojis;

// ─── Helpers ────────────────────────────────────────────────
String _monthShort(int month) {
  const names = [
    '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];
  return month >= 1 && month <= 12 ? names[month] : '';
}

const Map<String, String> _categoryLabels = {
  'food': 'Comida',
  'transport': 'Transporte',
  'health': 'Salud',
  'entertainment': 'Entretenimiento',
  'shopping': 'Compras',
  'home': 'Hogar',
  'education': 'Educacion',
  'services': 'Servicios',
  'salary': 'Sueldo',
  'freelance': 'Freelance',
  'transfer': 'Transferencia',
  'cat_alim': 'Supermercado',
  'cat_transp': 'Transporte',
  'cat_entret': 'Entretenimiento',
  'cat_salud': 'Salud',
  'cat_financial': 'Financiero',
  'cat_peer_to_peer': 'Entre personas',
  'cat_delivery': 'Delivery',
  'cat_subs': 'Suscripciones',
  'cat_tecno': 'Tecnologia',
  'cat_ropa': 'Ropa',
  'cat_hogar': 'Hogar',
  'cat_otros_gasto': 'Otros',
  'other_expense': 'Otro gasto',
  'other_income': 'Otro ingreso',
};

String _catLabel(String id) => _categoryLabels[id] ?? id;

enum _SortMode { byDate, byAmountDesc, byAmountAsc }

/// null = show all months (default)
final txSelectedMonthProvider = StateProvider<DateTime?>((ref) => null);

final txSelectedAccountProvider = StateProvider<String?>((ref) => null);

// ═════════════════════════════════════════════════════════════
// MAIN PAGE
// ═════════════════════════════════════════════════════════════
class TransactionsPage extends ConsumerStatefulWidget {
  /// [standalone] = true when pushed above the shell (from Más).
  /// Controls back button visibility in the SliverAppBar.
  final bool standalone;
  const TransactionsPage({super.key, this.standalone = false});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage>
    with AutomaticKeepAliveClientMixin {
  _SortMode _sortMode = _SortMode.byDate;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final txsAsync = ref.watch(transactionsStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final filterValue = ref.watch(txFilterProvider);
    final searchQuery = ref.watch(txSearchQueryProvider);
    final selectedMonth = ref.watch(txSelectedMonthProvider);
    final selectedAccountId = ref.watch(txSelectedAccountProvider);
    final cs = Theme.of(context).colorScheme;

    return txsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error DB: $err'))),
      data: (allTxs) {
        final accounts = accountsAsync.valueOrNull ?? [];
        final now = DateTime.now();

        // Base transactions (month-filtered or all)
        final baseTxs = selectedMonth != null
            ? allTxs.where((t) =>
                t.date.month == selectedMonth.month &&
                t.date.year == selectedMonth.year).toList()
            : allTxs.toList();

        // Stats for summary (current month always)
        final currentMonthTxs = allTxs.where((t) =>
            t.date.month == now.month && t.date.year == now.year).toList();
        final displayTxs = selectedMonth != null ? baseTxs : currentMonthTxs;
        final totalIncome = displayTxs
            .where((t) => t.type == TransactionType.income || t.type == TransactionType.loanReceived)
            .fold(0.0, (sum, t) => sum + t.amount);
        final totalExpense = displayTxs
            .where((t) => t.type == TransactionType.expense || t.type == TransactionType.loanGiven)
            .fold(0.0, (sum, t) => sum + t.realExpense);
        final balance = totalIncome - totalExpense;

        // Apply filters (type, search, account)
        final filtered = baseTxs.where((tx) {
          if (selectedAccountId != null && tx.accountId != selectedAccountId) return false;
          final matchesSearch = searchQuery.isEmpty ||
              tx.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (tx.note?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
          if (!matchesSearch) return false;
          switch (filterValue) {
            case TxFilterType.all: return true;
            case TxFilterType.income:
              return tx.type == TransactionType.income || tx.type == TransactionType.loanReceived;
            case TxFilterType.expense:
              return tx.type == TransactionType.expense || tx.type == TransactionType.loanGiven;
            case TxFilterType.shared: return tx.isShared;
          }
        }).toList();

        // Sort
        if (_sortMode == _SortMode.byAmountDesc) {
          filtered.sort((a, b) => b.amount.compareTo(a.amount));
        } else if (_sortMode == _SortMode.byAmountAsc) {
          filtered.sort((a, b) => a.amount.compareTo(b.amount));
        } else {
          filtered.sort((a, b) => b.date.compareTo(a.date));
        }

        // Group by date
        final grouped = <String, List<Transaction>>{};
        if (_sortMode == _SortMode.byDate) {
          for (final tx in filtered) {
            final key = _formatGroupDate(tx.date);
            grouped.putIfAbsent(key, () => []).add(tx);
          }
        } else {
          if (filtered.isNotEmpty) grouped['all'] = filtered;
        }

        // Available months for chips
        final availableMonths = <DateTime>{};
        for (final tx in allTxs) {
          availableMonths.add(DateTime(tx.date.year, tx.date.month));
        }
        availableMonths.add(DateTime(now.year, now.month));
        final sortedMonths = availableMonths.toList()..sort((a, b) => b.compareTo(a));

        // Active filter count for badge
        final activeFilters = (selectedMonth != null ? 1 : 0) +
            (selectedAccountId != null ? 1 : 0) +
            (filterValue != TxFilterType.all ? 1 : 0);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // ── App Bar with inline summary ──
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                leading: widget.standalone
                    ? GestureDetector(
                        onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white54, size: 20),
                      )
                    : null,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Movimientos',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
                actions: [
                  // Sort button
                  PopupMenuButton<_SortMode>(
                    icon: Icon(
                      Icons.swap_vert_rounded,
                      size: 20,
                      color: _sortMode != _SortMode.byDate ? cs.primary : cs.onSurfaceVariant,
                    ),
                    tooltip: 'Ordenar',
                    color: const Color(0xFF1E1E2C),
                    onSelected: (mode) => setState(() => _sortMode = mode),
                    itemBuilder: (_) => [
                      _sortMenuItem(_SortMode.byDate, 'Por fecha', Icons.calendar_today_rounded, cs),
                      _sortMenuItem(_SortMode.byAmountDesc, 'Mayor a menor', Icons.arrow_downward_rounded, cs),
                      _sortMenuItem(_SortMode.byAmountAsc, 'Menor a mayor', Icons.arrow_upward_rounded, cs),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),

              // ── Compact Summary Row ──
              SliverToBoxAdapter(
                child: _CompactSummary(
                  income: totalIncome,
                  expense: totalExpense,
                  balance: balance,
                  txCount: filtered.length,
                  label: selectedMonth != null
                      ? '${_monthShort(selectedMonth.month)} ${selectedMonth.year}'
                      : _monthShort(now.month),
                ),
              ),

              // ── Filters: Month pills + Account + Type (all in one compact area) ──
              SliverToBoxAdapter(
                child: _AllFilters(
                  months: sortedMonths,
                  selectedMonth: selectedMonth,
                  onMonthSelect: (m) => ref.read(txSelectedMonthProvider.notifier).state = m,
                  accounts: accounts,
                  selectedAccountId: selectedAccountId,
                  onAccountSelect: (id) => ref.read(txSelectedAccountProvider.notifier).state = id,
                  activeFilters: activeFilters,
                ),
              ),

              // ── Transaction List ──
              if (grouped.isEmpty)
                const SliverFillRemaining(child: _EmptyState())
              else if (_sortMode == _SortMode.byDate)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, groupIndex) {
                      final dateKey = grouped.keys.elementAt(groupIndex);
                      final txList = grouped[dateKey]!;
                      final dayTotal = txList.fold<double>(0, (sum, tx) {
                        if (tx.type == TransactionType.income || tx.type == TransactionType.loanReceived) return sum + tx.amount;
                        return sum - tx.realExpense;
                      });

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                top: groupIndex == 0 ? 4 : 14,
                                bottom: 6,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    dateKey,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.25)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${dayTotal >= 0 ? '+' : ''}${formatAmount(dayTotal, compact: true)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: dayTotal >= 0 ? AppTheme.colorIncome : AppTheme.colorExpense,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...txList.map((tx) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: _TxCard(transaction: tx, accounts: accounts),
                            )),
                          ],
                        ),
                      );
                    },
                    childCount: grouped.length,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: _TxCard(transaction: filtered[i], accounts: accounts),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ),
        );
      },
    );
  }

  PopupMenuItem<_SortMode> _sortMenuItem(_SortMode mode, String label, IconData icon, ColorScheme cs) {
    final selected = _sortMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(children: [
        Icon(icon, size: 16, color: selected ? cs.primary : Colors.white54),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: selected ? cs.primary : Colors.white)),
      ]),
    );
  }

  String _formatGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;

    if (d == today) return 'Hoy';
    if (diff == 1) return 'Ayer';
    if (diff < 7 && diff > 0) {
      final weekday = DateFormat('EEEE', 'es').format(date);
      return weekday[0].toUpperCase() + weekday.substring(1);
    }

    // Different month or older
    if (date.year == now.year) {
      final weekday = DateFormat('EEE', 'es').format(date);
      final cap = weekday[0].toUpperCase() + weekday.substring(1);
      return '$cap ${date.day} ${_monthShort(date.month)}';
    }
    return DateFormat('d MMM yy', 'es').format(date);
  }
}

// ═════════════════════════════════════════════════════════════
// COMPACT SUMMARY (single row, minimal height)
// ═════════════════════════════════════════════════════════════
class _CompactSummary extends StatelessWidget {
  final double income;
  final double expense;
  final double balance;
  final int txCount;
  final String label;

  const _CompactSummary({
    required this.income,
    required this.expense,
    required this.balance,
    required this.txCount,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Month label
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text('$txCount', style: GoogleFonts.inter(fontSize: 10, color: Colors.white30)),
          const Spacer(),
          // Income
          Icon(Icons.arrow_downward_rounded, size: 12, color: AppTheme.colorIncome.withValues(alpha: 0.7)),
          const SizedBox(width: 2),
          Text(
            formatAmount(income, compact: true),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.colorIncome),
          ),
          Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 8), color: cs.outlineVariant.withValues(alpha: 0.3)),
          // Expense
          Icon(Icons.arrow_upward_rounded, size: 12, color: AppTheme.colorExpense.withValues(alpha: 0.7)),
          const SizedBox(width: 2),
          Text(
            formatAmount(expense, compact: true),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.colorExpense),
          ),
          Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 8), color: cs.outlineVariant.withValues(alpha: 0.3)),
          // Balance
          Text(
            '${balance >= 0 ? '+' : ''}${formatAmount(balance, compact: true)}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: balance >= 0 ? AppTheme.colorIncome : AppTheme.colorExpense,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// ALL FILTERS IN ONE COMPACT WIDGET
// ═════════════════════════════════════════════════════════════
class _AllFilters extends ConsumerWidget {
  final List<DateTime> months;
  final DateTime? selectedMonth;
  final ValueChanged<DateTime?> onMonthSelect;
  final List<dynamic> accounts;
  final String? selectedAccountId;
  final ValueChanged<String?> onAccountSelect;
  final int activeFilters;

  const _AllFilters({
    required this.months,
    required this.selectedMonth,
    required this.onMonthSelect,
    required this.accounts,
    required this.selectedAccountId,
    required this.onAccountSelect,
    required this.activeFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterType = ref.watch(txFilterProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Type filters + account chips (all inline)
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Type filters
              ...TxFilterType.values.map((f) {
                final selected = f == filterType;
                final label = switch (f) {
                  TxFilterType.all => 'Todos',
                  TxFilterType.income => 'Ingresos',
                  TxFilterType.expense => 'Gastos',
                  TxFilterType.shared => 'Compartidos',
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: _ChipButton(
                    label: label,
                    selected: selected,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => ref.read(txFilterProvider.notifier).state = f,
                  ),
                );
              }),
              // Divider
              if (accounts.length > 1) ...[
                Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white.withValues(alpha: 0.06)),
                // Account chips
                ...accounts.map((acc) {
                  final isSelected = acc.id == selectedAccountId;
                  final accColor = acc.isCreditCard ? AppTheme.colorWarning : AppTheme.colorIncome;
                  return Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: _ChipButton(
                      label: acc.name,
                      selected: isSelected,
                      color: accColor,
                      icon: acc.isCreditCard ? Icons.credit_card_rounded : Icons.account_balance_rounded,
                      onTap: () => onAccountSelect(isSelected ? null : acc.id),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 5),
        // Row 2: Month pills (compact)
        SizedBox(
          height: 28,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: months.length + 1, // +1 for "Todos"
            itemBuilder: (context, i) {
              if (i == 0) {
                final isAll = selectedMonth == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => onMonthSelect(null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isAll
                            ? AppTheme.colorTransfer.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAll
                              ? AppTheme.colorTransfer.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Todo',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: isAll ? FontWeight.w700 : FontWeight.w400,
                            color: isAll ? Colors.white : Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              final m = months[i - 1];
              final now = DateTime.now();
              final isSelected = selectedMonth != null &&
                  m.year == selectedMonth!.year && m.month == selectedMonth!.month;

              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => onMonthSelect(isSelected ? null : m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.colorTransfer.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.colorTransfer.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        m.year == now.year
                            ? _monthShort(m.month)
                            : '${_monthShort(m.month)} ${m.year % 100}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? Colors.white : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.selected,
    required this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: selected ? color : Colors.white24),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? color : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// TRANSACTION CARD
// ═════════════════════════════════════════════════════════════
class _TxCard extends ConsumerWidget {
  final Transaction transaction;
  final List<dynamic> accounts;
  const _TxCard({required this.transaction, required this.accounts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tx = transaction;
    final isIncome = tx.type == TransactionType.income || tx.type == TransactionType.loanReceived;
    final color = colorForType(tx.type);
    final emoji = kCategoryEmojis[tx.categoryId] ?? _emojiForType(tx.type);
    // For shared expenses show the TOTAL paid — the person owes you back their portion
    final displayAmount = tx.isShared
        ? (tx.sharedTotalAmount ?? tx.amount)
        : tx.amount;

    final account = accounts.cast<dynamic>().where((a) => a.id == tx.accountId).firstOrNull;
    final accountName = account?.name ?? '';

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.colorExpense.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.colorExpense),
      ),
      confirmDismiss: (_) async {
        await _confirmDeleteDialog(context, ref, tx);
        return false;
      },
      child: InkWell(
        onTap: () => context.push('/transactions/${tx.id}'),
        onLongPress: () => _showEditSheet(context, ref, tx, accounts),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              // Emoji
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (accountName.isNotEmpty) ...[
                          Icon(
                            account?.isCreditCard == true ? Icons.credit_card_rounded : Icons.account_balance_rounded,
                            size: 9, color: Colors.white24,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(accountName,
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(' · ', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.15))),
                        ],
                        Text(
                          _catLabel(tx.categoryId),
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                        ),
                      ],
                    ),
                    // Tags
                    if (tx.isRetroactive || tx.isShared || tx.isExtraordinary)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Wrap(
                          spacing: 4,
                          children: [
                            if (tx.isRetroactive) _Tag(label: 'Retro', color: Colors.blueGrey),
                            if (tx.isShared) _Tag(label: 'Compartido', color: AppTheme.colorWarning),
                            if (tx.isExtraordinary) _Tag(label: 'Extra', color: Colors.purpleAccent),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}${formatAmount(displayAmount)}',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                  ),
                  if (tx.isShared && (tx.sharedOtherAmount ?? 0) > 0)
                    Text(
                      'Prestado: ${formatAmount(tx.sharedOtherAmount!, compact: true)}',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.colorWarning),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _emojiForType(TransactionType type) {
    switch (type) {
      case TransactionType.income: return '💰';
      case TransactionType.expense: return '💸';
      case TransactionType.transfer: return '🔄';
      case TransactionType.loanGiven: return '👆';
      case TransactionType.loanReceived: return '👇';
    }
  }

  Future<void> _confirmDeleteDialog(BuildContext context, WidgetRef ref, Transaction tx) async {
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.colorExpense, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Eliminar movimiento',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Text(
          '"${tx.title}" por ${formatAmount(tx.amount)}\n\nEl saldo se restaurara.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await ref.read(transactionServiceProvider).deleteTransaction(tx.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${tx.title} eliminado')),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.colorExpense, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── INLINE EDIT BOTTOM SHEET ──
  void _showEditSheet(BuildContext context, WidgetRef ref, Transaction tx, List<dynamic> accounts) {
    final titleCtrl = TextEditingController(text: tx.title);
    final amountCtrl = TextEditingController(text: formatInitialAmount(tx.amount));
    final noteCtrl = TextEditingController(text: tx.note ?? '');
    String selectedType = tx.type == TransactionType.income
        ? 'income'
        : tx.type == TransactionType.transfer ? 'transfer' : 'expense';
    String selectedCategory = tx.categoryId;
    String selectedAccountId = tx.accountId;
    DateTime selectedDate = tx.date;
    bool saving = false;

    final typeOptions = [
      ('income', 'Ingreso', Icons.arrow_downward_rounded, AppTheme.colorIncome),
      ('expense', 'Gasto', Icons.arrow_upward_rounded, AppTheme.colorExpense),
      ('transfer', 'Transfer', Icons.swap_horiz_rounded, AppTheme.colorTransfer),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final typeColor = selectedType == 'income'
              ? AppTheme.colorIncome
              : selectedType == 'expense' ? AppTheme.colorExpense : AppTheme.colorTransfer;

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            decoration: const BoxDecoration(
              color: Color(0xFF18181F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle + Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.edit_rounded, color: typeColor, size: 18),
                          const SizedBox(width: 8),
                          Text('Editar Movimiento', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E2C),
                                  title: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                  content: Text('Eliminar "${tx.title}"?', style: const TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancelar')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('Eliminar', style: TextStyle(color: AppTheme.colorExpense)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && ctx.mounted) {
                                await ref.read(transactionServiceProvider).deleteTransaction(tx.id);
                                if (ctx.mounted) Navigator.pop(ctx);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.colorExpense.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.colorExpense.withValues(alpha: 0.7)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset > 0 ? bottomInset + 12 : 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount + Type
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: typeColor.withValues(alpha: 0.12)),
                                ),
                                child: Row(
                                  children: [
                                    Text(r'$', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: typeColor.withValues(alpha: 0.6))),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: TextField(
                                        controller: amountCtrl,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [ThousandsSeparatorFormatter()],
                                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ...typeOptions.map((e) {
                              final isSelected = selectedType == e.$1;
                              final c = e.$4;
                              return Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: GestureDetector(
                                  onTap: () => setState(() => selectedType = e.$1),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected ? c.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isSelected ? c.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Icon(e.$3, size: 18, color: isSelected ? c : Colors.white24),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Description
                        TextField(
                          controller: titleCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Descripcion',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                            prefixIcon: Icon(Icons.short_text_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Account
                        if (accounts.isNotEmpty) ...[
                          Text('Cuenta', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 42,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: accounts.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                final acc = accounts[index];
                                final isSelected = acc.id == selectedAccountId;
                                final accColor = acc.isCreditCard ? AppTheme.colorWarning : AppTheme.colorTransfer;
                                return GestureDetector(
                                  onTap: () => setState(() => selectedAccountId = acc.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? accColor.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? accColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(acc.isCreditCard ? Icons.credit_card_rounded : Icons.account_balance_rounded, size: 16, color: isSelected ? accColor : Colors.white30),
                                        const SizedBox(width: 6),
                                        Text(acc.name, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Date
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(primary: AppTheme.colorTransfer, surface: Color(0xFF1E1E2C)),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, color: AppTheme.colorTransfer.withValues(alpha: 0.6), size: 15),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('d MMM yyyy', 'es').format(selectedDate),
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Category
                        Text('Categoria', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: kCategoryEmojis.entries.map((entry) {
                              final isSelected = selectedCategory == entry.key;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () => setState(() => selectedCategory = entry.key),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? typeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isSelected ? typeColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Center(child: Text(
                                      '${entry.value} ${_catLabel(entry.key)}',
                                      style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w500),
                                    )),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Note
                        TextField(
                          controller: noteCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          maxLines: 2, minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Nota (opcional)',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                            prefixIcon: Icon(Icons.notes_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),

                // Save button row
                Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181F),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
                  ),
                  child: Row(
                    children: [
                      // Duplicate
                      GestureDetector(
                        onTap: () async {
                          await ref.read(transactionServiceProvider).duplicateTransaction(tx.id);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Duplicado: ${tx.title}')),
                            );
                          }
                        },
                        child: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: const Icon(Icons.copy_rounded, size: 18, color: Colors.white38),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: saving ? null : () async {
                              setState(() => saving = true);
                              try {
                                final newAmount = amountCtrl.text.isNotEmpty ? parseFormattedAmount(amountCtrl.text) : tx.amount;
                                final origType = tx.type == TransactionType.income ? 'income' : tx.type == TransactionType.transfer ? 'transfer' : 'expense';
                                await ref.read(transactionServiceProvider).updateTransaction(
                                  id: tx.id,
                                  title: titleCtrl.text,
                                  amount: newAmount != tx.amount ? newAmount : null,
                                  type: selectedType != origType ? selectedType : null,
                                  categoryId: selectedCategory != tx.categoryId ? selectedCategory : null,
                                  accountId: selectedAccountId != tx.accountId ? selectedAccountId : null,
                                  date: selectedDate != tx.date ? selectedDate : null,
                                  note: noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
                                  clearNote: noteCtrl.text.isEmpty && tx.note != null,
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Movimiento actualizado')),
                                  );
                                }
                              } catch (_) {
                                if (ctx.mounted) setState(() => saving = false);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: typeColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_rounded, size: 18),
                                      SizedBox(width: 6),
                                      Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// TAG & EMPTY STATE
// ═════════════════════════════════════════════════════════════
class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'Sin movimientos',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text('No hay transacciones con estos filtros', style: GoogleFonts.inter(fontSize: 11, color: Colors.white30)),
        ],
      ),
    );
  }
}
