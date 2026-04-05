import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../../transactions/presentation/widgets/add_transaction_bottom_sheet.dart'
    show kCategoryEmojis;
import '../../domain/models/historical_data.dart';
import '../providers/historical_providers.dart';
import '../providers/monthly_overview_providers.dart';

// ─── Category helpers ───
const _categoryLabels = <String, String>{
  'food': 'Comida',
  'transport': 'Transporte',
  'health': 'Salud',
  'entertainment': 'Entretenimiento',
  'shopping': 'Compras',
  'home': 'Hogar',
  'education': 'Educación',
  'services': 'Servicios',
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
  'cat_otros_gasto': 'Otros gastos',
  'other_expense': 'Otro gasto',
};

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
  'cat_hogar': Color(0xFF81C784),
  'education': Color(0xFF7986CB),
  'services': Color(0xFFFFB74D),
  'cat_financial': Color(0xFF4DD0E1),
  'cat_peer_to_peer': Color(0xFFA1887F),
  'cat_delivery': Color(0xFFFF7043),
  'cat_subs': Color(0xFF7E57C2),
  'cat_tecno': Color(0xFF26C6DA),
  'cat_ropa': Color(0xFFEC407A),
  'cat_otros_gasto': Color(0xFF90A4AE),
  'other_expense': Color(0xFF90A4AE),
};

String _catLabel(String id) => _categoryLabels[id] ?? id.replaceAll('cat_', '').replaceAll('_', ' ');
Color _catColor(String id) => _categoryColors[id] ?? AppTheme.colorTransfer;
String _catEmoji(String id) => kCategoryEmojis[id] ?? '📦';

const _shortMonths = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

class TendenciasTab extends ConsumerWidget {
  const TendenciasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(historicalMonthlyTotalsProvider);
    final comparison = ref.watch(monthComparisonProvider);
    final categoryTrends = ref.watch(historicalCategoryTrendsProvider);
    final transactions = ref.watch(filteredMonthlyTransactionsProvider);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final selectedMonth = ref.watch(selectedOverviewMonthProvider);

