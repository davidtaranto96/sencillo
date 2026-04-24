import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/logic/goal_service.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/models/goal.dart';
import '../providers/goals_provider.dart';
import '../widgets/add_goal_bottom_sheet.dart';
import '../../../../shared/widgets/empty_state.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _deleteGoal(Goal goal) async {
    await ref.read(goalServiceProvider).deleteGoal(goal.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${goal.name}" eliminado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final activeGoals = ref.watch(activeGoalsProvider);
    final completedGoals = ref.watch(completedGoalsProvider);
    final summary = ref.watch(goalsSummaryProvider);
    final isEmpty = activeGoals.isEmpty && completedGoals.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Metas',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // ── Empty state ──
            if (isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyGoals(
                  onAdd: () => AddGoalBottomSheet.show(context),
                ),
              ),

            // ── Summary card ──
            if (activeGoals.isNotEmpty)
              SliverToBoxAdapter(
                child: _SummaryCard(summary: summary),
              ),

            // ── Active goals section ──
            if (activeGoals.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    children: [
                      const Text(
                        'En progreso',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activeGoals.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.colorTransfer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: activeGoals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final goal = activeGoals[index];
                    return _GoalListCard(
                      goal: goal,
                      insight: insightForGoal(goal),
                      onDelete: () => _deleteGoal(goal),
                      onQuickAdd: () => _showQuickAddSheet(goal),
                    );
                  },
                ),
              ),
            ],

            // ── Completed goals section ──
            if (completedGoals.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                  child: Row(
                    children: [
                      const Text(
                        'Completados',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.colorIncome.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${completedGoals.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.colorIncome,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: completedGoals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _CompletedGoalCard(
                      goal: completedGoals[index],
                      onDelete: () => _deleteGoal(completedGoals[index]),
                    );
                  },
                ),
              ),
            ],

            SliverToBoxAdapter(child: SizedBox(height: 70 + MediaQuery.of(context).padding.bottom + 24)),
          ],
        ),
      ),
    );
  }

  void _showQuickAddSheet(Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickAddSavingsSheet(goal: goal),
    );
  }
}

