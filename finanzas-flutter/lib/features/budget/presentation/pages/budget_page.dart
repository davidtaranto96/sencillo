import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/logic/budget_service.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../transactions/domain/models/transaction.dart' as dom_tx;
import '../../domain/models/budget.dart';
import '../providers/budget_provider.dart';
import '../widgets/add_budget_bottom_sheet.dart';

class BudgetPage extends ConsumerStatefulWidget {
  /// [standalone] = true when pushed above the shell (from Más).
  /// Controls back button visibility.
  final bool standalone;
  const BudgetPage({super.key, this.standalone = false});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _deleteBudget(Budget budget) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.colorExpense, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Eliminar presupuesto', style: TextStyle(color: Colors.white, fontSize: 15))),
        ]),
        content: Text(
          'Eliminar "${budget.categoryName}"?\nLos movimientos no se borran.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.colorExpense, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(budgetServiceProvider).deleteBudget(budget.id, budget.categoryId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${budget.categoryName}" eliminado')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final fixedBudgets = ref.watch(fixedBudgetsProvider);
    final variableBudgets = ref.watch(variableBudgetsProvider);
    final totalSpent = ref.watch(totalBudgetSpentProvider);
    final totalLimit = ref.watch(totalBudgetLimitProvider);
    final isEmpty = fixedBudgets.isEmpty && variableBudgets.isEmpty;

    final allTxs = ref.watch(transactionsStreamProvider).valueOrNull ?? [];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthTxs = allTxs
        .where((t) =>
            t.type == dom_tx.TransactionType.expense && !t.date.isBefore(monthStart))
        .toList();

    // All budgets sorted by progress (most used first)
    final allBudgets = [...fixedBudgets, ...variableBudgets]
      ..sort((a, b) => b.progress.compareTo(a.progress));

    // Budgets over limit
    final overBudgets = allBudgets.where((b) => b.isOverBudget).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    if (widget.standalone) ...[
                      GestureDetector(
                        onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white54, size: 20),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text('Presupuesto',
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    const Spacer(),
                    if (!isEmpty)
                      GestureDetector(
                        onTap: () => AddBudgetBottomSheet.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.colorTransfer.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 16, color: AppTheme.colorTransfer),
                              const SizedBox(width: 4),
                              Text('Nuevo', style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.colorTransfer,
                              )),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Empty state ──
            if (isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyBudget(onAdd: () => AddBudgetBottomSheet.show(context)),
              ),

            // ── Summary ring + stats ──
            if (!isEmpty)
              SliverToBoxAdapter(
                child: _BudgetSummaryRing(
                  totalSpent: totalSpent,
                  totalLimit: totalLimit,
                  budgetCount: allBudgets.length,
                ),
              ),

            // ── Daily allowance + alerts ──
            if (!isEmpty)
              SliverToBoxAdapter(
                child: _QuickStatsRow(
                  totalSpent: totalSpent,
                  totalLimit: totalLimit,
                  overCount: overBudgets.length,
                ),
              ),

            // ── Alert banner if over budget ──
            if (overBudgets.isNotEmpty)
              SliverToBoxAdapter(
                child: _OverBudgetAlert(budgets: overBudgets),
              ),

            // ── Gastos Fijos ──
            if (fixedBudgets.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.push_pin_rounded,
                label: 'Fijos',
                spent: fixedBudgets.fold(0.0, (s, b) => s + b.spentAmount),
                limit: fixedBudgets.fold(0.0, (s, b) => s + b.limitAmount),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: fixedBudgets.length,
                  itemBuilder: (context, index) {
                    final b = fixedBudgets[index];
                    final txsForBudget = monthTxs.where((t) => t.categoryId == b.categoryId).toList()
                      ..sort((a, c) => c.date.compareTo(a.date));
                    return _BudgetCard(
                      budget: b,
                      transactions: txsForBudget,
                      onDelete: () => _deleteBudget(b),
                      onEdit: () => AddBudgetBottomSheet.show(context, budgetToEdit: b),
                    );
                  },
                ),
              ),
            ],

            // ── Gastos Variables ──
            if (variableBudgets.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.trending_up_rounded,
                label: 'Variables',
                spent: variableBudgets.fold(0.0, (s, b) => s + b.spentAmount),
                limit: variableBudgets.fold(0.0, (s, b) => s + b.limitAmount),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: variableBudgets.length,
                  itemBuilder: (context, index) {
                    final b = variableBudgets[index];
                    final txsForBudget = monthTxs.where((t) => t.categoryId == b.categoryId).toList()
                      ..sort((a, c) => c.date.compareTo(a.date));
                    return _BudgetCard(
                      budget: b,
                      transactions: txsForBudget,
                      onDelete: () => _deleteBudget(b),
                      onEdit: () => AddBudgetBottomSheet.show(context, budgetToEdit: b),
                    );
                  },
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// SUMMARY RING
// ═════════════════════════════════════════════════════════════
class _BudgetSummaryRing extends StatelessWidget {
  final double totalSpent;
  final double totalLimit;
  final int budgetCount;

  const _BudgetSummaryRing({
    required this.totalSpent,
    required this.totalLimit,
    required this.budgetCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;
    final isOver = totalSpent > totalLimit && totalLimit > 0;
    final pctUsed = (progress * 100).round();
    final remaining = totalLimit - totalSpent;
    final ringColor = isOver
        ? AppTheme.colorExpense
        : pctUsed > 80
            ? AppTheme.colorWarning
            : AppTheme.colorIncome;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          // Ring
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                color: ringColor,
                bgColor: Colors.white.withValues(alpha: 0.04),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pctUsed%',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: ringColor,
                      ),
                    ),
                    Text(
                      'usado',
                      style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM yyyy', 'es').format(DateTime.now()),
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                // Spent
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('Gastado', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                    const Spacer(),
                    Text(
                      formatAmount(totalSpent, compact: true),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Limit
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    )),
                    const SizedBox(width: 8),
                    Text('Presupuesto', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                    const Spacer(),
                    Text(
                      formatAmount(totalLimit, compact: true),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Remaining
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isOver ? AppTheme.colorExpense : AppTheme.colorIncome).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOver ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        size: 13,
                        color: isOver ? AppTheme.colorExpense : AppTheme.colorIncome,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOver
                            ? 'Excedido ${formatAmount(remaining.abs(), compact: true)}'
                            : 'Quedan ${formatAmount(remaining, compact: true)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOver ? AppTheme.colorExpense : AppTheme.colorIncome,
                        ),
                      ),
                    ],
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _RingPainter({required this.progress, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ═════════════════════════════════════════════════════════════
// QUICK STATS ROW
// ═════════════════════════════════════════════════════════════
class _QuickStatsRow extends StatelessWidget {
  final double totalSpent;
  final double totalLimit;
  final int overCount;

  const _QuickStatsRow({
    required this.totalSpent,
    required this.totalLimit,
    required this.overCount,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day;
    final remaining = totalLimit - totalSpent;
    final dailyAllowance = daysLeft > 0 && remaining > 0 ? remaining / daysLeft : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          // Daily allowance
          Expanded(
            child: _QuickStatChip(
              icon: Icons.today_rounded,
              label: 'Por dia',
              value: dailyAllowance > 0
                  ? formatAmount(dailyAllowance, compact: true)
                  : '-',
              color: AppTheme.colorTransfer,
            ),
          ),
          const SizedBox(width: 6),
          // Days left
          Expanded(
            child: _QuickStatChip(
              icon: Icons.hourglass_bottom_rounded,
              label: 'Dias restantes',
              value: '$daysLeft',
              color: Colors.white54,
            ),
          ),
          const SizedBox(width: 6),
          // Over count
          Expanded(
            child: _QuickStatChip(
              icon: overCount > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              label: overCount > 0 ? 'Excedidos' : 'Estado',
              value: overCount > 0 ? '$overCount' : 'OK',
              color: overCount > 0 ? AppTheme.colorExpense : AppTheme.colorIncome,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.white30)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// OVER BUDGET ALERT
// ═════════════════════════════════════════════════════════════
class _OverBudgetAlert extends StatelessWidget {
  final List<Budget> budgets;
  const _OverBudgetAlert({required this.budgets});

  @override
  Widget build(BuildContext context) {
    final names = budgets.map((b) => b.categoryName).take(3).join(', ');
    final extra = budgets.length > 3 ? ' y ${budgets.length - 3} mas' : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.colorExpense.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.colorExpense.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.colorExpense),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$names$extra excedido${budgets.length > 1 ? 's' : ''}',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.colorExpense),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// SECTION HEADER
// ═════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final double spent;
  final double limit;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.spent,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Row(
          children: [
            Icon(icon, size: 13, color: Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white60,
            )),
            const Spacer(),
            Text(
              '${formatAmount(spent, compact: true)} / ${formatAmount(limit, compact: true)}',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white30),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// BUDGET CARD (redesigned, expandable)
// ═════════════════════════════════════════════════════════════
class _BudgetCard extends StatefulWidget {
  final Budget budget;
  final List<dom_tx.Transaction> transactions;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BudgetCard({
    required this.budget,
    required this.transactions,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<_BudgetCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.budget;
    final isOver = b.isOverBudget;
    final hasTxs = widget.transactions.isNotEmpty;
    final pct = (b.progress * 100).round().clamp(0, 999);

    // Status color
    final statusColor = isOver
        ? AppTheme.colorExpense
        : b.progress > 0.8
            ? AppTheme.colorWarning
            : b.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? b.color.withValues(alpha: 0.15)
              : isOver
                  ? AppTheme.colorExpense.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: Column(
        children: [
          // ── Main row ──
          GestureDetector(
            onTap: hasTxs ? () => setState(() => _expanded = !_expanded) : null,
            onLongPress: () => _showOptions(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Icon
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: b.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(b.icon, color: b.color, size: 17),
                      ),
                      const SizedBox(width: 10),
                      // Name + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.categoryName,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOver
                                  ? 'Excedido ${formatAmount(b.spentAmount - b.limitAmount, compact: true)}'
                                  : hasTxs
                                      ? '${widget.transactions.length} mov. · Quedan ${formatAmount(b.remaining, compact: true)}'
                                      : 'Sin gastos',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isOver ? AppTheme.colorExpense : Colors.white38,
                                fontWeight: isOver ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Amount + percentage
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatAmount(b.spentAmount, compact: true),
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: isOver ? AppTheme.colorExpense : Colors.white,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '/ ${formatAmount(b.limitAmount, compact: true)}',
                                style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$pct%',
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (hasTxs) ...[
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white24),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: b.progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded transactions ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildTxList(),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildTxList() {
    final dateFmt = DateFormat('d MMM', 'es');

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Column(
        children: [
          for (final tx in widget.transactions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Container(width: 5, height: 5, decoration: BoxDecoration(
                    color: widget.budget.color.withValues(alpha: 0.5), shape: BoxShape.circle,
                  )),
                  const SizedBox(width: 8),
                  Text(dateFmt.format(tx.date), style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500,
                  )),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tx.title, style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(formatAmount(tx.amount, compact: true), style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54,
                  )),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // Quick edit/delete row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 12, color: AppTheme.colorTransfer.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text('Editar', style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 12, color: AppTheme.colorExpense.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text('Eliminar', style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
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
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(widget.budget.categoryName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
            Text(
              '${formatAmount(widget.budget.spentAmount, compact: true)} de ${formatAmount(widget.budget.limitAmount, compact: true)}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: AppTheme.colorTransfer),
              title: const Text('Editar presupuesto', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); widget.onEdit(); },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: AppTheme.colorExpense),
              title: Text('Eliminar', style: TextStyle(color: AppTheme.colorExpense)),
              onTap: () { Navigator.pop(ctx); widget.onDelete(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// EMPTY STATE
// ═════════════════════════════════════════════════════════════
class _EmptyBudget extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBudget({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.donut_large_outlined, size: 36, color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text('Sin presupuestos', style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Defini limites por categoria\npara controlar tus gastos.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Crear presupuesto'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
