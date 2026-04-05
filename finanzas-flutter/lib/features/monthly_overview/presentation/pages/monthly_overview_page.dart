import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/utils/export_utils.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../../../core/logic/transaction_service.dart';
import '../../../transactions/presentation/widgets/add_transaction_bottom_sheet.dart'
    show kCategoryEmojis;
import '../providers/monthly_overview_providers.dart';
import '../widgets/statement_scanner_bottom_sheet.dart';
import '../widgets/month_closure_wizard.dart';
import '../widgets/tendencias_tab.dart';

// ─── Category label map ───
const _categoryLabels = <String, String>{
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
  'other_expense': 'Otro gasto',
  'other_income': 'Otro ingreso',
};

String _catLabel(String? id, [List<dynamic>? dbCats]) {
  if (id == null) return 'Sin categoría';
  if (_categoryLabels.containsKey(id)) return _categoryLabels[id]!;
  if (dbCats != null) {
    for (final c in dbCats) {
      if (c.id == id) return c.name;
    }
  }
  // Fallback: clean up raw id
  final clean = id.replaceAll('cat_', '').replaceAll('_', ' ');
  return clean.isEmpty ? 'Otro' : '${clean[0].toUpperCase()}${clean.substring(1)}';
}

// ─── Category colors ───
const _categoryColors = <String, Color>{
  'food': Color(0xFFFF8A65),
  'cat_alim': Color(0xFFFF8A65),
  'transport': Color(0xFF4FC3F7),
  'cat_transp': Color(0xFF4FC3F7),
  'health': Color(0xFFEF5350),
  'cat_salud': Color(0xFFEF5350),
  'entertainment': Color(0xFFBA68C8),
  'cat_entret': Color(0xFFBA68C8),
  'shopping': Color(0xFFFFD54F),
  'home': Color(0xFF81C784),
  'education': Color(0xFF7986CB),
  'services': Color(0xFFFFB74D),
  'cat_financial': Color(0xFF4DD0E1),
  'cat_peer_to_peer': Color(0xFFA1887F),
  'other_expense': Color(0xFF90A4AE),
  'other_income': Color(0xFF66BB6A),
};

Color _catColor(String id) =>
    _categoryColors[id] ?? AppTheme.colorTransfer;

class MonthlyOverviewPage extends ConsumerStatefulWidget {
  /// [standalone] = true when pushed above the shell (from Más or router).
  /// Controls back button visibility.
  final bool standalone;
  const MonthlyOverviewPage({super.key, this.standalone = false});

  @override
  ConsumerState<MonthlyOverviewPage> createState() =>
      _MonthlyOverviewPageState();
}

