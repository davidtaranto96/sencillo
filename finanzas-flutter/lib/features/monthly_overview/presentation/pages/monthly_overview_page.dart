import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../providers/monthly_overview_providers.dart';
import '../widgets/statement_scanner_bottom_sheet.dart';
import '../widgets/month_closure_wizard.dart';

class MonthlyOverviewPage extends ConsumerStatefulWidget {
  const MonthlyOverviewPage({super.key});

  @override
  ConsumerState<MonthlyOverviewPage> createState() => _MonthlyOverviewPageState();
}

class _MonthlyOverviewPageState extends ConsumerState<MonthlyOverviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final bool _isMonthClosed = false; // Prototype: Should be derived from account.lastClosedDate or a dedicated table

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _changeMonth(int delta) {
    final current = ref.read(selectedOverviewMonthProvider);
    ref.read(selectedOverviewMonthProvider.notifier).state = 
        DateTime(current.year, current.month + delta);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedOverviewMonthProvider);
    final monthName = DateFormat('MMMM yyyy', 'es').format(selectedMonth);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white54, size: 20),
              onPressed: () => _changeMonth(-1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 80),
                child: Text(
                  '${monthName[0].toUpperCase()}${monthName.substring(1)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
              onPressed: () => _changeMonth(1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (selectedMonth.month == DateTime.now().month)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  side: BorderSide(
                    color: _isMonthClosed ? Colors.white38 : AppTheme.colorTransfer.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  if (_isMonthClosed) {
                    _showReopenConfirmation(context);
                  } else {
                    MonthClosureWizard.show(context, selectedMonth);
                  }
                },
                child: Text(
                  _isMonthClosed ? 'Modificar Cierre' : 'Cerrar Mes',
                  style: TextStyle(
                    color: _isMonthClosed ? Colors.white54 : Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.document_scanner_outlined, color: AppTheme.colorTransfer),
            tooltip: 'Escanear Resumen',
            onPressed: () => StatementScannerBottomSheet.show(context),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.colorTransfer,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Compartidos'),
            Tab(text: 'Préstamos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ResumenTab(),
          _CompartidosTab(),
          _PrestamosTab(),
        ],
      ),
    );
  }

  void _showReopenConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Mes Cerrado', style: TextStyle(color: Colors.white)),
        content: const Text('Este mes ya fue cerrado. ¿Querés modificar el cierre anterior?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Re-open logic or wizard
            },
            child: const Text('Modificar'),
          ),
        ],
      ),
    );
  }
}

class _ResumenTab extends ConsumerWidget {
  const _ResumenTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(filteredMonthlyTransactionsProvider);
    final categoryTotals = ref.watch(monthlyCategoryTotalsProvider);
    final accountTotals = ref.watch(monthlyAccountTotalsProvider);
    
    final accounts = ref.watch(accountsStreamProvider).maybeWhen(
      data: (d) => d,
      orElse: () => [],
    );

