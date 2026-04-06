import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/export_utils.dart';

import '../../../transactions/domain/models/transaction.dart';
import '../../../monthly_overview/presentation/providers/monthly_overview_providers.dart';
import '../../../monthly_overview/presentation/providers/historical_providers.dart';
import '../../../monthly_overview/domain/models/historical_data.dart';
import '../../../transactions/presentation/widgets/add_transaction_bottom_sheet.dart'
    show kCategoryEmojis;

// ─── Category maps ───
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
  'other_expense': 'Otro gasto',
  'other_income': 'Otro ingreso',
};

const _categoryColors = <String, Color>{
  'food': Color(0xFFFF8A65),
  'transport': Color(0xFF4FC3F7),
  'health': Color(0xFFEF5350),
  'entertainment': Color(0xFFBA68C8),
  'shopping': Color(0xFFFFD54F),
  'home': Color(0xFF81C784),
  'education': Color(0xFF7986CB),
  'services': Color(0xFFFFB74D),
  'other_expense': Color(0xFF90A4AE),
  'other_income': Color(0xFF66BB6A),
};

String _catLabel(String id) =>
    _categoryLabels[id] ?? id.replaceAll('cat_', '').replaceAll('_', ' ');

Color _catColor(String id) =>
    _categoryColors[id] ?? AppTheme.colorTransfer;