    if (totals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up_rounded, size: 48, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text('Sin datos históricos', style: GoogleFonts.inter(color: Colors.white38, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Registrá movimientos para ver tendencias',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12)),
          ],
        ),
      );
    }

    // Current month stats
    final isCurrentMonth = selectedMonth.month == DateTime.now().month &&
        selectedMonth.year == DateTime.now().year;
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final daysElapsed = isCurrentMonth ? DateTime.now().day : daysInMonth;

    final totalExpense = transactions
        .where((t) => t.type == TransactionType.expense || t.type == TransactionType.loanGiven)
        .fold(0.0, (s, t) => s + t.amount);
    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income || t.type == TransactionType.loanReceived)
        .fold(0.0, (s, t) => s + t.amount);
    final dailyAvg = daysElapsed > 0 ? totalExpense / daysElapsed : 0.0;
    final projection = isCurrentMonth ? dailyAvg * daysInMonth : totalExpense;
    final balance = totalIncome - totalExpense;

    // Category breakdown for donut
    final catTotals = <String, double>{};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense || tx.type == TransactionType.loanGiven) {
        catTotals[tx.categoryId] = (catTotals[tx.categoryId] ?? 0) + tx.amount;
      }
    }
    final sortedCats = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Account breakdown
    final accTotals = <String, double>{};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense || tx.type == TransactionType.loanGiven) {
        accTotals[tx.accountId] = (accTotals[tx.accountId] ?? 0) + tx.amount;
      }
    }
    final sortedAccs = accTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Top 3 biggest expenses
    final topExpenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Last 6 months for charts
    final last6 = totals.length > 6 ? totals.sublist(totals.length - 6) : totals;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // ─── Key Metrics Row ───
        _KeyMetricsRow(
          totalExpense: totalExpense,
          totalIncome: totalIncome,
          balance: balance,
          dailyAvg: dailyAvg,
          projection: projection,
          isCurrentMonth: isCurrentMonth,
          daysElapsed: daysElapsed,
          daysInMonth: daysInMonth,
        ),
        const SizedBox(height: 16),

        // ─── Delta indicator ───
        if (comparison != null) _DeltaCard(comparison: comparison),
        const SizedBox(height: 16),

        // ─── Donut chart: category distribution ───
        if (sortedCats.isNotEmpty) ...[
          _SectionTitle(icon: Icons.donut_large_rounded, title: 'Distribución por Categoría'),
          const SizedBox(height: 12),
          _CategoryDonutChart(categories: sortedCats, totalExpense: totalExpense),
          const SizedBox(height: 24),
        ],

        // ─── Account breakdown ───
        if (sortedAccs.length > 1) ...[
          _SectionTitle(icon: Icons.account_balance_wallet_rounded, title: 'Gasto por Cuenta'),
          const SizedBox(height: 12),
          _AccountBreakdown(accounts: accounts, accTotals: sortedAccs, totalExpense: totalExpense),
          const SizedBox(height: 24),
        ],

        // ─── Top 3 biggest expenses ───
        if (topExpenses.length >= 3) ...[
          _SectionTitle(icon: Icons.local_fire_department_rounded, title: 'Gastos más Grandes'),
          const SizedBox(height: 12),
          _TopExpensesList(expenses: topExpenses.take(3).toList()),
          const SizedBox(height: 24),
        ],

        // ─── Bar chart: gastos últimos 6 meses ───
        _SectionTitle(icon: Icons.bar_chart_rounded, title: 'Gastos por Mes'),
        const SizedBox(height: 12),
        _ExpenseBarChart(months: last6),
        const SizedBox(height: 24),

        // ─── Bar chart: ingresos vs gastos ───
        _SectionTitle(icon: Icons.compare_arrows_rounded, title: 'Ingresos vs Gastos'),
        const SizedBox(height: 12),
        _IncomeExpenseChart(months: last6),
        const SizedBox(height: 24),

        // ─── Savings line chart ───
        _SectionTitle(icon: Icons.savings_rounded, title: 'Ahorro Mensual'),
        const SizedBox(height: 12),
        _SavingsLineChart(months: last6),
        const SizedBox(height: 24),

        // ─── Top categorías con evolución ───
        _SectionTitle(icon: Icons.category_rounded, title: 'Evolución por Categoría'),
        const SizedBox(height: 12),
        _TopCategoriesList(categoryTrends: categoryTrends, comparison: comparison),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// KEY METRICS ROW — Balance, Daily Avg, Projection
// ═══════════════════════════════════════════════════════════════
class _KeyMetricsRow extends StatelessWidget {
  final double totalExpense, totalIncome, balance, dailyAvg, projection;
  final bool isCurrentMonth;
  final int daysElapsed, daysInMonth;

  const _KeyMetricsRow({
    required this.totalExpense,
    required this.totalIncome,
    required this.balance,
    required this.dailyAvg,
    required this.projection,
    required this.isCurrentMonth,
    required this.daysElapsed,
    required this.daysInMonth,
  });