class _MonthlyOverviewPageState extends ConsumerState<MonthlyOverviewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  void _changeMonth(int delta) {
    final current = ref.read(selectedOverviewMonthProvider);
    ref.read(selectedOverviewMonthProvider.notifier).state =
        DateTime(current.year, current.month + delta);
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref, DateTime month) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Generando PDF...'),
      duration: Duration(seconds: 1),
    ));

    try {
      final transactions = ref.read(filteredMonthlyTransactionsProvider);
      final categoryTotals = ref.read(monthlyCategoryTotalsProvider);
      final accountTotals = ref.read(monthlyAccountTotalsProvider);
      final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
      final categories = ref.read(categoriesStreamProvider).valueOrNull ?? [];

      final income = transactions
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (s, t) => s + t.amount);
      final expense = transactions
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (s, t) => s + t.amount);

      final catNames = <String, String>{};
      for (final c in categories) {
        catNames[c.id] = c.name;
      }
      for (final e in _categoryLabels.entries) {
        catNames.putIfAbsent(e.key, () => e.value);
      }

      final accNames = <String, String>{};
      for (final a in accounts) {
        accNames[a.id] = a.name;
      }

      // Build installment info for PDF
      final installmentList = <InstallmentInfo>[];
      for (final tx in transactions) {
        if (tx.note == null) continue;
        final match = RegExp(r'Cuota (\d+)/(\d+)').firstMatch(tx.note!);
        if (match != null) {
          final current = int.tryParse(match.group(1)!) ?? 0;
          final total = int.tryParse(match.group(2)!) ?? 0;
          final remaining = total - current;
          installmentList.add(InstallmentInfo(
            description: tx.title,
            currentInstallment: current,
            totalInstallments: total,
            monthlyAmount: tx.amount,
            remainingAmount: remaining * tx.amount,
          ));
        }
      }

      final path = await generateMonthlyReportPdf(
        year: month.year,
        month: month.month,
        totalIncome: income,
        totalExpense: expense,
        categoryTotals: categoryTotals,
        accountTotals: accountTotals,
        transactions: transactions,
        categoryNames: catNames,
        accountNames: accNames,
        installments: installmentList.isNotEmpty ? installmentList : null,
      );

      await OpenFilex.open(path);

      messenger.showSnackBar(const SnackBar(
        content: Text('PDF generado'),
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error al generar PDF: $e'),
        backgroundColor: AppTheme.colorExpense,
      ));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedOverviewMonthProvider);
    final isCurrentMonth = selectedMonth.month == DateTime.now().month &&
        selectedMonth.year == DateTime.now().year;

    final monthOnly = DateFormat('MMMM', 'es').format(selectedMonth);
    final capitalMonth = '${monthOnly[0].toUpperCase()}${monthOnly.substring(1)}';
    final yearStr = selectedMonth.year.toString();

    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final daysInMonth = lastDay;
    final daysElapsed = isCurrentMonth ? DateTime.now().day : daysInMonth;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.standalone
            ? const BackButton(color: Colors.white)
            : null,
        titleSpacing: 0,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.15, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(capitalMonth),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                capitalMonth,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                yearStr,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.3),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          if (isCurrentMonth)
            _ActionIconBtn(
              icon: Icons.lock_outline_rounded,
              tooltip: 'Cerrar Mes',
              color: AppTheme.colorTransfer,
              onPressed: () =>
                  MonthClosureWizard.show(context, selectedMonth),
            ),
          _ActionIconBtn(
            icon: Icons.picture_as_pdf_outlined,
            tooltip: 'Exportar PDF',
            color: AppTheme.colorWarning,
            onPressed: () => _exportPdf(context, ref, selectedMonth),
          ),
          _ActionIconBtn(
            icon: Icons.document_scanner_outlined,
            tooltip: 'Escanear Resumen',
            color: AppTheme.colorTransfer,
            onPressed: () async {
              final result = await StatementScannerBottomSheet.show(context);
              if (result != null && result['action'] == 'show_detail' && mounted) {
                // Navigate to the correct month
                final month = result['month'] as int?;
                final year = result['year'] as int?;
                final cardId = result['cardId'] as String?;
                if (month != null && year != null) {
                  ref.read(selectedOverviewMonthProvider.notifier).state =
                      DateTime(year, month);
                }
                // Filter by imported card
                if (cardId != null) {
                  ref.read(selectedOverviewAccountIdProvider.notifier).state = cardId;
                }
                _tabController.animateTo(1); // Detalle tab
              }
            },
          ),


        ],
      ),
      body: Column(
        children: [
          // Month nav + info badges — swipeable to change month
          GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 300) {
                _changeMonth(-1); // Swipe right → mes anterior
              } else if (velocity < -300) {
                _changeMonth(1); // Swipe left → mes siguiente
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  // Month navigation row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MonthNavBtn(
                        icon: Icons.chevron_left_rounded,
                        onPressed: () => _changeMonth(-1),
                      ),
                      const SizedBox(width: 24),
                      _InfoBadge(
                        icon: Icons.calendar_today_rounded,
                        label: isCurrentMonth
                            ? 'Día $daysElapsed de $daysInMonth'
                            : '$daysInMonth días',
                      ),
                      if (isCurrentMonth) ...[
                        const SizedBox(width: 10),
                        _InfoBadge(
                          icon: Icons.hourglass_bottom_rounded,
                          label: '${daysInMonth - daysElapsed} restantes',
                        ),
                      ],
                      const SizedBox(width: 24),
                      _MonthNavBtn(
                        icon: Icons.chevron_right_rounded,
                        onPressed: () => _changeMonth(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // TabBar — text for main tabs, icons for secondary
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.colorTransfer,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            dividerColor: Colors.white.withValues(alpha: 0.06),
            labelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_rounded, size: 20)),
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 20)),
              Tab(icon: Icon(Icons.people_alt_rounded, size: 20)),
              Tab(icon: Icon(Icons.handshake_rounded, size: 20)),
              Tab(icon: Icon(Icons.auto_graph_rounded, size: 20)),
            ],
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ResumenTab(),
                _DetalleTab(),
                _CompartidosTab(),
                _PrestamosTab(),
                TendenciasTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1 — RESUMEN
// ═══════════════════════════════════════════════════════════════
class _ResumenTab extends ConsumerWidget {
  const _ResumenTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(filteredMonthlyTransactionsProvider);
    final categoryTotals = ref.watch(monthlyCategoryTotalsProvider);
    final accountTotals = ref.watch(monthlyAccountTotalsProvider);
    final categories = ref.watch(categoriesStreamProvider).valueOrNull ?? [];

    final accounts = ref.watch(accountsStreamProvider).maybeWhen(
          data: (d) => d,
          orElse: () => [],
        );

