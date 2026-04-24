import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../database/database_providers.dart';
import '../utils/format_utils.dart';
import '../../features/budget/presentation/providers/budget_provider.dart';
import '../../features/goals/presentation/providers/goals_provider.dart';

/// Tipo de alerta para diferenciar comportamiento.
enum AlertType { cardClosing, cardDue, budgetWarning, budgetExceeded, goalDeadline, monthClosing, debtOwed, debtOwing }

class AppAlert {
  final String id;
  final AlertType type;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final bool dismissible;

  const AppAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    this.dismissible = true,
  });
}

/// Alertas descartadas permanentemente o pospuestas por el usuario.
class DismissedAlertsNotifier extends StateNotifier<Set<String>> {
  DismissedAlertsNotifier() : super({}) {
    _load();
  }

  static const _kDismissedAlerts = 'dismissed_alerts';
  static const _kSnoozedAlerts = 'snoozed_alerts';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = (prefs.getStringList(_kDismissedAlerts) ?? []).toSet();

    // Load snoozed: stored as "id|timestamp_ms"
    final now = DateTime.now().millisecondsSinceEpoch;
    final snoozedRaw = prefs.getStringList(_kSnoozedAlerts) ?? [];
    final activeSnoozed = <String>{};
    final stillValid = <String>[];
    for (final entry in snoozedRaw) {
      final parts = entry.split('|');
      if (parts.length == 2) {
        final until = int.tryParse(parts[1]) ?? 0;
        if (until > now) {
          activeSnoozed.add(parts[0]);
          stillValid.add(entry);
        }
      }
    }
    // Prune expired snoozes
    if (stillValid.length != snoozedRaw.length) {
      await prefs.setStringList(_kSnoozedAlerts, stillValid);
    }

    state = {...dismissed, ...activeSnoozed};
  }

  Future<void> dismiss(String alertId) async {
    state = {...state, alertId};
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kDismissedAlerts) ?? [];
    if (!list.contains(alertId)) {
      list.add(alertId);
      await prefs.setStringList(_kDismissedAlerts, list);
    }
  }

  Future<void> snooze(String alertId, {int days = 7}) async {
    final until = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kSnoozedAlerts) ?? [];
    // Remove any existing snooze for this alertId
    list.removeWhere((e) => e.startsWith('$alertId|'));
    list.add('$alertId|$until');
    await prefs.setStringList(_kSnoozedAlerts, list);
    state = {...state, alertId};
  }

  Future<void> clearAll() async {
    state = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDismissedAlerts);
    await prefs.remove(_kSnoozedAlerts);
  }
}

final dismissedAlertsProvider =
    StateNotifierProvider<DismissedAlertsNotifier, Set<String>>(
        (ref) => DismissedAlertsNotifier());