    double ordinaryIncome = 0;
    double extraordinaryIncome = 0;
    double ordinaryExpense = 0;
    double extraordinaryExpense = 0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        if (tx.isExtraordinary) {
          extraordinaryIncome += tx.amount;
        } else {
          ordinaryIncome += tx.amount;
        }
      }
      if (tx.type == TransactionType.expense) {
        if (tx.isExtraordinary) {
          extraordinaryExpense += tx.amount;
        } else {
          ordinaryExpense += tx.amount;
        }
      }
    }
    final totalExpenses = ordinaryExpense + extraordinaryExpense;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // --- Detalle Consolidado ---
        _ConsolidatedSummaryCard(
          ordinaryIncome: ordinaryIncome,
          extraordinaryIncome: extraordinaryIncome,
          ordinaryExpense: ordinaryExpense,
          extraordinaryExpense: extraordinaryExpense,
          onEditIncome: () => _showEditIncomeDialog(context),
        ),
        const SizedBox(height: 24),

        // --- Filtros ---
        _buildFilters(context, ref, accounts),
        const SizedBox(height: 24),

        // --- Gastos por Categoría ---
        Text(
          'Gastos por Categoría',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 12),
        if (categoryTotals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Sin gastos registrados', style: TextStyle(color: Colors.white30, fontSize: 13)),
          )
        else
          ...categoryTotals.entries.map((e) {
            final catName = e.key.replaceAll('cat_', '').replaceAll('_', ' '); // Simple format
            return _ProgressRow(
              label: catName[0].toUpperCase() + catName.substring(1),
              amount: e.value,
              total: totalExpenses,
              color: AppTheme.colorTransfer,
            );
          }),

        const SizedBox(height: 32),

        // --- Gastos por Cuenta/Tarjeta ---
        Text(
          'Gastos por Cuenta/Tarjeta',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 12),
        if (accountTotals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Sin gastos registrados', style: TextStyle(color: Colors.white30, fontSize: 13)),
          )
        else
          ...accountTotals.entries.map((e) {
            final accName = accounts.any((a) => a.id == e.key)
                ? accounts.firstWhere((a) => a.id == e.key).name
                : 'Otro';
            return _ProgressRow(
              label: accName,
              amount: e.value,
              total: totalExpenses,
              color: AppTheme.colorWarning,
            );
          }),
        
        const SizedBox(height: 100),
      ],
    );
  }

  void _showEditIncomeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ajustar Ingreso Mensual', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Monto de Ingreso',
                labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                prefixText: r'$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, WidgetRef ref, List accounts) {
    final selectedAcc = ref.watch(selectedOverviewAccountIdProvider);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('Todas las cuentas', style: TextStyle(fontSize: 12)),
            selected: selectedAcc == null,
            onSelected: (_) => ref.read(selectedOverviewAccountIdProvider.notifier).state = null,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            selectedColor: AppTheme.colorTransfer.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.colorTransfer,
          ),
          const SizedBox(width: 8),
          ...accounts.map((a) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(a.name, style: const TextStyle(fontSize: 12)),
              selected: selectedAcc == a.id,
              onSelected: (_) => ref.read(selectedOverviewAccountIdProvider.notifier).state = a.id,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedColor: AppTheme.colorTransfer.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.colorTransfer,
            ),
          )),
        ],
      ),
    );
  }
}

class _ConsolidatedSummaryCard extends StatelessWidget {
  final double ordinaryIncome;
  final double extraordinaryIncome;
  final double ordinaryExpense;
  final double extraordinaryExpense;
  final VoidCallback onEditIncome;

  const _ConsolidatedSummaryCard({
    required this.ordinaryIncome,
    required this.extraordinaryIncome,
    required this.ordinaryExpense,
    required this.extraordinaryExpense,
    required this.onEditIncome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Resumen del Mes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: AppTheme.colorTransfer, size: 20),
                onPressed: onEditIncome,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Ingresos Ordinarios', amount: ordinaryIncome, color: AppTheme.colorIncome),
          _SummaryRow(label: 'Ingresos Extraord.', amount: extraordinaryIncome, color: AppTheme.colorIncome.withValues(alpha: 0.7)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white10),
          ),
          _SummaryRow(label: 'Gastos Ordinarios', amount: ordinaryExpense, color: AppTheme.colorExpense),
          _SummaryRow(label: 'Gastos Extraord.', amount: extraordinaryExpense, color: AppTheme.colorExpense.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Balance Neto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text(
                formatAmount((ordinaryIncome + extraordinaryIncome) - (ordinaryExpense + extraordinaryExpense)),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SummaryRow({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(
            formatAmount(amount),
            style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.amount, required this.total, required this.color});
  final String label;
  final double amount;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text(formatAmount(amount), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.8)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompartidosTab extends StatelessWidget {
  const _CompartidosTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text(
          'Por cobrar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, color: AppTheme.colorTransfer),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sushi con Sofi y Juan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Sofi debe \$15.000, Juan \$15.000',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100), // spacing for bottom bar
      ],
    );
  }
}

class _PrestamosTab extends StatelessWidget {
  const _PrestamosTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text(
          'Mis Préstamos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Presté a Martin',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15)),
                  Text('\$120.000',
                      style: TextStyle(color: AppTheme.colorTransfer, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 0.2, // 20% devuelto
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.colorTransfer),
                ),
              ),
              SizedBox(height: 8),
              Text('Devolvió \$24.000', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}
