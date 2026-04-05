import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/models/goal.dart';
import '../../../../core/database/database_providers.dart';

final activeGoalsProvider = Provider<List<Goal>>((ref) {
  return ref.watch(goalsStreamProvider).valueOrNull
      ?.where((g) => !g.isCompleted).toList() ?? [];
});

final completedGoalsProvider = Provider<List<Goal>>((ref) {
  return ref.watch(goalsStreamProvider).valueOrNull
      ?.where((g) => g.isCompleted).toList() ?? [];
});

// ── Resumen global de objetivos ──

class GoalsSummary {
  final int activeCount;
  final double totalSaved;
  final double totalTarget;

  const GoalsSummary({
    required this.activeCount,
    required this.totalSaved,
    required this.totalTarget,
  });

  double get progress => totalTarget > 0
      ? (totalSaved / totalTarget).clamp(0.0, 1.0)
      : 0.0;

  double get totalRemaining => totalTarget > totalSaved
      ? totalTarget - totalSaved
      : 0.0;
}

final goalsSummaryProvider = Provider<GoalsSummary>((ref) {
  final active = ref.watch(activeGoalsProvider);
  double saved = 0, target = 0;
  for (final g in active) {
    saved += g.savedAmount;
    target += g.targetAmount;
  }
  return GoalsSummary(
    activeCount: active.length,
    totalSaved: saved,
    totalTarget: target,
  );
});

// ── Insight IA por objetivo ──

class GoalInsight {
  final String message;
  final Color color;
  final IconData icon;

  const GoalInsight({
    required this.message,
    required this.color,
    required this.icon,
  });
}

GoalInsight insightForGoal(Goal goal) {
  if (goal.isCompleted) {
    return const GoalInsight(
      message: '¡Meta alcanzada!',
      color: AppTheme.colorIncome,
      icon: Icons.emoji_events_rounded,
    );
  }

  final remaining = goal.remaining;

  if (goal.deadline != null) {
    final now = DateTime.now();
    final daysLeft = goal.deadline!.difference(now).inDays;

    if (daysLeft < 0) {
      return GoalInsight(
        message: 'Fecha vencida — faltan ${formatAmount(remaining, compact: true)}',
        color: AppTheme.colorExpense,
        icon: Icons.warning_rounded,
      );
    }

    if (daysLeft == 0) {
      return GoalInsight(
        message: '¡Hoy es el día! Faltan ${formatAmount(remaining, compact: true)}',
        color: AppTheme.colorWarning,
        icon: Icons.today_rounded,
      );
    }

    final monthsLeft = daysLeft / 30.0;
    if (monthsLeft < 1) {
      final perDay = remaining / daysLeft;
      return GoalInsight(
        message: 'Ahorrá ${formatAmount(perDay, compact: true)}/día — quedan $daysLeft días',
        color: AppTheme.colorWarning,
        icon: Icons.speed_rounded,
      );
    }

    final perMonth = remaining / monthsLeft;
    return GoalInsight(
      message: 'Ahorrá ${formatAmount(perMonth, compact: true)}/mes para llegar a tiempo',
      color: AppTheme.colorTransfer,
      icon: Icons.auto_awesome_rounded,
    );
  }

  // Sin deadline — mensaje motivacional por progreso
  if (goal.progress < 0.1) {
    return const GoalInsight(
      message: '¡Dale el primer empujón!',
      color: AppTheme.colorTransfer,
      icon: Icons.rocket_launch_rounded,
    );
  }
  if (goal.progress < 0.25) {
    return const GoalInsight(
      message: '¡Buen arranque, seguí así!',
      color: AppTheme.colorTransfer,
      icon: Icons.trending_up_rounded,
    );
  }
  if (goal.progress < 0.5) {
    return GoalInsight(
      message: 'Llevas ${(goal.progress * 100).toInt()}% — ¡no pares!',
      color: AppTheme.colorTransfer,
      icon: Icons.auto_awesome_rounded,
    );
  }
  if (goal.progress < 0.75) {
    return const GoalInsight(
      message: '¡Más de la mitad! Ya se siente cerca',
      color: AppTheme.colorIncome,
      icon: Icons.emoji_events_rounded,
    );
  }
  return const GoalInsight(
    message: '¡Último tramo! Ya casi llegás',
    color: AppTheme.colorIncome,
    icon: Icons.flag_rounded,
  );
}