  @override
  Widget build(BuildContext context) {
    final balanceColor = balance >= 0 ? AppTheme.colorIncome : AppTheme.colorExpense;

    return Column(
      children: [
        // Balance hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                balanceColor.withValues(alpha: 0.12),
                balanceColor.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: balanceColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Text('Balance del Mes',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                '${balance >= 0 ? '+' : ''}${formatAmount(balance)}',
                style: GoogleFonts.inter(color: balanceColor, fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniStat(icon: Icons.arrow_downward_rounded, label: 'Ingresos', value: formatAmount(totalIncome, compact: true), color: AppTheme.colorIncome),
                  const SizedBox(width: 24),
                  _MiniStat(icon: Icons.arrow_upward_rounded, label: 'Gastos', value: formatAmount(totalExpense, compact: true), color: AppTheme.colorExpense),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Daily avg + Projection row
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.speed_rounded,
                label: 'Promedio diario',
                value: formatAmount(dailyAvg, compact: true),
                subtitle: '$daysElapsed días',
                color: AppTheme.colorWarning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                icon: isCurrentMonth ? Icons.trending_flat_rounded : Icons.check_circle_outline_rounded,
                label: isCurrentMonth ? 'Proyección' : 'Total final',
                value: formatAmount(projection, compact: true),
                subtitle: isCurrentMonth ? '$daysInMonth días' : 'Cerrado',
                color: AppTheme.colorTransfer,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
            Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label, value, subtitle;
  final Color color;
  const _MetricTile({required this.icon, required this.label, required this.value, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w500)),
                Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DELTA CARD — This month vs last month
// ═══════════════════════════════════════════════════════════════
class _DeltaCard extends StatelessWidget {
  final MonthComparison comparison;
  const _DeltaCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final hasPrev = comparison.previous != null;
    final expDelta = comparison.expenseDelta;
    final incDelta = comparison.incomeDelta;
    final expUp = expDelta > 0;
    final incUp = incDelta > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Este mes vs anterior',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (!hasPrev)
            Text('No hay datos del mes anterior para comparar.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13))
          else
            Row(
              children: [
                Expanded(
                  child: _DeltaChip(
                    label: 'Gastos',
                    delta: expDelta,
                    isUp: expUp,
                    color: expUp ? AppTheme.colorExpense : AppTheme.colorIncome,
                    icon: expUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DeltaChip(
                    label: 'Ingresos',
                    delta: incDelta,
                    isUp: incUp,
                    color: incUp ? AppTheme.colorIncome : AppTheme.colorExpense,
                    icon: incUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  ),
                ),
              ],
            ),
          if (hasPrev) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mes actual', style: TextStyle(color: Colors.white38, fontSize: 11)),
                Text(formatAmount(comparison.current.totalExpense, compact: true),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mes anterior', style: TextStyle(color: Colors.white38, fontSize: 11)),
                Text(formatAmount(comparison.previous!.totalExpense, compact: true),
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final String label;
  final double delta;
  final bool isUp;
  final Color color;
  final IconData icon;
  const _DeltaChip({required this.label, required this.delta, required this.isUp, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final pct = (delta.abs() * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
                Text('${isUp ? '+' : '-'}$pct%',
                    style: GoogleFonts.inter(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CATEGORY DONUT CHART
// ═══════════════════════════════════════════════════════════════
class _CategoryDonutChart extends StatelessWidget {
  final List<MapEntry<String, double>> categories;
  final double totalExpense;
  const _CategoryDonutChart({required this.categories, required this.totalExpense});

  @override
  Widget build(BuildContext context) {
    // Take top 6, group rest into "Otros"
    final top = categories.take(6).toList();
    final restAmount = categories.skip(6).fold(0.0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Donut
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  ...top.map((e) => PieChartSectionData(
                        value: e.value,
                        color: _catColor(e.key),
                        radius: 25,
                        showTitle: false,
                      )),
                  if (restAmount > 0)
                    PieChartSectionData(
                      value: restAmount,
                      color: Colors.white.withValues(alpha: 0.1),
                      radius: 25,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...top.map((e) {
                  final pct = totalExpense > 0 ? (e.value / totalExpense * 100).toStringAsFixed(0) : '0';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(color: _catColor(e.key), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_catLabel(e.key),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text('$pct%',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Text(formatAmount(e.value, compact: true),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
                if (restAmount > 0)
                  Row(
                    children: [
                      Container(width: 8, height: 8,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Otros', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11))),
                      Text(formatAmount(restAmount, compact: true),
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ACCOUNT BREAKDOWN
// ═══════════════════════════════════════════════════════════════
class _AccountBreakdown extends StatelessWidget {
  final List<dynamic> accounts;
  final List<MapEntry<String, double>> accTotals;
  final double totalExpense;
  const _AccountBreakdown({required this.accounts, required this.accTotals, required this.totalExpense});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: accTotals.map((entry) {
          final accName = accounts.where((a) => a.id == entry.key).isNotEmpty
              ? accounts.firstWhere((a) => a.id == entry.key).name
              : entry.key;
          final isCard = accounts.where((a) => a.id == entry.key).isNotEmpty &&
              accounts.firstWhere((a) => a.id == entry.key).isCreditCard;
          final pct = totalExpense > 0 ? entry.value / totalExpense : 0.0;
          final color = isCard ? AppTheme.colorWarning : AppTheme.colorTransfer;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isCard ? Icons.credit_card_rounded : Icons.account_balance_rounded,
                      size: 16,
                      color: color.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(accName as String,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(formatAmount(entry.value, compact: true),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TOP 3 BIGGEST EXPENSES
// ═══════════════════════════════════════════════════════════════
class _TopExpensesList extends StatelessWidget {
  final List<Transaction> expenses;
  const _TopExpensesList({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final medals = ['🥇', '🥈', '🥉'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: expenses.asMap().entries.map((entry) {
          final tx = entry.value;
          final medal = entry.key < medals.length ? medals[entry.key] : '';
          final emoji = kCategoryEmojis[tx.categoryId] ?? '💸';
          return Padding(
            padding: EdgeInsets.only(bottom: entry.key < expenses.length - 1 ? 10 : 0),
            child: Row(
              children: [
                Text(medal, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.title,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(_catLabel(tx.categoryId),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10)),
                    ],
                  ),
                ),
                Text(formatAmount(tx.amount, compact: true),
                    style: GoogleFonts.inter(color: AppTheme.colorExpense, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BAR CHART — Expense per month
// ═══════════════════════════════════════════════════════════════
class _ExpenseBarChart extends StatelessWidget {
  final List<MonthlyTotal> months;
  const _ExpenseBarChart({required this.months});

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();

    final maxVal = months.map((m) => m.totalExpense).reduce((a, b) => a > b ? a : b);
    final ceiling = maxVal > 0 ? maxVal * 1.15 : 100.0;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(0, 16, 8, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: BarChart(
        BarChartData(
          maxY: ceiling,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final m = months[group.x.toInt()];
                return BarTooltipItem(
                  '${_shortMonths[m.month - 1]}\n${formatAmount(m.totalExpense, compact: true)}',
                  GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      formatAmount(value, compact: true),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _shortMonths[months[idx].month - 1],
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ceiling / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.04),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(months.length, (i) {
            final isLast = i == months.length - 1;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: months[i].totalExpense,
                  width: 24,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: isLast
                        ? [AppTheme.colorExpense.withValues(alpha: 0.5), AppTheme.colorExpense]
                        : [AppTheme.colorTransfer.withValues(alpha: 0.3), AppTheme.colorTransfer.withValues(alpha: 0.6)],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BAR CHART — Income vs Expense grouped
// ═══════════════════════════════════════════════════════════════
class _IncomeExpenseChart extends StatelessWidget {
  final List<MonthlyTotal> months;
  const _IncomeExpenseChart({required this.months});

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();

    final maxVal = months.map((m) => math.max(m.totalIncome, m.totalExpense)).reduce((a, b) => a > b ? a : b);
    final ceiling = maxVal > 0 ? maxVal * 1.15 : 100.0;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(0, 16, 8, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: BarChart(
        BarChartData(
          maxY: ceiling,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final m = months[group.x.toInt()];
                final label = rodIndex == 0 ? 'Ingreso' : 'Gasto';
                final val = rodIndex == 0 ? m.totalIncome : m.totalExpense;
                return BarTooltipItem(
                  '$label\n${formatAmount(val, compact: true)}',
                  GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      formatAmount(value, compact: true),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _shortMonths[months[idx].month - 1],
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ceiling / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.04),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          groupsSpace: 16,
          barGroups: List.generate(months.length, (i) {
            return BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: months[i].totalIncome,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color: AppTheme.colorIncome.withValues(alpha: 0.7),
                ),
                BarChartRodData(
                  toY: months[i].totalExpense,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color: AppTheme.colorExpense.withValues(alpha: 0.7),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SAVINGS LINE CHART — Income - Expense over time
// ═══════════════════════════════════════════════════════════════
class _SavingsLineChart extends StatelessWidget {
  final List<MonthlyTotal> months;
  const _SavingsLineChart({required this.months});

  @override
  Widget build(BuildContext context) {
    if (months.length < 2) return const SizedBox.shrink();

    final savings = months.map((m) => m.totalIncome - m.totalExpense).toList();
    final minVal = savings.reduce((a, b) => a < b ? a : b);
    final maxVal = savings.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    final floor = minVal - range * 0.15;
    final ceiling = maxVal + range * 0.15;

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(0, 16, 8, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: LineChart(
        LineChartData(
          minY: floor,
          maxY: ceiling,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItems: (spots) => spots.map((s) {
                final idx = s.x.toInt();
                final m = months[idx];
                final val = savings[idx];
                return LineTooltipItem(
                  '${_shortMonths[m.month - 1]}\n${val >= 0 ? '+' : ''}${formatAmount(val, compact: true)}',
                  GoogleFonts.inter(
                    color: val >= 0 ? AppTheme.colorIncome : AppTheme.colorExpense,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: range > 0 ? range / 3 : 100,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.04),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      formatAmount(value, compact: true),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _shortMonths[months[idx].month - 1],
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          // Zero line
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: Colors.white.withValues(alpha: 0.1),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(savings.length, (i) => FlSpot(i.toDouble(), savings[i])),
              isCurved: true,
              color: AppTheme.colorTransfer,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, pct, bar, idx) {
                  final val = savings[idx];
                  return FlDotCirclePainter(
                    radius: 4,
                    color: val >= 0 ? AppTheme.colorIncome : AppTheme.colorExpense,
                    strokeColor: Colors.white.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.colorIncome.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
                cutOffY: 0,
                applyCutOffY: true,
              ),
              aboveBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppTheme.colorExpense.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
                cutOffY: 0,
                applyCutOffY: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TOP CATEGORIES LIST
// ═══════════════════════════════════════════════════════════════
class _TopCategoriesList extends StatelessWidget {
  final Map<String, List<MonthlyCategoryAmount>> categoryTrends;
  final MonthComparison? comparison;
  const _TopCategoriesList({required this.categoryTrends, this.comparison});

  @override
  Widget build(BuildContext context) {
    if (categoryTrends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('Sin datos de categorías',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
        ),
      );
    }

    // Sort categories by most recent month total
    final sorted = categoryTrends.entries.toList();
    sorted.sort((a, b) {
      final aLast = a.value.isNotEmpty ? a.value.last.amount : 0.0;
      final bLast = b.value.isNotEmpty ? b.value.last.amount : 0.0;
      return bLast.compareTo(aLast);
    });

    final top5 = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          ...top5.asMap().entries.map((entry) {
            final catId = entry.value.key;
            final data = entry.value.value;
            return _CategoryTrendRow(
              categoryId: catId,
              data: data,
              isLast: entry.key == top5.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryTrendRow extends StatelessWidget {
  final String categoryId;
  final List<MonthlyCategoryAmount> data;
  final bool isLast;
  const _CategoryTrendRow({required this.categoryId, required this.data, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final currentAmount = data.isNotEmpty ? data.last.amount : 0.0;
    final prevAmount = data.length >= 2 ? data[data.length - 2].amount : 0.0;
    final delta = prevAmount > 0 ? ((currentAmount - prevAmount) / prevAmount) : 0.0;
    final deltaUp = delta > 0;
    final color = _catColor(categoryId);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          // Emoji
          Text(_catEmoji(categoryId), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          // Name + current amount
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_catLabel(categoryId),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(formatAmount(currentAmount, compact: true),
                    style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Mini sparkline
          SizedBox(
            width: 60,
            height: 28,
            child: _MiniSparkline(data: data, color: color),
          ),
          const SizedBox(width: 10),
          // Delta badge
          if (prevAmount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: (deltaUp ? AppTheme.colorExpense : AppTheme.colorIncome).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    deltaUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 10,
                    color: deltaUp ? AppTheme.colorExpense : AppTheme.colorIncome,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${(delta.abs() * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: deltaUp ? AppTheme.colorExpense : AppTheme.colorIncome,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MINI SPARKLINE
// ═══════════════════════════════════════════════════════════════
class _MiniSparkline extends StatelessWidget {
  final List<MonthlyCategoryAmount> data;
  final Color color;
  const _MiniSparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();

    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.amount)).toList();

    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color.withValues(alpha: 0.8),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.colorTransfer),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