// ─── Date range mode ───
enum _RangeMode { month, custom }

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  DateTime _selectedMonth = DateTime.now();
  _RangeMode _rangeMode = _RangeMode.month;
  late DateTimeRange _customRange;
  late TabController _tabController;

  // Alert thresholds
  double _alertSpendingLimit = 0; // 0 = disabled
  bool _alertBudgetOverrun = true;
  bool _alertSavingsBelow20 = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _customRange = DateTimeRange(
      start: DateTime(_selectedMonth.year, _selectedMonth.month),
      end: DateTime(_selectedMonth.year, _selectedMonth.month + 1)
          .subtract(const Duration(days: 1)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedOverviewMonthProvider.notifier).state = _selectedMonth;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _customRange = DateTimeRange(
        start: DateTime(_selectedMonth.year, _selectedMonth.month),
        end: DateTime(_selectedMonth.year, _selectedMonth.month + 1)
            .subtract(const Duration(days: 1)),
      );
    });
    ref.read(selectedOverviewMonthProvider.notifier).state = _selectedMonth;
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.colorTransfer,
            surface: const Color(0xFF1E1E2C),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _rangeMode = _RangeMode.custom;
        _customRange = picked;
      });
    }
  }

  /// Filter transactions by active date range
  List<Transaction> _filterByRange(List<Transaction> txs) {
    if (_rangeMode == _RangeMode.month) {
      return txs
          .where((t) =>
              t.date.year == _selectedMonth.year &&
              t.date.month == _selectedMonth.month)
          .toList();
    }
    return txs
        .where((t) =>
            !t.date.isBefore(_customRange.start) &&
            t.date.isBefore(_customRange.end.add(const Duration(days: 1))))
        .toList();
  }

  String get _rangeLabel {
    if (_rangeMode == _RangeMode.month) {
      final name =
          DateFormat('MMMM yyyy', 'es').format(_selectedMonth);
      return '${name[0].toUpperCase()}${name.substring(1)}';
    }
    final df = DateFormat('dd/MM/yy');
    return '${df.format(_customRange.start)} — ${df.format(_customRange.end)}';
  }

  int get _rangeDays {
    if (_rangeMode == _RangeMode.month) {
      return DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    }
    return _customRange.end.difference(_customRange.start).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
        symbol: '\$', decimalDigits: 0, locale: 'es_AR');
    final fmtCompact = NumberFormat.compactCurrency(
        symbol: '\$', decimalDigits: 1, locale: 'es_AR');

    // Get all transactions via stream and filter locally
    final allTxsAsync = ref.watch(transactionsStreamProvider);
    final allTxs = allTxsAsync.valueOrNull ?? [];
    final transactions = _filterByRange(allTxs);

    // Category totals from filtered transactions
    final categoryTotals = <String, double>{};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense ||
          tx.type == TransactionType.transfer) {
        categoryTotals[tx.categoryId] =
            (categoryTotals[tx.categoryId] ?? 0) + tx.amount;
      }
    }

    final historicalTotals = ref.watch(historicalMonthlyTotalsProvider);
    final comparison = ref.watch(monthComparisonProvider);
    final budgets = ref.watch(budgetsStreamProvider).valueOrNull ?? [];
    final goals = ref.watch(goalsStreamProvider).valueOrNull ?? [];


    // Computed metrics
    final income = transactions
        .where((t) =>
            t.type == TransactionType.income ||
            t.type == TransactionType.loanReceived)
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) =>
            t.type == TransactionType.expense ||
            t.type == TransactionType.loanGiven ||
            t.type == TransactionType.transfer)
        .fold(0.0, (s, t) => s + t.amount);
    final balance = income - expense;
    final savingsRate = income > 0 ? ((balance / income) * 100) : 0.0;
    final txCount = transactions.length;
    final avgPerDay = expense > 0 ? expense / _rangeDays : 0.0;

    // Loans / shared
    final loans = transactions.where((t) =>
        t.type == TransactionType.loanGiven ||
        t.type == TransactionType.loanReceived);
    final sharedTxs = transactions.where((t) => t.isShared);
    final pendingToRecover =
        sharedTxs.fold(0.0, (s, t) => s + t.pendingToRecover);

    // Daily spending
    final dailyMap = <int, double>{};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense ||
          tx.type == TransactionType.loanGiven ||
          tx.type == TransactionType.transfer) {
        final day = tx.date.day;
        dailyMap[day] = (dailyMap[day] ?? 0) + tx.realExpense;
      }
    }

    // Sorted categories
    final sortedCats = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalExpenseForPct =
        sortedCats.fold(0.0, (s, e) => s + e.value);

    // Budget compliance
    final budgetsOnTrack =
        budgets.where((b) => b.spentAmount <= b.limitAmount).length;
    final budgetsOver =
        budgets.where((b) => b.spentAmount > b.limitAmount).length;

    // Alerts
    final alerts = _computeAlerts(
      expense: expense,
      savingsRate: savingsRate,
      budgetsOver: budgetsOver,
      avgPerDay: avgPerDay,
      comparison: comparison,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Análisis',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
            tooltip: 'Exportar PDF',
            onPressed: () => _exportPdf(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Date Range Selector ──
          _buildDateSelector(),

          // ── Tab Bar ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.colorTransfer.withValues(alpha: 0.2),
              ),
              dividerColor: Colors.transparent,
              labelColor: AppTheme.colorTransfer,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500),
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Resumen', height: 34),
                Tab(text: 'Categorías', height: 34),
                Tab(text: 'Tendencias', height: 34),
                Tab(text: 'Presupuestos', height: 34),
                Tab(text: 'Análisis', height: 34),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Alert Banner ──
          if (alerts.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.colorExpense.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.colorExpense.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_rounded,
                      color: AppTheme.colorWarning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alerts.first,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (alerts.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.colorWarning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${alerts.length - 1}',
                        style: TextStyle(
                            color: AppTheme.colorWarning,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // ── Tab Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Resumen
                _buildResumenTab(
                  fmt: fmt,
                  fmtCompact: fmtCompact,
                  income: income,
                  expense: expense,
                  balance: balance,
                  savingsRate: savingsRate,
                  txCount: txCount,
                  avgPerDay: avgPerDay,
                  comparison: comparison,
                  dailyMap: dailyMap,
                  pendingToRecover: pendingToRecover,
                ),
                // Tab 2: Categorías
                _buildCategoriasTab(
                  fmt: fmt,
                  fmtCompact: fmtCompact,
                  sortedCats: sortedCats,
                  totalExpenseForPct: totalExpenseForPct,
                  transactions: transactions,
                ),
                // Tab 3: Tendencias
                _buildTendenciasTab(
                  fmtCompact: fmtCompact,
                  historicalTotals: historicalTotals,
                ),
                // Tab 4: Presupuestos
                _buildPresupuestosTab(
                  fmtCompact: fmtCompact,
                  budgets: budgets,
                  budgetsOnTrack: budgetsOnTrack,
                  budgetsOver: budgetsOver,
                  goals: goals,
                  fmt: fmt,
                ),
                // Tab 5: Análisis
                _buildAnalisisTab(
                  income: income,
                  expense: expense,
                  savingsRate: savingsRate,
                  comparison: comparison,
                  budgetsOnTrack: budgetsOnTrack,
                  budgetsOver: budgetsOver,
                  goals: goals,
                  txCount: txCount,
                  loans: loans.toList(),
                  sharedTxs: sharedTxs.toList(),
                  pendingToRecover: pendingToRecover,
                  avgPerDay: avgPerDay,
                  fmt: fmt,
                  fmtCompact: fmtCompact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Date Selector ─────────────────────────────────
  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          // Month nav
          if (_rangeMode == _RangeMode.month) ...[
            GestureDetector(
              onTap: () => _changeMonth(-1),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white54, size: 22),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: GestureDetector(
              onTap: _pickCustomRange,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: AppTheme.colorTransfer, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _rangeLabel,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    if (_rangeMode == _RangeMode.custom) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(
                            () => _rangeMode = _RangeMode.month),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white38, size: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_rangeMode == _RangeMode.month) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _changeMonth(1),
              child: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white54, size: 22),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // TAB 1: RESUMEN
  // ═══════════════════════════════════════════════════
  Widget _buildResumenTab({
    required NumberFormat fmt,
    required NumberFormat fmtCompact,
    required double income,
    required double expense,
    required double balance,
    required double savingsRate,
    required int txCount,
    required double avgPerDay,
    required MonthComparison? comparison,
    required Map<int, double> dailyMap,
    required double pendingToRecover,
  }) {
    final daysInMonth = _rangeDays;
    final dailySpending = List.filled(daysInMonth, 0.0);
    for (final entry in dailyMap.entries) {
      final idx = entry.key - 1;
      if (idx >= 0 && idx < daysInMonth) {
        dailySpending[idx] = entry.value;
      }
    }
    final maxDaily =
        dailySpending.isEmpty ? 1.0 : dailySpending.reduce(math.max);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Row
          Row(children: [
            Expanded(
                child: _KpiCard(
                    label: 'Ingresos',
                    value: fmt.format(income),
                    color: AppTheme.colorIncome,
                    icon: Icons.trending_up_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _KpiCard(
                    label: 'Gastos',
                    value: fmt.format(expense),
                    color: AppTheme.colorExpense,
                    icon: Icons.trending_down_rounded)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _KpiCard(
                    label: 'Balance',
                    value: fmt.format(balance),
                    color: balance >= 0
                        ? AppTheme.colorIncome
                        : AppTheme.colorExpense,
                    icon: Icons.account_balance_rounded)),
            const SizedBox(width: 10),
            Expanded(
                child: _KpiCard(
                    label: 'Ahorro',
                    value: '${savingsRate.toStringAsFixed(1)}%',
                    color: savingsRate >= 20
                        ? AppTheme.colorIncome
                        : savingsRate >= 0
                            ? AppTheme.colorWarning
                            : AppTheme.colorExpense,
                    icon: Icons.savings_rounded)),
          ]),

          // Comparison chips
          if (comparison?.previous != null &&
              _rangeMode == _RangeMode.month) ...[
            const SizedBox(height: 12),
            Row(children: [
              _DeltaChip(
                  label: 'vs mes anterior',
                  delta: comparison!.expenseDelta,
                  isExpense: true),
              const SizedBox(width: 8),
              _DeltaChip(
                  label: 'ingresos',
                  delta: comparison.incomeDelta,
                  isExpense: false),
            ]),
          ],

          // Quick stats row
          const SizedBox(height: 16),
          Row(children: [
            _QuickStat(
                icon: Icons.speed_rounded,
                label: 'Promedio/día',
                value: fmtCompact.format(avgPerDay),
                color: AppTheme.colorWarning),
            const SizedBox(width: 8),
            _QuickStat(
                icon: Icons.receipt_long_rounded,
                label: 'Movimientos',
                value: '$txCount',
                color: AppTheme.colorTransfer),
            if (pendingToRecover > 0) ...[
              const SizedBox(width: 8),
              _QuickStat(
                  icon: Icons.people_alt_rounded,
                  label: 'A cobrar',
                  value: fmtCompact.format(pendingToRecover),
                  color: AppTheme.colorTransfer),
            ],
          ]),

          const SizedBox(height: 24),
          _SectionTitle('Gasto diario'),
          const SizedBox(height: 12),

          // Daily chart
          Container(
            height: 180,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: _cardDecoration(),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxDaily * 1.2 + 1,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) {
                      return BarTooltipItem(
                        'Día ${group.x + 1}\n${fmtCompact.format(rod.toY)}',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (daysInMonth / 6).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt() + 1;
                        if (day == 1 || day == daysInMonth || day % 5 == 0) {
                          return Text('$day',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 9));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(fmtCompact.format(value),
                            style: const TextStyle(
                                color: Colors.white24, fontSize: 9));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxDaily / 3).clamp(1, double.infinity),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.04),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  daysInMonth,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: dailySpending[i],
                        color: i + 1 == DateTime.now().day &&
                                _selectedMonth.month == DateTime.now().month &&
                                _selectedMonth.year == DateTime.now().year
                            ? AppTheme.colorWarning
                            : AppTheme.colorTransfer,
                        width: math.max(2, (280 / daysInMonth) - 2),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat('Promedio/día', fmtCompact.format(avgPerDay)),
              _MiniStat('Movimientos', '$txCount'),
              if (dailySpending.any((d) => d > 0))
                _MiniStat('Día más caro',
                    '${dailySpending.indexOf(dailySpending.reduce(math.max)) + 1}/${_selectedMonth.month}'),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // TAB 2: CATEGORÍAS
  // ═══════════════════════════════════════════════════
  Widget _buildCategoriasTab({
    required NumberFormat fmt,
    required NumberFormat fmtCompact,
    required List<MapEntry<String, double>> sortedCats,
    required double totalExpenseForPct,
    required List<Transaction> transactions,
  }) {
    // Income categories
    final incomeCats = <String, double>{};
    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        incomeCats[tx.categoryId] =
            (incomeCats[tx.categoryId] ?? 0) + tx.realExpense;
      }
    }
    final sortedIncomeCats = incomeCats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalIncomeForPct =
        sortedIncomeCats.fold(0.0, (s, e) => s + e.value);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pie chart replacement: horizontal breakdown
          if (sortedCats.isNotEmpty) ...[
            _SectionTitle('Gastos por categoría'),
            const SizedBox(height: 12),
            // Donut chart
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: sortedCats.take(6).map((entry) {
                          final pct = totalExpenseForPct > 0
                              ? entry.value / totalExpenseForPct
                              : 0.0;
                          return PieChartSectionData(
                            value: entry.value,
                            color: _catColor(entry.key),
                            radius: 50,
                            title: '${(pct * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: sortedCats.take(6).map((entry) {
                      final emoji = kCategoryEmojis[entry.key];
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _catColor(entry.key),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${emoji ?? ''} ${_catLabel(entry.key)}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Detailed list
            ...sortedCats.map((entry) {
              final pct = totalExpenseForPct > 0
                  ? entry.value / totalExpenseForPct
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryBar(
                  name: _catLabel(entry.key),
                  emoji: kCategoryEmojis[entry.key],
                  percent: pct,
                  amount: entry.value,
                  color: _catColor(entry.key),
                ),
              );
            }),
          ],

          if (sortedCats.isEmpty)
            _EmptyState(message: 'Sin gastos en este período'),

          // Income categories
          if (sortedIncomeCats.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle('Ingresos por categoría'),
            const SizedBox(height: 12),
            ...sortedIncomeCats.map((entry) {
              final pct = totalIncomeForPct > 0
                  ? entry.value / totalIncomeForPct
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryBar(
                  name: _catLabel(entry.key),
                  emoji: kCategoryEmojis[entry.key],
                  percent: pct,
                  amount: entry.value,
                  color: AppTheme.colorIncome,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // TAB 3: TENDENCIAS
  // ═══════════════════════════════════════════════════
  Widget _buildTendenciasTab({
    required NumberFormat fmtCompact,
    required List<MonthlyTotal> historicalTotals,
  }) {
    final catTrends = ref.watch(historicalCategoryTrendsProvider);

    // Top 3 categories by total spending across months
    final catTotalSpend = <String, double>{};
    for (final entry in catTrends.entries) {
      catTotalSpend[entry.key] =
          entry.value.fold(0.0, (s, m) => s + m.amount);
    }
    final topCats = (catTotalSpend.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(4)
        .toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Evolución mensual'),
          const SizedBox(height: 12),
          Container(
            height: 200,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: _cardDecoration(),
            child: _HistoricalChart(
                totals: historicalTotals, fmtCompact: fmtCompact),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(
                  color: AppTheme.colorIncome, label: 'Ingresos'),
              const SizedBox(width: 16),
              _ChartLegend(
                  color: AppTheme.colorExpense, label: 'Gastos'),
            ],
          ),

          const SizedBox(height: 24),
          _SectionTitle('Balance mensual'),
          const SizedBox(height: 12),
          Container(
            height: 180,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: _cardDecoration(),
            child: _BalanceBarChart(
                totals: historicalTotals, fmtCompact: fmtCompact),
          ),

          // Category trends
          if (topCats.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle('Tendencia por categoría'),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: _cardDecoration(),
              child: _CategoryTrendChart(
                trends: catTrends,
                topCats: topCats.map((e) => e.key).toList(),
                fmtCompact: fmtCompact,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: topCats.map((e) {
                return _ChartLegend(
                    color: _catColor(e.key),
                    label: _catLabel(e.key));
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // TAB 4: PRESUPUESTOS
  // ═══════════════════════════════════════════════════
  Widget _buildPresupuestosTab({
    required NumberFormat fmtCompact,
    required NumberFormat fmt,
    required List budgets,
    required int budgetsOnTrack,
    required int budgetsOver,
    required List goals,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (budgets.isNotEmpty) ...[
            // Summary chips
            Row(children: [
              _BudgetStatusChip(
                  label: 'En regla',
                  count: budgetsOnTrack,
                  color: AppTheme.colorIncome,
                  icon: Icons.check_circle_rounded),
              const SizedBox(width: 12),
              _BudgetStatusChip(
                  label: 'Excedidos',
                  count: budgetsOver,
                  color: AppTheme.colorExpense,
                  icon: Icons.warning_rounded),
            ]),
            const SizedBox(height: 16),

            // Budget cards
            ...budgets.map((b) {
              final pct = b.limitAmount > 0
                  ? (b.spentAmount / b.limitAmount).clamp(0.0, 1.5)
                  : 0.0;
              final isOver = b.spentAmount > b.limitAmount;
              final remaining = b.limitAmount - b.spentAmount;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isOver
                          ? AppTheme.colorExpense.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(b.categoryName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: isOver
                              ? AppTheme.colorExpense
                              : AppTheme.colorIncome,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.05),
                        color: isOver
                            ? AppTheme.colorExpense
                            : Color.lerp(AppTheme.colorIncome,
                                AppTheme.colorWarning, pct)!,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(
                        '${fmtCompact.format(b.spentAmount)} / ${fmtCompact.format(b.limitAmount)}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        isOver
                            ? 'Excedido ${fmtCompact.format(remaining.abs())}'
                            : 'Quedan ${fmtCompact.format(remaining)}',
                        style: TextStyle(
                          color: isOver
                              ? AppTheme.colorExpense
                              : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]),
                  ],
                ),
              );
            }),
          ] else
            _EmptyState(message: 'No hay presupuestos configurados'),

          // Goals section
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle('Metas de ahorro'),
            const SizedBox(height: 12),
            ...goals.map((g) {
              final pct = g.targetAmount > 0
                  ? (g.savedAmount / g.targetAmount).clamp(0.0, 1.0)
                  : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: _cardDecoration(),
                child: Row(children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 4,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.06),
                          color: AppTheme.colorIncome,
                        ),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${fmtCompact.format(g.savedAmount)} / ${fmtCompact.format(g.targetAmount)}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // TAB 5: ANÁLISIS
  // ═══════════════════════════════════════════════════
  Widget _buildAnalisisTab({
    required double income,
    required double expense,
    required double savingsRate,
    required MonthComparison? comparison,
    required int budgetsOnTrack,
    required int budgetsOver,
    required List goals,
    required int txCount,
    required List<Transaction> loans,
    required List<Transaction> sharedTxs,
    required double pendingToRecover,
    required double avgPerDay,
    required NumberFormat fmt,
    required NumberFormat fmtCompact,
  }) {
    final loansGiven = loans
        .where((t) => t.type == TransactionType.loanGiven)
        .fold(0.0, (s, t) => s + t.amount);
    final loansReceived = loans
        .where((t) => t.type == TransactionType.loanReceived)
        .fold(0.0, (s, t) => s + t.amount);

    // Projections
    final now = DateTime.now();
    final dayOfMonth = now.day;
    final daysInMonth =
        DateTime(now.year, now.month + 1, 0).day;
    final projectedExpense =
        dayOfMonth > 0 ? (expense / dayOfMonth) * daysInMonth : expense;
    final projectedBalance = income - projectedExpense;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insights
          _SectionTitle('Insights'),
          const SizedBox(height: 12),
          ..._buildInsights(
            income: income,
            expense: expense,
            savingsRate: savingsRate,
            comparison: comparison,
            budgetsOnTrack: budgetsOnTrack,
            budgetsOver: budgetsOver,
            goals: goals,
            txCount: txCount,
          ),

          // Projections
          if (_rangeMode == _RangeMode.month &&
              _selectedMonth.month == now.month &&
              _selectedMonth.year == now.year) ...[
            const SizedBox(height: 24),
            _SectionTitle('Proyección fin de mes'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _ProjectionRow(
                    label: 'Gasto estimado',
                    value: fmtCompact.format(projectedExpense),
                    color: AppTheme.colorExpense,
                    icon: Icons.trending_up_rounded,
                  ),
                  const SizedBox(height: 8),
                  _ProjectionRow(
                    label: 'Balance estimado',
                    value: fmtCompact.format(projectedBalance),
                    color: projectedBalance >= 0
                        ? AppTheme.colorIncome
                        : AppTheme.colorExpense,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                  const SizedBox(height: 8),
                  _ProjectionRow(
                    label: 'Ritmo diario ideal',
                    value: fmtCompact.format(
                        income > 0
                            ? (income * 0.8) / daysInMonth
                            : 0),
                    color: AppTheme.colorTransfer,
                    icon: Icons.speed_rounded,
                    subtitle: 'para ahorrar 20%',
                  ),
                ],
              ),
            ),
          ],

          // Loans
          if (loans.isNotEmpty || sharedTxs.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionTitle('Préstamos y compartidos'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  if (loansGiven > 0)
                    _LoanRow(
                        label: 'Prestado',
                        value: fmtCompact.format(loansGiven),
                        icon: Icons.arrow_upward_rounded,
                        color: AppTheme.colorExpense),
                  if (loansReceived > 0)
                    _LoanRow(
                        label: 'Recibido',
                        value: fmtCompact.format(loansReceived),
                        icon: Icons.arrow_downward_rounded,
                        color: AppTheme.colorIncome),
                  if (pendingToRecover > 0)
                    _LoanRow(
                        label: 'Pendiente a cobrar',
                        value: fmtCompact.format(pendingToRecover),
                        icon: Icons.schedule_rounded,
                        color: AppTheme.colorWarning),
                  if (sharedTxs.isNotEmpty)
                    _LoanRow(
                        label: 'Gastos compartidos',
                        value: '${sharedTxs.length} movimientos',
                        icon: Icons.group_rounded,
                        color: AppTheme.colorTransfer),
                ],
              ),
            ),
          ],

          // Alert config
          const SizedBox(height: 24),
          _SectionTitle('Alertas'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AlertChip(
                label: 'Presupuesto excedido',
                icon: Icons.warning_rounded,
                active: _alertBudgetOverrun,
                onTap: () => setState(
                    () => _alertBudgetOverrun = !_alertBudgetOverrun),
              ),
              _AlertChip(
                label: 'Ahorro < 20%',
                icon: Icons.savings_rounded,
                active: _alertSavingsBelow20,
                onTap: () => setState(
                    () => _alertSavingsBelow20 = !_alertSavingsBelow20),
              ),
              _AlertChip(
                label: 'Gasto diario alto',
                icon: Icons.speed_rounded,
                active: _alertSpendingLimit > 0,
                onTap: () => _showSpendingLimitDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Alerts computation ────────────────────────────
  void _showSpendingLimitDialog() {
    final ctrl = TextEditingController(
        text: _alertSpendingLimit > 0
            ? _alertSpendingLimit.toStringAsFixed(0)
            : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Límite de gasto diario',
            style:
                TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ej: 5000',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixText: '\$ ',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          if (_alertSpendingLimit > 0)
            TextButton(
              onPressed: () {
                setState(() => _alertSpendingLimit = 0);
                Navigator.pop(ctx);
              },
              child: const Text('Desactivar',
                  style: TextStyle(color: Colors.white38)),
            ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null && val > 0) {
                setState(() => _alertSpendingLimit = val);
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  List<String> _computeAlerts({
    required double expense,
    required double savingsRate,
    required int budgetsOver,
    required double avgPerDay,
    required MonthComparison? comparison,
  }) {
    final alerts = <String>[];
    if (_alertBudgetOverrun && budgetsOver > 0) {
      alerts.add(
          '$budgetsOver presupuesto${budgetsOver > 1 ? 's' : ''} excedido${budgetsOver > 1 ? 's' : ''}');
    }
    if (_alertSavingsBelow20 && savingsRate < 20 && savingsRate >= 0) {
      alerts.add(
          'Tasa de ahorro ${savingsRate.toStringAsFixed(0)}% — meta: 20%');
    }
    if (_alertSpendingLimit > 0 && avgPerDay > _alertSpendingLimit) {
      alerts.add(
          'Gasto diario promedio supera tu límite de \$${_alertSpendingLimit.toStringAsFixed(0)}');
    }
    if (comparison?.previous != null &&
        comparison!.expenseDelta > 0.3) {
      alerts.add(
          'Gastos ${(comparison.expenseDelta * 100).toStringAsFixed(0)}% mayores al mes anterior');
    }
    return alerts;
  }

  // ─── Insights ──────────────────────────────────────
  List<Widget> _buildInsights({
    required double income,
    required double expense,
    required double savingsRate,
    required MonthComparison? comparison,
    required int budgetsOnTrack,
    required int budgetsOver,
    required List goals,
    required int txCount,
  }) {
    final insights = <Widget>[];

    if (savingsRate >= 30) {
      insights.add(_InsightCard(
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFFFD700),
          title: 'Ahorrista Pro',
          subtitle:
              'Ahorraste el ${savingsRate.toStringAsFixed(0)}% de tus ingresos'));
    } else if (savingsRate >= 15) {
      insights.add(_InsightCard(
          icon: Icons.thumb_up_rounded,
          color: AppTheme.colorIncome,
          title: 'Buen mes',
          subtitle:
              'Ahorraste el ${savingsRate.toStringAsFixed(0)}% — meta ideal: 20%+'));
    } else if (savingsRate < 0) {
      insights.add(_InsightCard(
          icon: Icons.warning_amber_rounded,
          color: AppTheme.colorExpense,
          title: 'Gastaste más de lo que ganaste',
          subtitle: 'Balance negativo este mes. Revisá tus gastos.'));
    }

    if (comparison?.previous != null) {
      final delta = comparison!.expenseDelta;
      if (delta < -0.1) {
        insights.add(_InsightCard(
            icon: Icons.trending_down_rounded,
            color: AppTheme.colorIncome,
            title: 'Gastaste menos',
            subtitle:
                '${(delta.abs() * 100).toStringAsFixed(0)}% menos que el mes anterior'));
      } else if (delta > 0.2) {
        insights.add(_InsightCard(
            icon: Icons.trending_up_rounded,
            color: AppTheme.colorExpense,
            title: 'Gastos en aumento',
            subtitle:
                '${(delta * 100).toStringAsFixed(0)}% más que el mes anterior'));
      }
    }

    if (budgetsOnTrack > 0 && budgetsOver == 0) {
      insights.add(_InsightCard(
          icon: Icons.verified_rounded,
          color: AppTheme.colorTransfer,
          title: 'Todos los presupuestos en regla',
          subtitle: '$budgetsOnTrack presupuestos dentro del límite'));
    }

    if (goals.isNotEmpty) {
      final completed =
          goals.where((g) => g.savedAmount >= g.targetAmount).length;
      if (completed > 0) {
        insights.add(_InsightCard(
            icon: Icons.flag_rounded,
            color: AppTheme.colorIncome,
            title:
                '$completed objetivo${completed > 1 ? 's' : ''} cumplido${completed > 1 ? 's' : ''}',
            subtitle: 'Seguí así'));
      }
    }

    if (txCount == 0) {
      insights.add(_InsightCard(
          icon: Icons.info_outline_rounded,
          color: Colors.white38,
          title: 'Sin movimientos',
          subtitle: 'No hay datos para este período todavía'));
    }

    return insights;
  }

  // ─── PDF Export ─────────────────────────────────────
  Future<void> _exportPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('Generando PDF...'),
        duration: Duration(seconds: 1)));

    try {
      final transactions = ref.read(filteredMonthlyTransactionsProvider);
      final categoryTotals = ref.read(monthlyCategoryTotalsProvider);
      final accountTotals = ref.read(monthlyAccountTotalsProvider);
      final accounts =
          ref.read(accountsStreamProvider).valueOrNull ?? [];
      final categories =
          ref.read(categoriesStreamProvider).valueOrNull ?? [];

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

      final path = await generateMonthlyReportPdf(
        year: _selectedMonth.year,
        month: _selectedMonth.month,
        totalIncome: income,
        totalExpense: expense,
        categoryTotals: categoryTotals,
        accountTotals: accountTotals,
        transactions: transactions,
        categoryNames: catNames,
        accountNames: accNames,
      );

      if (context.mounted) {
        messenger.showSnackBar(SnackBar(
          content: const Text('Reporte generado'),
          action: SnackBarAction(
              label: 'Abrir',
              onPressed: () => OpenFilex.open(path)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05)),
      );
}

// ═════════════════════════════════════════════════════
// SHARED WIDGETS
// ═════════════════════════════════════════════════════

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final String label;
  final double delta;
  final bool isExpense;

  const _DeltaChip({
    required this.label,
    required this.delta,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final isGood = isExpense ? !isUp : isUp;
    final color = isGood ? AppTheme.colorIncome : AppTheme.colorExpense;
    final icon =
        isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final pct = (delta.abs() * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          Text('$pct% $label',
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white));
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(color: Colors.white30, fontSize: 10)),
    ]);
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 9),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String name;
  final String? emoji;
  final double percent;
  final double amount;
  final Color color;

  const _CategoryBar({
    required this.name,
    this.emoji,
    required this.percent,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(
        symbol: '\$', decimalDigits: 0, locale: 'es_AR');
    return Row(children: [
      if (emoji != null) ...[
        Text(emoji!, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
      ],
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${(percent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 70,
        child: Text(fmt.format(amount),
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 12)),
      ),
    ]);
  }
}

class _HistoricalChart extends StatelessWidget {
  final List<MonthlyTotal> totals;
  final NumberFormat fmtCompact;

  const _HistoricalChart({
    required this.totals,
    required this.fmtCompact,
  });

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return const Center(
          child:
              Text('Sin datos', style: TextStyle(color: Colors.white38)));
    }

    final last6 =
        totals.length > 6 ? totals.sublist(totals.length - 6) : totals;
    final maxVal = last6.fold(0.0,
        (max, t) => math.max(max, math.max(t.totalIncome, t.totalExpense)));

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxVal * 1.15 + 1,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((spot) => LineTooltipItem(
                      fmtCompact.format(spot.y),
                      TextStyle(
                          color: spot.barIndex == 0
                              ? AppTheme.colorIncome
                              : AppTheme.colorExpense,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal / 3 + 1,
          getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.04), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= last6.length) {
                  return const SizedBox.shrink();
                }
                final m = last6[idx];
                return Text(
                    DateFormat('MMM', 'es')
                        .format(DateTime(m.year, m.month)),
                    style: const TextStyle(
                        color: Colors.white30, fontSize: 9));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(fmtCompact.format(value),
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 9));
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(last6.length,
                (i) => FlSpot(i.toDouble(), last6[i].totalIncome)),
            isCurved: true,
            color: AppTheme.colorIncome,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 3, color: AppTheme.colorIncome, strokeWidth: 0),
            ),
            belowBarData: BarAreaData(
                show: true,
                color: AppTheme.colorIncome.withValues(alpha: 0.06)),
          ),
          LineChartBarData(
            spots: List.generate(last6.length,
                (i) => FlSpot(i.toDouble(), last6[i].totalExpense)),
            isCurved: true,
            color: AppTheme.colorExpense,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 3,
                  color: AppTheme.colorExpense,
                  strokeWidth: 0),
            ),
            belowBarData: BarAreaData(
                show: true,
                color: AppTheme.colorExpense.withValues(alpha: 0.06)),
          ),
        ],
      ),
    );
  }
}

class _BalanceBarChart extends StatelessWidget {
  final List<MonthlyTotal> totals;
  final NumberFormat fmtCompact;

  const _BalanceBarChart({
    required this.totals,
    required this.fmtCompact,
  });

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return const Center(
          child:
              Text('Sin datos', style: TextStyle(color: Colors.white38)));
    }

    final last6 =
        totals.length > 6 ? totals.sublist(totals.length - 6) : totals;
    final balances = last6.map((t) => t.balance).toList();
    final maxAbs =
        balances.fold(0.0, (m, b) => math.max(m, b.abs())) * 1.2 + 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxAbs,
        minY: -maxAbs,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              fmtCompact.format(rod.toY),
              TextStyle(
                  color: rod.toY >= 0
                      ? AppTheme.colorIncome
                      : AppTheme.colorExpense,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= last6.length) {
                  return const SizedBox.shrink();
                }
                final m = last6[idx];
                return Text(
                    DateFormat('MMM', 'es')
                        .format(DateTime(m.year, m.month)),
                    style: const TextStyle(
                        color: Colors.white30, fontSize: 9));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(fmtCompact.format(value),
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 9));
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.04),
              strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          last6.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: balances[i],
                color: balances[i] >= 0
                    ? AppTheme.colorIncome
                    : AppTheme.colorExpense,
                width: 16,
                borderRadius: balances[i] >= 0
                    ? const BorderRadius.vertical(
                        top: Radius.circular(4))
                    : const BorderRadius.vertical(
                        bottom: Radius.circular(4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTrendChart extends StatelessWidget {
  final Map<String, List<MonthlyCategoryAmount>> trends;
  final List<String> topCats;
  final NumberFormat fmtCompact;

  const _CategoryTrendChart({
    required this.trends,
    required this.topCats,
    required this.fmtCompact,
  });

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return const Center(
          child:
              Text('Sin datos', style: TextStyle(color: Colors.white38)));
    }

    double maxVal = 0;
    for (final catId in topCats) {
      final data = trends[catId] ?? [];
      for (final d in data) {
        maxVal = math.max(maxVal, d.amount);
      }
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxVal * 1.15 + 1,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final catId =
                  spot.barIndex < topCats.length ? topCats[spot.barIndex] : '';
              return LineTooltipItem(
                '${_catLabel(catId)}: ${fmtCompact.format(spot.y)}',
                TextStyle(
                    color: _catColor(catId),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.04),
              strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                // Use first category's data for month labels
                final firstData = trends[topCats.first] ?? [];
                if (idx < 0 || idx >= firstData.length) {
                  return const SizedBox.shrink();
                }
                final m = firstData[idx];
                return Text(
                    DateFormat('MMM', 'es')
                        .format(DateTime(m.year, m.month)),
                    style: const TextStyle(
                        color: Colors.white30, fontSize: 9));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(fmtCompact.format(value),
                    style: const TextStyle(
                        color: Colors.white24, fontSize: 9));
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: topCats.map((catId) {
          final data = trends[catId] ?? [];
          return LineChartBarData(
            spots: List.generate(data.length,
                (i) => FlSpot(i.toDouble(), data[i].amount)),
            isCurved: true,
            color: _catColor(catId),
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 2.5,
                  color: _catColor(catId),
                  strokeWidth: 0),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BudgetStatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _BudgetStatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text('$count $label',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InsightCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

class _ProjectionRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? subtitle;

  const _ProjectionRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12)),
            if (subtitle != null)
              Text(subtitle!,
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 9)),
          ],
        ),
      ),
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700)),
    ]);
  }
}

class _LoanRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _LoanRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label,
            style:
                const TextStyle(color: Colors.white54, fontSize: 12)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _AlertChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.colorTransfer : Colors.white38;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.colorTransfer.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active
                  ? AppTheme.colorTransfer.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white70 : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.insert_chart_outlined_rounded,
              color: Colors.white12, size: 48),
          const SizedBox(height: 8),
          Text(message,
              style:
                  const TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}