// ─────────────────────────────────────────────
// Summary Card
// ─────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final GoalsSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.colorTransfer.withValues(alpha: 0.15),
              AppTheme.colorIncome.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.colorTransfer.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.savings_rounded,
                      color: AppTheme.colorTransfer, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progreso total',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatAmount(summary.totalSaved)} de ${formatAmount(summary.totalTarget)}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.colorTransfer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(summary.progress * 100).toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.colorTransfer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Barra de progreso global
            _MilestoneProgressBar(
              progress: summary.progress,
              color: AppTheme.colorTransfer,
              height: 8,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${summary.activeCount} objetivo${summary.activeCount != 1 ? 's' : ''} activo${summary.activeCount != 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white38),
                ),
                Text(
                  'Faltan ${formatAmount(summary.totalRemaining, compact: true)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Goal List Card (active)
// ─────────────────────────────────────────────
class _GoalListCard extends StatelessWidget {
  final Goal goal;
  final GoalInsight insight;
  final VoidCallback onDelete;
  final VoidCallback onQuickAdd;

  const _GoalListCard({
    required this.goal,
    required this.insight,
    required this.onDelete,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showOptionsSheet(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: goal.color.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: icon + name + percentage + quick add ──
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: goal.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(goal.icon, color: goal.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatAmount(goal.savedAmount)} / ${formatAmount(goal.targetAmount)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Percentage badge
                Text(
                  '${(goal.progress * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: goal.color,
                  ),
                ),
                const SizedBox(width: 8),
                // Quick add button
                GestureDetector(
                  onTap: onQuickAdd,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: goal.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_rounded,
                        color: goal.color, size: 20),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Progress bar with milestones ──
            _MilestoneProgressBar(
              progress: goal.progress,
              color: goal.color,
              height: 6,
            ),

            const SizedBox(height: 12),

            // ── Insight IA + deadline ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(insight.icon,
                      size: 14, color: insight.color.withValues(alpha: 0.8)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insight.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: insight.color.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            if (goal.deadline != null) ...[
              const SizedBox(height: 8),
              _DeadlineChip(deadline: goal.deadline!),
            ],
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(goal.name,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              '${formatAmount(goal.savedAmount)} de ${formatAmount(goal.targetAmount)}',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading:
                  const Icon(Icons.edit_rounded, color: AppTheme.colorTransfer),
              title: const Text('Editar Objetivo',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                AddGoalBottomSheet.show(ctx, goalToEdit: goal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded,
                  color: AppTheme.colorExpense),
              title: Text('Eliminar Objetivo',
                  style: TextStyle(
                      color: AppTheme.colorExpense,
                      fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Milestone Progress Bar
// ─────────────────────────────────────────────
class _MilestoneProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final double height;

  const _MilestoneProgressBar({
    required this.progress,
    required this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height + 6, // extra for milestone dots
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background track
              Positioned(
                top: 3,
                left: 0,
                right: 0,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
              // Filled track with gradient
              Positioned(
                top: 3,
                left: 0,
                child: Container(
                  height: height,
                  width: width * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.5),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // Milestone dots at 25%, 50%, 75%
              for (final milestone in [0.25, 0.50, 0.75])
                Positioned(
                  top: 0,
                  left: width * milestone - 4.5,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: progress >= milestone
                          ? color
                          : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: progress >= milestone
                            ? color.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.05),
                        width: 1.5,
                      ),
                    ),
                    child: progress >= milestone
                        ? const Icon(Icons.check, size: 5, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Deadline Chip
// ─────────────────────────────────────────────
class _DeadlineChip extends StatelessWidget {
  final DateTime deadline;
  const _DeadlineChip({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = deadline.difference(now).inDays;

    String text;
    Color color;

    if (days < 0) {
      text = 'Vencido';
      color = AppTheme.colorExpense;
    } else if (days == 0) {
      text = '¡Hoy!';
      color = AppTheme.colorWarning;
    } else if (days <= 7) {
      text = '$days d';
      color = AppTheme.colorWarning;
    } else if (days <= 30) {
      text = '$days d';
      color = AppTheme.colorTransfer;
    } else {
      final months = (days / 30).floor();
      text = '${months}m ${days - months * 30}d';
      color = Colors.white38;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: 11, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Completed Goal Card
// ─────────────────────────────────────────────
class _CompletedGoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onDelete;

  const _CompletedGoalCard({required this.goal, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF18181F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded,
                      color: AppTheme.colorExpense),
                  title: Text('Eliminar "${goal.name}"',
                      style: TextStyle(
                          color: AppTheme.colorExpense,
                          fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.colorIncome.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.colorIncome.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.colorIncome.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: AppTheme.colorIncome, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white70,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¡Meta alcanzada! ${formatAmount(goal.targetAmount)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.colorIncome.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.colorIncome, size: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quick Add Savings Bottom Sheet
// ─────────────────────────────────────────────
class _QuickAddSavingsSheet extends ConsumerStatefulWidget {
  final Goal goal;
  const _QuickAddSavingsSheet({required this.goal});

  @override
  ConsumerState<_QuickAddSavingsSheet> createState() =>
      _QuickAddSavingsSheetState();
}

class _QuickAddSavingsSheetState extends ConsumerState<_QuickAddSavingsSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = parseFormattedAmount(_controller.text.trim());
    if (amount <= 0) return;

    setState(() => _saving = true);

    final newSaved = widget.goal.savedAmount + amount;
    await ref.read(goalServiceProvider).updateGoal(
          widget.goal.id,
          currentAmount: newSaved,
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '+${formatAmount(amount)} agregados a "${widget.goal.name}"'),
          backgroundColor: AppTheme.colorIncome.withValues(alpha: 0.9),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final goal = widget.goal;
    final remaining = goal.remaining;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: goal.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(goal.icon, color: goal.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agregar ahorro',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      goal.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: goal.color.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress mini
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(goal.progress * 100).toInt()}% completado',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
              Text(
                'Faltan ${formatAmount(remaining)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: goal.color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Amount field
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorFormatter()],
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: goal.color,
              ),
              hintText: '0',
              hintStyle: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white12,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),

          const SizedBox(height: 8),

          // Quick amount chips
          Wrap(
            spacing: 8,
            children: [
              _QuickAmountChip(
                label: formatAmount(remaining * 0.1, compact: true),
                onTap: () => _setAmount(remaining * 0.1),
                color: goal.color,
              ),
              _QuickAmountChip(
                label: formatAmount(remaining * 0.25, compact: true),
                onTap: () => _setAmount(remaining * 0.25),
                color: goal.color,
              ),
              _QuickAmountChip(
                label: formatAmount(remaining * 0.5, compact: true),
                onTap: () => _setAmount(remaining * 0.5),
                color: goal.color,
              ),
              _QuickAmountChip(
                label: 'Todo',
                onTap: () => _setAmount(remaining),
                color: goal.color,
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.savings_rounded),
              label: Text(_saving ? 'Guardando...' : 'Agregar ahorro'),
              style: FilledButton.styleFrom(
                backgroundColor: goal.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setAmount(double amount) {
    final intAmount = amount.round();
    _controller.text = formatInitialAmount(intAmount.toDouble());
    _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length);
  }
}

// ─────────────────────────────────────────────
// Quick Amount Chip
// ─────────────────────────────────────────────
class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _QuickAmountChip({
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────
class _EmptyGoals extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyGoals({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      variant: EmptyStateVariant.full,
      icon: Icons.flag_outlined,
      title: '¿Cuál es tu próximo objetivo?',
      description: 'Creá una meta de ahorro y seguí tu progreso hasta cumplirla.',
      ctaLabel: 'Crear objetivo',
      ctaIcon: Icons.add_rounded,
      onCta: onAdd,
      extraContent: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: const [
          EmptyStateExampleChip(text: '🌴 Viaje', leadingIcon: null),
          EmptyStateExampleChip(text: '🛟 Emergencia'),
          EmptyStateExampleChip(text: '💻 Tecnología'),
        ],
      ),
    );
  }
}