/// Genera todas las alertas activas (presupuesto + objetivos).
/// Las alertas de tarjetas de crédito siguen en _AlertsSection por separado
/// porque tienen su propio widget con botones de pagar/deshacer.
final smartAlertsProvider = Provider<List<AppAlert>>((ref) {
  final alerts = <AppAlert>[];
  final now = DateTime.now();

  // ── Alertas de presupuesto ──
  final allBudgets = [
    ...ref.watch(fixedBudgetsProvider),
    ...ref.watch(variableBudgetsProvider),
  ];

  for (final b in allBudgets) {
    if (b.limitAmount <= 0) continue;
    final pct = b.spentAmount / b.limitAmount;

    if (pct >= 1.0) {
      alerts.add(AppAlert(
        id: 'budget_exceeded_${b.id}',
        type: AlertType.budgetExceeded,
        title: '${b.categoryName}: excedido',
        body:
            'Gastaste ${formatAmount(b.spentAmount)} de ${formatAmount(b.limitAmount)} presupuestados.',
        icon: Icons.warning_rounded,
        color: AppTheme.colorExpense,
      ));
    } else if (pct >= 0.8) {
      final pctInt = (pct * 100).toInt();
      alerts.add(AppAlert(
        id: 'budget_warning_${b.id}',
        type: AlertType.budgetWarning,
        title: '${b.categoryName}: $pctInt% usado',
        body:
            'Te queda ${formatAmount(b.remaining)} de presupuesto este mes.',
        icon: Icons.donut_large_rounded,
        color: AppTheme.colorWarning,
      ));
    }
  }

  // ── Alertas de objetivos con fecha límite ──
  final goals = ref.watch(activeGoalsProvider);
  for (final g in goals) {
    if (g.deadline == null) continue;
    final daysLeft = g.deadline!.difference(now).inDays;

    if (daysLeft < 0) {
      alerts.add(AppAlert(
        id: 'goal_overdue_${g.id}',
        type: AlertType.goalDeadline,
        title: '${g.name}: fecha vencida',
        body:
            'La fecha límite ya pasó y llevas ${(g.progress * 100).toInt()}% ahorrado.',
        icon: Icons.flag_rounded,
        color: AppTheme.colorExpense,
      ));
    } else if (daysLeft <= 7) {
      alerts.add(AppAlert(
        id: 'goal_urgent_${g.id}',
        type: AlertType.goalDeadline,
        title: '${g.name}: ${daysLeft == 0 ? "¡hoy!" : "$daysLeft días"}',
        body:
            'Llevas ${(g.progress * 100).toInt()}% de tu meta. ¡Dale un empujón final!',
        icon: Icons.flag_rounded,
        color: AppTheme.colorWarning,
      ));
    } else if (daysLeft <= 30) {
      alerts.add(AppAlert(
        id: 'goal_soon_${g.id}',
        type: AlertType.goalDeadline,
        title: '${g.name}: $daysLeft días restantes',
        body:
            'Llevas ${(g.progress * 100).toInt()}% ahorrado de tu objetivo.',
        icon: Icons.flag_outlined,
        color: AppTheme.colorTransfer,
      ));
    }
  }

  // ── Alerta de cierre de mes ──
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  final daysLeft = lastDay - now.day;

  if (daysLeft <= 2) {
    final msg = daysLeft == 0
        ? '¡Hoy es el último día del mes! Revisá tu resumen y cerrá el ciclo.'
        : daysLeft == 1
            ? 'Mañana se termina el mes. ¿Ya revisaste tu resumen?'
            : 'Faltan $daysLeft días para fin de mes. Buen momento para revisar el resumen.';
    alerts.add(AppAlert(
      id: 'month_closure_${now.year}_${now.month}',
      type: AlertType.monthClosing,
      title: 'Cierre de mes',
      body: msg,
      icon: Icons.calendar_month_rounded,
      color: AppTheme.colorWarning,
    ));
  }

  // ── Alertas de deudas con personas ──
  final people = ref.watch(peopleStreamProvider).valueOrNull ?? [];
  for (final p in people) {
    if (p.totalBalance == 0) continue;
    if (p.owesMe) {
      alerts.add(AppAlert(
        id: 'debt_owed_${p.id}',
        type: AlertType.debtOwed,
        title: '${p.displayName} te debe',
        body: '${p.displayName} te debe ${formatAmount(p.totalBalance)}. Recordale cobrarle.',
        icon: Icons.arrow_downward_rounded,
        color: AppTheme.colorIncome,
      ));
    } else {
      alerts.add(AppAlert(
        id: 'debt_owing_${p.id}',
        type: AlertType.debtOwing,
        title: 'Le debés a ${p.displayName}',
        body: 'Tenés una deuda de ${formatAmount(p.totalBalance.abs())} con ${p.displayName}.',
        icon: Icons.arrow_upward_rounded,
        color: AppTheme.colorExpense,
      ));
    }
  }

  return alerts;
});

/// Alertas visibles (no descartadas por el usuario).
final visibleAlertsProvider = Provider<List<AppAlert>>((ref) {
  final all = ref.watch(smartAlertsProvider);
  final dismissed = ref.watch(dismissedAlertsProvider);
  return all.where((a) => !dismissed.contains(a.id)).toList();
});
