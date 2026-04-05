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

String _monthFull(int month) {
  const names = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
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
  'education': 'Educación',
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
  'cat_tecno': 'Tecnología',
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

        // Stats for summary — use selected month or current month
        final displayTxs = selectedMonth != null ? baseTxs : allTxs.where((t) =>
            t.date.month == now.month && t.date.year == now.year).toList();
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

        // Summary month label
        final summaryLabel = selectedMonth != null
            ? '${_monthFull(selectedMonth.month)} ${selectedMonth.year}'
            : '${_monthFull(now.month)} ${now.year}';

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // ── App Bar ──
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
                title: Text('Movimientos',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                actions: [
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

              // ── Summary Card ──
              SliverToBoxAdapter(
                child: _SummaryCard(
                  income: totalIncome,
                  expense: totalExpense,
                  balance: balance,
                  label: summaryLabel,
                  txCount: filtered.length,
                ),
              ),

              // ── Month Filter ──
              SliverToBoxAdapter(
                child: _MonthFilter(
                  months: sortedMonths,
                  selectedMonth: selectedMonth,
                  onSelect: (m) => ref.read(txSelectedMonthProvider.notifier).state = m,
                ),
              ),

              // ── Type Tabs + Account Filter ──
              SliverToBoxAdapter(
                child: _TypeAndAccountFilter(
                  accounts: accounts,
                  selectedAccountId: selectedAccountId,
                  onAccountSelect: (id) => ref.read(txSelectedAccountProvider.notifier).state = id,
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

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Day header — clean, no balance
                            Padding(
                              padding: EdgeInsets.only(
                                top: groupIndex == 0 ? 6 : 18,
                                bottom: 8,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    dateKey,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white38,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      height: 0.5,
                                      color: Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...txList.map((tx) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
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
                        padding: const EdgeInsets.only(bottom: 6),
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

    if (d == today) return 'HOY';
    if (diff == 1) return 'AYER';
    if (diff < 7 && diff > 0) {
      final weekday = DateFormat('EEEE', 'es').format(date);
      return weekday.toUpperCase();
    }

    if (date.year == now.year) {
      return '${date.day} ${_monthShort(date.month).toUpperCase()}';
    }
    return '${date.day} ${_monthShort(date.month).toUpperCase()} ${date.year}';
  }
}

// ═════════════════════════════════════════════════════════════
// SUMMARY CARD — clear 3-column layout
// ═════════════════════════════════════════════════════════════
class _SummaryCard extends StatelessWidget {
  final double income;
  final double expense;
  final double balance;
  final int txCount;
  final String label;

  const _SummaryCard({
    required this.income,
    required this.expense,
    required this.balance,
    required this.txCount,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final balancePositive = balance >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Month + count header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$txCount mov.',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                  ),
                ),
              ],
            ),
          ),
          // 3 columns: Ingresos / Gastos / Balance
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCol(
                    label: 'Ingresos',
                    amount: income,
                    color: AppTheme.colorIncome,
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _SummaryCol(
                    label: 'Gastos',
                    amount: expense,
                    color: AppTheme.colorExpense,
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _SummaryCol(
                    label: 'Balance',
                    amount: balance,
                    color: balancePositive ? AppTheme.colorIncome : AppTheme.colorExpense,
                    icon: balancePositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    showSign: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SummaryCol extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool showSign;

  const _SummaryCol({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final amountStr = showSign
        ? '${amount >= 0 ? '+' : ''}${formatAmount(amount, compact: true)}'
        : formatAmount(amount, compact: true);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            amountStr,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// MONTH FILTER — horizontal scrollable pills
// ═════════════════════════════════════════════════════════════
class _MonthFilter extends StatelessWidget {
  final List<DateTime> months;
  final DateTime? selectedMonth;
  final ValueChanged<DateTime?> onSelect;

  const _MonthFilter({
    required this.months,
    required this.selectedMonth,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: months.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            final isAll = selectedMonth == null;
            return _MonthPill(
              label: 'Todo',
              selected: isAll,
              onTap: () => onSelect(null),
            );
          }
          final m = months[i - 1];
          final isSelected = selectedMonth != null &&
              m.year == selectedMonth!.year && m.month == selectedMonth!.month;
          final label = m.year == now.year
              ? _monthFull(m.month)
              : '${_monthShort(m.month)} ${m.year % 100}';

          return _MonthPill(
            label: label,
            selected: isSelected,
            onTap: () => onSelect(isSelected ? null : m),
          );
        },
      ),
    );
  }
}

class _MonthPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MonthPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6C63FF);
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.07),
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// TYPE TABS + ACCOUNT FILTER
// ═════════════════════════════════════════════════════════════
class _TypeAndAccountFilter extends ConsumerWidget {
  final List<dynamic> accounts;
  final String? selectedAccountId;
  final ValueChanged<String?> onAccountSelect;

  const _TypeAndAccountFilter({
    required this.accounts,
    required this.selectedAccountId,
    required this.onAccountSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterType = ref.watch(txFilterProvider);
    final cs = Theme.of(context).colorScheme;

    final types = [
      (TxFilterType.all, 'Todos', null),
      (TxFilterType.income, 'Ingresos', AppTheme.colorIncome),
      (TxFilterType.expense, 'Gastos', AppTheme.colorExpense),
      (TxFilterType.shared, 'Compartidos', AppTheme.colorWarning),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: types.map((t) {
                final isSelected = t.$1 == filterType;
                final color = t.$3 ?? cs.primary;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => ref.read(txFilterProvider.notifier).state = t.$1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        t.$2,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? (t.$3 ?? Colors.white) : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Account chips (only if multiple)
        if (accounts.length > 1) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: accounts.map((acc) {
                final isSelected = acc.id == selectedAccountId;
                final accColor = acc.isCreditCard ? AppTheme.colorWarning : AppTheme.colorTransfer;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onAccountSelect(isSelected ? null : acc.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? accColor.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? accColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            acc.isCreditCard ? Icons.credit_card_rounded : Icons.account_balance_rounded,
                            size: 10,
                            color: isSelected ? accColor : Colors.white24,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            acc.name,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              color: isSelected ? accColor : Colors.white30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 8),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════
// TRANSACTION CARD — redesigned with clear category display
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
    final catLabel = _catLabel(tx.categoryId);
    final displayAmount = tx.isShared
        ? (tx.sharedTotalAmount ?? tx.amount)
        : tx.amount;

    final account = accounts.cast<dynamic>().where((a) => a.id == tx.accountId).firstOrNull;
    final accountName = account?.name ?? '';

    // Time string
    final timeStr = DateFormat('HH:mm').format(tx.date);

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
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Category emoji icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 11),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      tx.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Category + account as clear labels
                    Row(
                      children: [
                        // Category pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            catLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        if (accountName.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              accountName,
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.white24),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Tags
                    if (tx.isRetroactive || tx.isShared || tx.isExtraordinary)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
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
              const SizedBox(width: 8),
              // Amount + time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}${formatAmount(displayAmount)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeStr,
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white24),
                  ),
                  if (tx.isShared && (tx.sharedOtherAmount ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Prestado: ${formatAmount(tx.sharedOtherAmount!, compact: true)}',
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.colorWarning),
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
          '"${tx.title}" por ${formatAmount(tx.amount)}\n\nEl saldo se restaurará.',
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
                            hintText: 'Descripción',
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
                        Text('Categoría', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w600)),
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
                                  amount: newAmount,
                                  type: selectedType != origType ? selectedType : null,
                                  categoryId: selectedCategory,
                                  accountId: selectedAccountId,
                                  date: selectedDate,
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
          Icon(Icons.receipt_long_outlined, size: 52, color: cs.outlineVariant),
          const SizedBox(height: 14),
          Text(
            'Sin movimientos',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay transacciones con estos filtros',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white30),
          ),
        ],
      ),
    );
  }
}
