import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/goal_service.dart';
import '../../../../core/providers/distribution_provider.dart';
import '../../domain/models/goal.dart';
import '../providers/goals_provider.dart';
import '../widgets/add_goal_bottom_sheet.dart';
import '../../../transactions/domain/models/transaction.dart' as dom_tx;

class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final userProfile = ref.watch(userProfileStreamProvider).valueOrNull;
    final activeGoals = ref.watch(activeGoalsProvider);
    final completedGoals = ref.watch(completedGoalsProvider);
    final transactions = ref.watch(transactionsStreamProvider).valueOrNull ?? [];
    final dist = ref.watch(distributionProvider);
    final salary = userProfile?.monthlySalary;
    final totalSaved = [...activeGoals, ...completedGoals]
        .fold(0.0, (sum, g) => sum + g.savedAmount);

    // Calculate current month spending by bucket
    final now = DateTime.now();
    final monthTxs = transactions.where(
        (t) => t.date.month == now.month && t.date.year == now.year && t.type == dom_tx.TransactionType.expense);

    double needsSpent = 0;
    double wantsSpent = 0;
    for (final t in monthTxs) {
      final bucket = categoryBucketMap[t.categoryId];
      if (bucket == SpendingBucket.needs) {
        needsSpent += t.amount;
      } else {
        // Default to wants for unknown categories
        wantsSpent += t.amount;
      }
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Ahorro',
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero: total ahorrado
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _SavingsHero(totalSaved: totalSaved, salary: salary),
            ),
          ),

          // Distribución del sueldo con tracking en vivo
          if (salary != null && salary > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _SalaryBreakdown(
                  salary: salary,
                  dist: dist,
                  needsSpent: needsSpent,
                  wantsSpent: wantsSpent,
                  totalSaved: totalSaved,
                  onEdit: () => _showEditDistributionDialog(context, ref, dist),
                ),
              ),
            ),

          // Objetivos activos
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Objetivos activos',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  GestureDetector(
                    onTap: () => AddGoalBottomSheet.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.colorTransfer.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: AppTheme.colorTransfer),
                          const SizedBox(width: 4),
                          Text('Nuevo',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.colorTransfer)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (activeGoals.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _EmptyGoalsCard(onAdd: () => AddGoalBottomSheet.show(context)),
              ),
            ),

          if (activeGoals.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: activeGoals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _GoalSavingsCard(
                    goal: activeGoals[index],
                    onAddSavings: () => _showAddSavingsDialog(context, ref, activeGoals[index]),
                  );
                },
              ),
            ),

          // Completados
          if (completedGoals.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text('Completados',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white54)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: completedGoals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final g = completedGoals[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.colorIncome.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.colorIncome.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.colorIncome.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: AppTheme.colorIncome, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name,
                                  style: GoogleFonts.inter(
                                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
                                      decoration: TextDecoration.lineThrough, decorationColor: Colors.white38)),
                              Text('Completado — ${formatAmount(g.targetAmount)}',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _showEditDistributionDialog(BuildContext context, WidgetRef ref, BudgetDistribution current) {
    int needs = current.needsPct;
    int wants = current.wantsPct;
    int savings = current.savingsPct;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final total = needs + wants + savings;
          final isValid = total == 100;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF18181F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('Editar distribución', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Los porcentajes deben sumar 100%', style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
                  const SizedBox(height: 24),

                  _PctSlider(
                    label: 'Necesidades',
                    icon: Icons.home_rounded,
                    color: AppTheme.colorIncome,
                    value: needs,
                    onChanged: (v) => setLocal(() => needs = v),
                  ),
                  const SizedBox(height: 16),
                  _PctSlider(
                    label: 'Gustos',
                    icon: Icons.favorite_rounded,
                    color: AppTheme.colorWarning,
                    value: wants,
                    onChanged: (v) => setLocal(() => wants = v),
                  ),
                  const SizedBox(height: 16),
                  _PctSlider(
                    label: 'Ahorro',
                    icon: Icons.savings_rounded,
                    color: AppTheme.colorTransfer,
                    value: savings,
                    onChanged: (v) => setLocal(() => savings = v),
                  ),
                  const SizedBox(height: 16),

                  // Total indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isValid ? AppTheme.colorIncome : AppTheme.colorExpense).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (isValid ? AppTheme.colorIncome : AppTheme.colorExpense).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isValid ? Icons.check_circle_rounded : Icons.warning_rounded,
                          size: 18,
                          color: isValid ? AppTheme.colorIncome : AppTheme.colorExpense,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total: $total%',
                          style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: isValid ? AppTheme.colorIncome : AppTheme.colorExpense,
                          ),
                        ),
                        if (!isValid) ...[
                          const SizedBox(width: 8),
                          Text(
                            total > 100 ? '(sobran ${total - 100}%)' : '(faltan ${100 - total}%)',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.colorExpense.withValues(alpha: 0.7)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: isValid
                          ? () async {
                              await ref.read(distributionProvider.notifier).update(
                                needs: needs, wants: wants, savings: savings,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.colorTransfer,
                        disabledBackgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddSavingsDialog(BuildContext context, WidgetRef ref, Goal goal) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF18181F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Agregar ahorro', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Para "${goal.name}"', style: GoogleFonts.inter(fontSize: 14, color: Colors.white54)),
              const SizedBox(height: 8),
              Text('Faltan ${formatAmount(goal.remaining)} de ${formatAmount(goal.targetAmount)}',
                  style: GoogleFonts.inter(fontSize: 12, color: goal.color)),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                  prefixText: r'$ ',
                  prefixStyle: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.colorTransfer),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final amount = parseFormattedAmount(controller.text);
                    if (amount <= 0) return;
                    final newSaved = (goal.savedAmount + amount).clamp(0.0, goal.targetAmount * 2);
                    await ref.read(goalServiceProvider).updateGoal(goal.id, currentAmount: newSaved);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('+${formatAmount(amount)} ahorrado para "${goal.name}"'),
                        backgroundColor: AppTheme.colorIncome.withValues(alpha: 0.8),
                      ));
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorTransfer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Guardar ahorro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Percentage slider row for edit dialog
// ─────────────────────────────────────────────────────
class _PctSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int value;
  final ValueChanged<int> onChanged;

  const _PctSlider({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$value%', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.1),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// Hero total ahorrado
// ─────────────────────────────────────────────────────
class _SavingsHero extends StatelessWidget {
  final double totalSaved;
  final double? salary;
  const _SavingsHero({required this.totalSaved, this.salary});

  @override
  Widget build(BuildContext context) {
    final pct = salary != null && salary! > 0
        ? (totalSaved / salary! * 100).clamp(0, 999).toStringAsFixed(0)
        : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.colorTransfer.withValues(alpha: 0.18),
            const Color(0xFF1E1E2C),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_rounded, size: 22, color: AppTheme.colorTransfer),
              const SizedBox(width: 8),
              Text('Total ahorrado',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
              const Spacer(),
              if (pct != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$pct% del sueldo',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.colorTransfer)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatAmount(totalSaved),
            style: GoogleFonts.inter(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Distribución del sueldo con tracking en vivo
// ─────────────────────────────────────────────────────
class _SalaryBreakdown extends StatelessWidget {
  final double salary;
  final BudgetDistribution dist;
  final double needsSpent;
  final double wantsSpent;
  final double totalSaved;
  final VoidCallback onEdit;

  const _SalaryBreakdown({
    required this.salary,
    required this.dist,
    required this.needsSpent,
    required this.wantsSpent,
    required this.totalSaved,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final needsBudget = salary * dist.needsPct / 100;
    final wantsBudget = salary * dist.wantsPct / 100;
    final savingsBudget = salary * dist.savingsPct / 100;

    final needsProgress = needsBudget > 0 ? (needsSpent / needsBudget).clamp(0.0, 1.5) : 0.0;
    final wantsProgress = wantsBudget > 0 ? (wantsSpent / wantsBudget).clamp(0.0, 1.5) : 0.0;
    final savingsProgress = savingsBudget > 0 ? (totalSaved / savingsBudget).clamp(0.0, 1.5) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Distribución (${dist.needsPct}/${dist.wantsPct}/${dist.savingsPct})',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 14, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text('Editar', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white60)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Basado en tu sueldo de ${formatAmount(salary)}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 18),

          _BucketRow(
            label: 'Necesidades',
            detail: 'Alquiler, servicios, comida',
            budget: needsBudget,
            spent: needsSpent,
            pct: '${dist.needsPct}%',
            color: AppTheme.colorIncome,
            icon: Icons.home_rounded,
            progress: needsProgress,
          ),
          const SizedBox(height: 16),
          _BucketRow(
            label: 'Gustos',
            detail: 'Salidas, entretenimiento, compras',
            budget: wantsBudget,
            spent: wantsSpent,
            pct: '${dist.wantsPct}%',
            color: AppTheme.colorWarning,
            icon: Icons.favorite_rounded,
            progress: wantsProgress,
          ),
          const SizedBox(height: 16),
          _BucketRow(
            label: 'Ahorro',
            detail: 'Objetivos, emergencias, inversión',
            budget: savingsBudget,
            spent: totalSaved,
            pct: '${dist.savingsPct}%',
            color: AppTheme.colorTransfer,
            icon: Icons.savings_rounded,
            progress: savingsProgress,
            isSavings: true,
          ),
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  final String label;
  final String detail;
  final double budget;
  final double spent;
  final String pct;
  final Color color;
  final IconData icon;
  final double progress;
  final bool isSavings;

  const _BucketRow({
    required this.label,
    required this.detail,
    required this.budget,
    required this.spent,
    required this.pct,
    required this.color,
    required this.icon,
    required this.progress,
    this.isSavings = false,
  });

  @override
  Widget build(BuildContext context) {
    final overBudget = !isSavings && progress > 1.0;
    final barColor = overBudget ? AppTheme.colorExpense : color;
    final remaining = budget - spent;
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(pct, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ),
                  if (overBudget) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.colorExpense.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('¡Excedido!',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.colorExpense)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(detail, style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: clampedProgress,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSavings
                        ? '${formatAmount(spent)} ahorrado'
                        : '${formatAmount(spent)} gastado',
                    style: GoogleFonts.inter(fontSize: 10, color: barColor),
                  ),
                  Text(
                    isSavings
                        ? (remaining > 0 ? 'Meta: ${formatAmount(budget)}' : '¡Objetivo cumplido!')
                        : (remaining > 0 ? 'Quedan ${formatAmount(remaining)}' : 'Excedido ${formatAmount(-remaining)}'),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: (!isSavings && remaining <= 0) ? AppTheme.colorExpense : Colors.white54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// Goal savings card
// ─────────────────────────────────────────────────────
class _GoalSavingsCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onAddSavings;
  const _GoalSavingsCard({required this.goal, required this.onAddSavings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: goal.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(goal.icon, color: goal.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('${formatAmount(goal.savedAmount)} de ${formatAmount(goal.targetAmount)}',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
              SizedBox(
                width: 46, height: 46,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: goal.progress,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(goal.color),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text('${(goal.progress * 100).toInt()}%',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(goal.color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (goal.isCompleted)
                      Text('¡Objetivo completado!',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.colorIncome))
                    else
                      Text('Faltan ${formatAmount(goal.remaining)}',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                    if (goal.deadline != null) ...[
                      const SizedBox(height: 2),
                      _deadlineText(goal.deadline!),
                    ],
                  ],
                ),
              ),
              if (!goal.isCompleted)
                GestureDetector(
                  onTap: onAddSavings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: goal.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: goal.color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: goal.color),
                        const SizedBox(width: 4),
                        Text('Ahorrar',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: goal.color)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deadlineText(DateTime deadline) {
    final days = deadline.difference(DateTime.now()).inDays;
    final color = days < 0
        ? AppTheme.colorExpense
        : days <= 7 ? AppTheme.colorWarning : AppTheme.colorTransfer;
    final text = days < 0
        ? 'Venció hace ${-days} días'
        : days == 0 ? '¡Hoy!' : 'Quedan $days días';
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 10, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// Empty goals card
// ─────────────────────────────────────────────────────
class _EmptyGoalsCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyGoalsCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.flag_outlined, size: 44, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          Text('Sin objetivos de ahorro',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 6),
          Text('Creá una meta para empezar a destinar ahorros.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white54)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Crear objetivo'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.colorTransfer,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