    double ordinaryIncome = 0,
        extraordinaryIncome = 0,
        ordinaryExpense = 0,
        extraordinaryExpense = 0;
    int txCount = 0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.loanReceived) {
        if (tx.isExtraordinary) {
          extraordinaryIncome += tx.amount;
        } else {
          ordinaryIncome += tx.amount;
        }
      }
      if (tx.type == TransactionType.expense ||
          tx.type == TransactionType.loanGiven) {
        txCount++;
        if (tx.isExtraordinary) {
          extraordinaryExpense += tx.amount;
        } else {
          ordinaryExpense += tx.amount;
        }
      }
    }
    final totalIncome = ordinaryIncome + extraordinaryIncome;
    final totalExpense = ordinaryExpense + extraordinaryExpense;
    final balance = totalIncome - totalExpense;

    // Insights
    final selectedMonth = ref.watch(selectedOverviewMonthProvider);
    final isCurrentMonth = selectedMonth.month == DateTime.now().month &&
        selectedMonth.year == DateTime.now().year;
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final daysElapsed = isCurrentMonth ? DateTime.now().day : daysInMonth;
    final dailyAvg = daysElapsed > 0 ? totalExpense / daysElapsed : 0.0;
    final topExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final projection = isCurrentMonth ? dailyAvg * daysInMonth : totalExpense;

    // Sort categories by amount desc
    final sortedCats = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sort accounts by amount desc
    final sortedAccounts = accountTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Installment data: parse transactions with "Cuota X/Y" in note
    final installmentTxs = transactions.where((t) {
      if (t.note == null) return false;
      return RegExp(r'Cuota \d+/\d+').hasMatch(t.note!);
    }).toList();

    // Parse installment info
    final installmentInfos = <({Transaction tx, int current, int total, double monthlyAmount})>[];
    for (final tx in installmentTxs) {
      final match = RegExp(r'Cuota (\d+)/(\d+)').firstMatch(tx.note!);
      if (match != null) {
        final current = int.tryParse(match.group(1)!) ?? 0;
        final total = int.tryParse(match.group(2)!) ?? 0;
        installmentInfos.add((tx: tx, current: current, total: total, monthlyAmount: tx.amount));
      }
    }

    // Calculate totals
    final totalInstallmentDebt = installmentInfos.fold(0.0, (sum, info) {
      final remaining = info.total - info.current;
      return sum + (remaining * info.monthlyAmount);
    });
    final monthlyInstallmentObligation = installmentInfos.fold(0.0, (sum, info) => sum + info.monthlyAmount);

    return RefreshIndicator(
      color: AppTheme.colorTransfer,
      backgroundColor: const Color(0xFF1E1E2C),
      onRefresh: () async {
        ref.invalidate(transactionsStreamProvider);
        ref.invalidate(accountsStreamProvider);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Income section for past months ──
        if (!isCurrentMonth && totalExpense > 0) ...[
          _MonthIncomeSection(
            month: selectedMonth,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            incomeTransactions: transactions
                .where((t) => t.type == TransactionType.income ||
                              t.type == TransactionType.loanReceived)
                .toList(),
          ),
          const SizedBox(height: 14),
        ],

        // ── Hero Balance Card ──
        _BalanceSummaryCard(
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          balance: balance,
          ordinaryIncome: ordinaryIncome,
          extraordinaryIncome: extraordinaryIncome,
          ordinaryExpense: ordinaryExpense,
          extraordinaryExpense: extraordinaryExpense,
          txCount: txCount,
        ),
        const SizedBox(height: 14),

        // ── Quick Insights Row ──
        if (txCount > 0)
          Row(
            children: [
              Expanded(
                child: _InsightTile(
                  icon: Icons.speed_rounded,
                  label: 'Promedio diario',
                  value: formatAmount(dailyAvg, compact: true),
                  color: AppTheme.colorTransfer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InsightTile(
                  icon: isCurrentMonth
                      ? Icons.auto_graph_rounded
                      : Icons.receipt_long_rounded,
                  label: isCurrentMonth ? 'Proyección' : 'Total final',
                  value: formatAmount(projection, compact: true),
                  color: projection > totalIncome
                      ? AppTheme.colorExpense
                      : AppTheme.colorIncome,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InsightTile(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Gasto mayor',
                  value: topExpense.isNotEmpty
                      ? formatAmount(topExpense.first.amount, compact: true)
                      : '-',
                  color: AppTheme.colorWarning,
                ),
              ),
            ],
          ),
        if (txCount > 0) const SizedBox(height: 14),

        // ── Top expense highlight ──
        if (topExpense.isNotEmpty)
          _TopExpenseHighlight(tx: topExpense.first),
        if (topExpense.isNotEmpty) const SizedBox(height: 14),

        // ── Account filters ──
        if (accounts.isNotEmpty) ...[
          _buildFilters(context, ref, accounts),
          const SizedBox(height: 20),
        ],

        // ── Gastos por Categoría ──
        if (sortedCats.isNotEmpty) ...[
          _SectionHeader(
            title: 'Gastos por Categoría',
            icon: Icons.pie_chart_outline_rounded,
            count: sortedCats.length,
          ),
          const SizedBox(height: 12),
          _CategoryChart(
            categories: sortedCats,
            total: totalExpense,
            dbCategories: categories,
          ),
          const SizedBox(height: 10),
          ...sortedCats.map((e) => _CategoryRow(
                catId: e.key,
                amount: e.value,
                total: totalExpense,
                dbCategories: categories,
              )),
          const SizedBox(height: 24),
        ],

        // ── Gastos por Cuenta/Tarjeta ──
        if (sortedAccounts.isNotEmpty) ...[
          _SectionHeader(
            title: 'Gastos por Cuenta',
            icon: Icons.account_balance_wallet_outlined,
            count: sortedAccounts.length,
          ),
          const SizedBox(height: 12),
          ...sortedAccounts.map((e) {
            final accName = accounts.any((a) => a.id == e.key)
                ? accounts.firstWhere((a) => a.id == e.key).name
                : 'Otro';
            final acc = accounts.cast<dynamic>().firstWhere(
                (a) => a.id == e.key,
                orElse: () => null);
            final isCreditCard = acc?.isCreditCard ?? false;
            return _AccountRow(
              name: accName,
              amount: e.value,
              total: totalExpense,
              isCreditCard: isCreditCard,
            );
          }),
        ],

        // ── Cuotas pendientes ──
        if (installmentInfos.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Cuotas Pendientes',
            icon: Icons.calendar_month_outlined,
            count: installmentInfos.length,
          ),
          const SizedBox(height: 12),
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.colorWarning.withValues(alpha: 0.1),
                  const Color(0xFF1E1E2C),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.colorWarning.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Deuda total en cuotas',
                              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            formatAmount(totalInstallmentDebt),
                            style: GoogleFonts.inter(
                              color: AppTheme.colorWarning,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pago mensual',
                              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            formatAmount(monthlyInstallmentObligation),
                            style: GoogleFonts.inter(
                              color: AppTheme.colorExpense,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Individual installment cards
          ...installmentInfos.map((info) {
            final remaining = info.total - info.current;
            final progress = info.total > 0 ? info.current / info.total : 0.0;
            return _InstallmentCard(
              title: info.tx.title,
              current: info.current,
              total: info.total,
              monthlyAmount: info.monthlyAmount,
              remainingDebt: remaining * info.monthlyAmount,
              progress: progress,
              categoryId: info.tx.categoryId,
            );
          }),
        ],

        // ── Empty state ──
        if (sortedCats.isEmpty && sortedAccounts.isEmpty)
          _EmptyMonth(),
      ],
    ),
    );
  }

  Widget _buildFilters(BuildContext context, WidgetRef ref, List accounts) {
    final selectedAcc = ref.watch(selectedOverviewAccountIdProvider);

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterPill(
            label: 'Todas',
            icon: Icons.all_inclusive_rounded,
            isSelected: selectedAcc == null,
            onTap: () => ref
                .read(selectedOverviewAccountIdProvider.notifier)
                .state = null,
          ),
          ...accounts.map((a) => _FilterPill(
                label: a.name,
                icon: a.isCreditCard
                    ? Icons.credit_card_rounded
                    : Icons.account_balance_rounded,
                isSelected: selectedAcc == a.id,
                onTap: () => ref
                    .read(selectedOverviewAccountIdProvider.notifier)
                    .state = a.id,
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 2 — DETALLE (todos los movimientos del mes)
// ═══════════════════════════════════════════════════════════════
class _DetalleTab extends ConsumerWidget {
  const _DetalleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(filteredMonthlyTransactionsProvider);
    final categories = ref.watch(categoriesStreamProvider).valueOrNull ?? [];
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final activeAccountId = ref.watch(selectedOverviewAccountIdProvider);
    final selectedMonth = ref.watch(selectedOverviewMonthProvider);

    // Sort by date descending
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));

    // Group by date
    final grouped = <String, List<Transaction>>{};
    for (final tx in sorted) {
      final key = DateFormat('d MMMM', 'es').format(tx.date);
      (grouped[key] ??= []).add(tx);
    }

    // Build filter chip + list
    final activeAccName = activeAccountId != null && accounts.any((a) => a.id == activeAccountId)
        ? accounts.firstWhere((a) => a.id == activeAccountId).name
        : null;

    // Check other months with transactions for this card
    final otherMonthCounts = <DateTime, int>{};
    if (activeAccountId != null) {
      final allTxs = ref.watch(transactionsStreamProvider).valueOrNull ?? [];
      for (final tx in allTxs) {
        if (tx.accountId != activeAccountId) continue;
        final txMonth = DateTime(tx.date.year, tx.date.month);
        if (txMonth.year == selectedMonth.year && txMonth.month == selectedMonth.month) continue;
        otherMonthCounts[txMonth] = (otherMonthCounts[txMonth] ?? 0) + 1;
      }
    }
    // Sort other months by date descending, take closest ones
    final otherMonthEntries = otherMonthCounts.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      children: [
        // Active filter chip
        if (activeAccName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => ref.read(selectedOverviewAccountIdProvider.notifier).state = null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.colorTransfer.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.credit_card_rounded, size: 14, color: AppTheme.colorTransfer),
                        const SizedBox(width: 6),
                        Text(activeAccName,
                            style: TextStyle(color: AppTheme.colorTransfer, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Icon(Icons.close_rounded, size: 14, color: AppTheme.colorTransfer.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text('${sorted.length} movimientos',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
              ],
            ),
          ),

        // Other months banner — shows when card filter is active and there are
        // transactions for the same card in other months (e.g., from same statement PDF)
        if (activeAccountId != null && otherMonthEntries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.colorWarning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.colorWarning.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.colorWarning.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'También hay movimientos en otros meses:',
                          style: TextStyle(color: AppTheme.colorWarning.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: otherMonthEntries.take(4).map((entry) {
                      final monthLabel = DateFormat('MMM yyyy', 'es').format(entry.key);
                      final capLabel = '${monthLabel[0].toUpperCase()}${monthLabel.substring(1)}';
                      return GestureDetector(
                        onTap: () {
                          ref.read(selectedOverviewMonthProvider.notifier).state = entry.key;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.colorWarning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$capLabel (${entry.value})',
                            style: TextStyle(color: AppTheme.colorWarning, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

        if (sorted.isEmpty)
          Expanded(
            child: _EmptySection(
              icon: Icons.receipt_long_outlined,
              title: 'Sin movimientos',
              subtitle: activeAccName != null
                  ? 'No hay transacciones para esta tarjeta en este mes'
                  : 'No hay transacciones registradas para este mes',
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: grouped.length,
              itemBuilder: (context, groupIdx) {
                final dateLabel = grouped.keys.elementAt(groupIdx);
                final txs = grouped[dateLabel]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (groupIdx > 0) const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        dateLabel,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...txs.map((tx) {
                      final isIncome = tx.type == TransactionType.income ||
                          tx.type == TransactionType.loanReceived;
                      final emoji = kCategoryEmojis[tx.categoryId] ?? (isIncome ? '💰' : '💸');
                      final accName = accounts.any((a) => a.id == tx.accountId)
                          ? accounts.firstWhere((a) => a.id == tx.accountId).name
                          : '';

                      return GestureDetector(
                        onLongPress: () => _showEditDialog(context, ref, tx, accounts, categories),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2C).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: (isIncome
                                          ? AppTheme.colorIncome
                                          : AppTheme.colorExpense)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 16)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.title,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _catLabel(tx.categoryId, categories),
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.35),
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (accName.isNotEmpty) ...[
                                          Text(' · ',
                                              style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                  fontSize: 11)),
                                          Text(
                                            accName,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.3),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        if (tx.isRetroactive) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Retroactivo',
                                              style: TextStyle(
                                                color: Colors.blueGrey,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (tx.displayNote != null &&
                                            RegExp(r'Cuota \d+/\d+').hasMatch(tx.displayNote!)) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppTheme.colorWarning.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tx.displayNote!,
                                              style: const TextStyle(
                                                color: AppTheme.colorWarning,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIncome ? '+' : '-'}${formatAmount(tx.amount, compact: true)}',
                                style: GoogleFonts.inter(
                                  color: isIncome ? AppTheme.colorIncome : AppTheme.colorExpense,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Transaction tx, List<dynamic> accounts, List<dynamic> categories) {
    final titleCtrl = TextEditingController(text: tx.title);
    final amountCtrl = TextEditingController(text: formatInitialAmount(tx.amount));
    final noteCtrl = TextEditingController(text: tx.note ?? '');
    String selectedType = tx.type == TransactionType.income ? 'income' : tx.type == TransactionType.transfer ? 'transfer' : 'expense';
    String selectedCategory = tx.categoryId;
    String selectedAccountId = tx.accountId;
    DateTime selectedDate = tx.date;
    bool saving = false;

    final typeOptions = [
      ('income', 'Ingreso', Icons.arrow_downward_rounded, AppTheme.colorIncome),
      ('expense', 'Gasto', Icons.arrow_upward_rounded, AppTheme.colorExpense),
      ('transfer', 'Transferencia', Icons.swap_horiz_rounded, AppTheme.colorTransfer),
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
              : selectedType == 'expense'
                  ? AppTheme.colorExpense
                  : AppTheme.colorTransfer;

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            decoration: const BoxDecoration(
              color: Color(0xFF18181F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle + Header ──
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
                          // Delete button
                          GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E2C),
                                  title: const Text('Eliminar movimiento', style: TextStyle(color: Colors.white)),
                                  content: Text('¿Eliminar "${tx.title}"?', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
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

                // ── Scrollable content ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset > 0 ? bottomInset + 12 : 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Monto + Tipo ──
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
                                    width: 40,
                                    height: 40,
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

                        // ── Descripción ──
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

                        // ── Cuenta ──
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
                                        Text(acc.name, style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white54,
                                          fontSize: 12, fontWeight: FontWeight.w600,
                                        ), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Fecha ──
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
                              setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day));
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

                        // ── Categoría ──
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

                        // ── Nota ──
                        TextField(
                          controller: noteCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          minLines: 1,
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

                // ── Botón guardar ──
                Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181F),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
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
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 3 — COMPARTIDOS
// ═══════════════════════════════════════════════════════════════
class _CompartidosTab extends ConsumerWidget {
  const _CompartidosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(filteredMonthlyTransactionsProvider);
    final sharedTxs =
        transactions.where((t) => t.isShared).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final totalPending =
        sharedTxs.fold(0.0, (sum, t) => sum + t.pendingToRecover);
    final totalRecovered = sharedTxs.fold(
        0.0, (sum, t) => sum + (t.sharedRecovered ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Summary banner
        if (sharedTxs.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.colorWarning.withValues(alpha: 0.12),
                  AppTheme.colorTransfer.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppTheme.colorWarning.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.colorWarning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_alt_rounded,
                      color: AppTheme.colorWarning, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Por cobrar',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(totalPending),
                        style: GoogleFonts.inter(
                          color: AppTheme.colorWarning,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                if (totalRecovered > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Recuperado',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 10)),
                      Text(
                        formatAmount(totalRecovered),
                        style: GoogleFonts.inter(
                            color: AppTheme.colorIncome,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // List
        if (sharedTxs.isEmpty)
          _EmptySection(
            icon: Icons.group_outlined,
            title: 'Sin gastos compartidos',
            subtitle: 'Los gastos compartidos de este mes aparecerán acá',
          ),

        ...sharedTxs.map((tx) => _SharedTxCard(tx: tx)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 4 — PRÉSTAMOS
// ═══════════════════════════════════════════════════════════════
class _PrestamosTab extends ConsumerWidget {
  const _PrestamosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(filteredMonthlyTransactionsProvider);
    final loans = transactions
        .where((t) =>
            t.type == TransactionType.loanGiven ||
            t.type == TransactionType.loanReceived)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final given =
        loans.where((t) => t.type == TransactionType.loanGiven).toList();
    final received =
        loans.where((t) => t.type == TransactionType.loanReceived).toList();
    final totalGiven = given.fold(0.0, (s, t) => s + t.amount);
    final totalReceived = received.fold(0.0, (s, t) => s + t.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (loans.isNotEmpty) ...[
          // Summary
          Row(
            children: [
              Expanded(
                child: _LoanSummaryTile(
                  label: 'Presté',
                  amount: totalGiven,
                  icon: Icons.arrow_upward_rounded,
                  color: AppTheme.colorExpense,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LoanSummaryTile(
                  label: 'Me prestaron',
                  amount: totalReceived,
                  icon: Icons.arrow_downward_rounded,
                  color: AppTheme.colorIncome,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        if (given.isNotEmpty) ...[
          _SectionHeader(
            title: 'Préstamos dados',
            icon: Icons.arrow_upward_rounded,
            count: given.length,
          ),
          const SizedBox(height: 10),
          ...given.map((tx) => _LoanCard(tx: tx)),
          const SizedBox(height: 20),
        ],

        if (received.isNotEmpty) ...[
          _SectionHeader(
            title: 'Préstamos recibidos',
            icon: Icons.arrow_downward_rounded,
            count: received.length,
          ),
          const SizedBox(height: 10),
          ...received.map((tx) => _LoanCard(tx: tx)),
        ],

        if (loans.isEmpty)
          _EmptySection(
            icon: Icons.handshake_outlined,
            title: 'Sin préstamos',
            subtitle: 'Los préstamos de este mes aparecerán acá',
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS — Balance Summary Card
// ═══════════════════════════════════════════════════════════════
class _BalanceSummaryCard extends StatelessWidget {
  final double totalIncome, totalExpense, balance;
  final double ordinaryIncome, extraordinaryIncome;
  final double ordinaryExpense, extraordinaryExpense;
  final int txCount;

  const _BalanceSummaryCard({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.ordinaryIncome,
    required this.extraordinaryIncome,
    required this.ordinaryExpense,
    required this.extraordinaryExpense,
    required this.txCount,
  });

  @override
  Widget build(BuildContext context) {
    final spentRatio =
        totalIncome > 0 ? (totalExpense / totalIncome).clamp(0.0, 1.5) : 0.0;
    final isPositive = balance >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (isPositive
                    ? AppTheme.colorIncome
                    : AppTheme.colorExpense)
                .withValues(alpha: 0.10),
            const Color(0xFF1E1E2C),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // Balance hero
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance del Mes',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatAmount(balance),
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: isPositive
                            ? AppTheme.colorIncome
                            : AppTheme.colorExpense,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Mini ring chart
              _MiniRingChart(ratio: spentRatio, isPositive: isPositive),
            ],
          ),
          const SizedBox(height: 16),

          // Spent ratio bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: spentRatio.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                spentRatio > 1.0
                    ? AppTheme.colorExpense
                    : spentRatio > 0.8
                        ? AppTheme.colorWarning
                        : AppTheme.colorIncome,
              ),
              minHeight: 5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(spentRatio * 100).toStringAsFixed(0)}% gastado',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                Text(
                  '$txCount movimientos',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Income / Expense breakdown
          Row(
            children: [
              Expanded(
                child: _BreakdownColumn(
                  title: 'Ingresos',
                  total: totalIncome,
                  color: AppTheme.colorIncome,
                  icon: Icons.trending_up_rounded,
                  items: [
                    if (ordinaryIncome > 0)
                      ('Ordinarios', ordinaryIncome),
                    if (extraordinaryIncome > 0)
                      ('Extraordinarios', extraordinaryIncome),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 70,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(
                child: _BreakdownColumn(
                  title: 'Gastos',
                  total: totalExpense,
                  color: AppTheme.colorExpense,
                  icon: Icons.trending_down_rounded,
                  items: [
                    if (ordinaryExpense > 0)
                      ('Ordinarios', ordinaryExpense),
                    if (extraordinaryExpense > 0)
                      ('Extraordinarios', extraordinaryExpense),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownColumn extends StatelessWidget {
  final String title;
  final double total;
  final Color color;
  final IconData icon;
  final List<(String, double)> items;

  const _BreakdownColumn({
    required this.title,
    required this.total,
    required this.color,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 5),
            Text(title,
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatAmount(total),
          style: GoogleFonts.inter(
              color: color, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${item.$1}: ${formatAmount(item.$2, compact: true)}',
                style: TextStyle(color: Colors.white30, fontSize: 10),
              ),
            )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Mini Ring Chart (custom painter)
// ═══════════════════════════════════════════════════════════════
class _MiniRingChart extends StatelessWidget {
  final double ratio;
  final bool isPositive;
  const _MiniRingChart({required this.ratio, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(
        painter: _RingPainter(
          ratio: ratio.clamp(0.0, 1.0),
          color: ratio > 1.0
              ? AppTheme.colorExpense
              : ratio > 0.8
                  ? AppTheme.colorWarning
                  : AppTheme.colorIncome,
        ),
        child: Center(
          child: Icon(
            isPositive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: isPositive ? AppTheme.colorIncome : AppTheme.colorExpense,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double ratio;
  final Color color;
  _RingPainter({required this.ratio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // Progress arc
    final sweep = 2 * math.pi * ratio;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.color != color;
}

// ═══════════════════════════════════════════════════════════════
// Category mini horizontal bar chart
// ═══════════════════════════════════════════════════════════════
class _CategoryChart extends StatelessWidget {
  final List<MapEntry<String, double>> categories;
  final double total;
  final List<dynamic> dbCategories;

  const _CategoryChart({
    required this.categories,
    required this.total,
    required this.dbCategories,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty || total <= 0) return const SizedBox.shrink();

    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: categories.asMap().entries.map((entry) {
          final idx = entry.key;
          final cat = entry.value;
          final pct = cat.value / total;
          final color = _catColor(cat.key);
          return Expanded(
            flex: (pct * 1000).round().clamp(1, 1000),
            child: Tooltip(
              message:
                  '${_catLabel(cat.key, dbCategories)}: ${(pct * 100).toStringAsFixed(1)}%',
              child: Container(
                margin: EdgeInsets.only(right: idx < categories.length - 1 ? 2 : 0),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.horizontal(
                    left: idx == 0
                        ? const Radius.circular(8)
                        : Radius.zero,
                    right: idx == categories.length - 1
                        ? const Radius.circular(8)
                        : Radius.zero,
                  ),
                ),
                alignment: Alignment.center,
                child: pct > 0.08
                    ? Text(
                        kCategoryEmojis[cat.key] ?? '',
                        style: const TextStyle(fontSize: 13),
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Category Row
// ═══════════════════════════════════════════════════════════════
class _CategoryRow extends StatelessWidget {
  final String catId;
  final double amount;
  final double total;
  final List<dynamic> dbCategories;

  const _CategoryRow({
    required this.catId,
    required this.amount,
    required this.total,
    required this.dbCategories,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final color = _catColor(catId);
    final emoji = kCategoryEmojis[catId] ?? '📦';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _catLabel(catId, dbCategories),
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  formatAmount(amount, compact: true),
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                valueColor:
                    AlwaysStoppedAnimation(color.withValues(alpha: 0.6)),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Account Row
// ═══════════════════════════════════════════════════════════════
class _AccountRow extends StatelessWidget {
  final String name;
  final double amount;
  final double total;
  final bool isCreditCard;

  const _AccountRow({
    required this.name,
    required this.amount,
    required this.total,
    required this.isCreditCard,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final color = isCreditCard ? AppTheme.colorWarning : AppTheme.colorTransfer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isCreditCard
                      ? Icons.credit_card_rounded
                      : Icons.account_balance_rounded,
                  color: color.withValues(alpha: 0.7),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  formatAmount(amount, compact: true),
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                valueColor:
                    AlwaysStoppedAnimation(color.withValues(alpha: 0.6)),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared Tx Card
// ═══════════════════════════════════════════════════════════════
class _SharedTxCard extends StatelessWidget {
  final Transaction tx;
  const _SharedTxCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final recovered = tx.sharedRecovered ?? 0;
    final pending = tx.pendingToRecover;
    final totalOther = tx.sharedOtherAmount ?? 0;
    final progress =
        totalOther > 0 ? (recovered / totalOther).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.colorWarning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    kCategoryEmojis[tx.categoryId] ?? '👥',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.title,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14)),
                    Text(
                      DateFormat('d MMM', 'es').format(tx.date),
                      style: const TextStyle(
                          color: Colors.white30, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatAmount(tx.amount),
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  if (pending > 0)
                    Text(
                      '↩ ${formatAmount(pending, compact: true)}',
                      style: GoogleFonts.inter(
                          color: AppTheme.colorWarning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
          ),
          if (totalOther > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1.0
                      ? AppTheme.colorIncome
                      : AppTheme.colorWarning,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recuperado: ${formatAmount(recovered, compact: true)}',
                  style:
                      const TextStyle(color: Colors.white30, fontSize: 10),
                ),
                Text(
                  progress >= 1.0 ? 'Completo ✓' : 'Pendiente',
                  style: TextStyle(
                    color: progress >= 1.0
                        ? AppTheme.colorIncome
                        : AppTheme.colorWarning,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Loan Card
// ═══════════════════════════════════════════════════════════════
class _LoanCard extends StatelessWidget {
  final Transaction tx;
  const _LoanCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isGiven = tx.type == TransactionType.loanGiven;
    final color = isGiven ? AppTheme.colorExpense : AppTheme.colorIncome;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGiven
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                Text(
                  DateFormat('d MMM', 'es').format(tx.date),
                  style:
                      const TextStyle(color: Colors.white30, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            formatAmount(tx.amount),
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanSummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _LoanSummaryTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatAmount(amount),
            style: GoogleFonts.inter(
                color: color, fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════════════════════════
class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InsightTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopExpenseHighlight extends StatelessWidget {
  final Transaction tx;
  const _TopExpenseHighlight({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.colorExpense.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.colorExpense.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.colorExpense.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                kCategoryEmojis[tx.categoryId] ?? '💸',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mayor gasto del mes',
                  style: TextStyle(
                    color: AppTheme.colorExpense.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  tx.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            formatAmount(tx.amount),
            style: GoogleFonts.inter(
              color: AppTheme.colorExpense,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _MonthNavBtn({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white54, size: 18),
      ),
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ActionIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.colorTransfer.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.colorTransfer.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: isSelected
                      ? AppTheme.colorTransfer
                      : Colors.white30),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_note_rounded,
                color: Colors.white24, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin movimientos este mes',
            style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'Agregá ingresos o gastos para ver tu resumen',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Income Prompt Banner (for past months with $0 income)
// ═══════════════════════════════════════════════════════════════
class _MonthIncomeSection extends ConsumerWidget {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;
  final List<Transaction> incomeTransactions;

  const _MonthIncomeSection({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.incomeTransactions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasIncome = totalIncome > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (hasIncome ? AppTheme.colorIncome : AppTheme.colorTransfer)
                .withValues(alpha: 0.06),
            const Color(0xFF1E1E2C).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (hasIncome ? AppTheme.colorIncome : Colors.white)
              .withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasIncome) ...[
            // No income — prompt to add
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppTheme.colorIncome.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin ingresos registrados',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _AddIncomeBtn(month: month),
              ],
            ),
          ] else ...[
            // Has income — show summary with each income entry
            Row(
              children: [
                Icon(Icons.trending_up_rounded,
                    size: 16, color: AppTheme.colorIncome.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text(
                  'Ingresos del mes',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _AddIncomeBtn(month: month),
              ],
            ),
            const SizedBox(height: 8),
            // List each income transaction
            for (final tx in incomeTransactions) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        tx.title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '+${formatAmount(tx.amount, compact: true)}',
                      style: GoogleFonts.inter(
                        color: AppTheme.colorIncome,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (tx.isRetroactive)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('R', style: TextStyle(
                            color: Colors.blueGrey, fontSize: 8, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
          // "No afecta tu saldo" note
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Los ingresos de meses cerrados no afectan tu saldo actual',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showQuickIncomeDialog(
      BuildContext context, WidgetRef ref, DateTime month) {
    final amountCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: 'Sueldo');
    String? selectedAccountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
        final nonCardAccounts = accounts.where((a) => !a.isCreditCard).toList();
        if (nonCardAccounts.isNotEmpty) {
          selectedAccountId = nonCardAccounts.first.id;
        }

        final monthName = DateFormat('MMMM yyyy', 'es').format(month);
        final capitalMonth = '${monthName[0].toUpperCase()}${monthName.substring(1)}';

        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Agregar ingreso — $capitalMonth',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Concepto',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: const Color(0xFF2A2A38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: GoogleFonts.inter(
                  color: AppTheme.colorIncome,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(
                    color: AppTheme.colorIncome.withValues(alpha: 0.7),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2A2A38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (nonCardAccounts.isNotEmpty)
                StatefulBuilder(
                  builder: (context, setLocalState) {
                    return DropdownButtonFormField<String>(
                      initialValue: selectedAccountId,
                      decoration: InputDecoration(
                        labelText: 'Cuenta',
                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: const Color(0xFF2A2A38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      dropdownColor: const Color(0xFF2A2A38),
                      style: const TextStyle(color: Colors.white),
                      items: nonCardAccounts
                          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                          .toList(),
                      onChanged: (v) {
                        setLocalState(() => selectedAccountId = v);
                      },
                    );
                  },
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () async {
                    final amountText = amountCtrl.text.replaceAll('.', '').replaceAll(',', '.');
                    final amount = double.tryParse(amountText);
                    if (amount == null || amount <= 0 || selectedAccountId == null) return;

                    final title = titleCtrl.text.trim().isEmpty ? 'Sueldo' : titleCtrl.text.trim();

                    final now = DateTime.now();
                    final isCurrentMonth = month.year == now.year && month.month == now.month;

                    if (isCurrentMonth) {
                      // Current month: normal transaction — counts in balance
                      await ref.read(transactionServiceProvider).addTransaction(
                        title: title,
                        amount: amount,
                        type: 'income',
                        categoryId: 'salary',
                        accountId: selectedAccountId!,
                        date: DateTime(month.year, month.month, 1),
                      );
                    } else {
                      // Past month: retroactive — excluded from balance
                      await ref.read(transactionServiceProvider).addRetroactiveTransaction(
                        title: title,
                        amount: amount,
                        type: 'income',
                        categoryId: 'salary',
                        accountId: selectedAccountId!,
                        date: DateTime(month.year, month.month, 1),
                        note: 'Ingreso retroactivo',
                      );
                    }

                    if (ctx.mounted) Navigator.pop(ctx);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Ingreso de \$${formatAmount(amount)} agregado a ${DateFormat('MMMM', 'es').format(month)}'),
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Guardar ingreso',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorIncome,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddIncomeBtn extends StatelessWidget {
  final DateTime month;
  const _AddIncomeBtn({required this.month});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => SizedBox(
        height: 28,
        child: TextButton.icon(
          onPressed: () => _MonthIncomeSection.showQuickIncomeDialog(
            context, ref, month,
          ),
          icon: Icon(Icons.add_rounded,
              size: 14, color: AppTheme.colorIncome.withValues(alpha: 0.8)),
          label: Text(
            'Agregar',
            style: TextStyle(
              color: AppTheme.colorIncome.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Installment Card
// ═══════════════════════════════════════════════════════════════
class _InstallmentCard extends StatelessWidget {
  final String title;
  final int current;
  final int total;
  final double monthlyAmount;
  final double remainingDebt;
  final double progress;
  final String categoryId;

  const _InstallmentCard({
    required this.title,
    required this.current,
    required this.total,
    required this.monthlyAmount,
    required this.remainingDebt,
    required this.progress,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = total - current;
    final isNearEnd = remaining <= 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.colorWarning.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.colorWarning.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  kCategoryEmojis[categoryId] ?? '💳',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.colorWarning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Cuota $current/$total',
                              style: TextStyle(
                                color: AppTheme.colorWarning,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isNearEnd
                                ? (remaining == 0 ? '¡Última cuota!' : '$remaining cuota${remaining > 1 ? 's' : ''} más')
                                : '$remaining restantes',
                            style: TextStyle(
                              color: isNearEnd
                                  ? AppTheme.colorIncome
                                  : Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: isNearEnd ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatAmount(monthlyAmount, compact: true),
                      style: GoogleFonts.inter(
                        color: AppTheme.colorExpense,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'debe: ${formatAmount(remainingDebt, compact: true)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                valueColor: AlwaysStoppedAnimation(
                  progress >= 0.8
                      ? AppTheme.colorIncome
                      : AppTheme.colorWarning.withValues(alpha: 0.6),
                ),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white24, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
