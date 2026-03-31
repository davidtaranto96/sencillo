import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/budget.dart';
import '../../../../core/theme/app_theme.dart';

// Generamos datos mock con estilo UI similar al Dashboard (neones, dark)

final mockBudgetsProvider = Provider<List<Budget>>((ref) {
  return [
    // Gastos Fijos
    Budget(
      id: '1',
      categoryName: 'Alquiler & Expensas',
      icon: Icons.home_work_rounded,
      color: Colors.blueAccent,
      limitAmount: 250000,
      spentAmount: 250000,
      monthYear: '2026-03',
      isFixed: true,
    ),
    Budget(
      id: '2',
      categoryName: 'Servicios (Luz, Gas, Internet)',
      icon: Icons.bolt_rounded,
      color: Colors.yellowAccent,
      limitAmount: 45000,
      spentAmount: 32000,
      monthYear: '2026-03',
      isFixed: true,
    ),
    Budget(
      id: '3',
      categoryName: 'Gimnasio & Suscripciones',
      icon: Icons.fitness_center_rounded,
      color: Colors.orangeAccent,
      limitAmount: 22000,
      spentAmount: 22000,
      monthYear: '2026-03',
      isFixed: true,
    ),
    
    // Gastos Variables
    Budget(
      id: '4',
      categoryName: 'Supermercado',
      icon: Icons.shopping_cart_rounded,
      color: AppTheme.colorExpense, // Rosa neo
      limitAmount: 150000,
      spentAmount: 110000,
      monthYear: '2026-03',
      isFixed: false,
    ),
    Budget(
      id: '5',
      categoryName: 'Salidas & Ocio',
      icon: Icons.local_bar_rounded,
      color: Colors.purpleAccent,
      limitAmount: 80000,
      spentAmount: 95000, // OVER BUDGET para mostrar el warning
      monthYear: '2026-03',
      isFixed: false,
    ),
    Budget(
      id: '6',
      categoryName: 'Transporte & Nafta',
      icon: Icons.directions_car_rounded,
      color: AppTheme.colorTransfer, // Celeste neon
      limitAmount: 60000,
      spentAmount: 45000,
      monthYear: '2026-03',
      isFixed: false,
    ),
  ];
});

final fixedBudgetsProvider = Provider<List<Budget>>((ref) {
  return ref.watch(mockBudgetsProvider).where((b) => b.isFixed).toList();
});

final variableBudgetsProvider = Provider<List<Budget>>((ref) {
  return ref.watch(mockBudgetsProvider).where((b) => !b.isFixed).toList();
});

final totalBudgetLimitProvider = Provider<double>((ref) {
  return ref.watch(mockBudgetsProvider).fold(0.0, (sum, b) => sum + b.limitAmount);
});

final totalBudgetSpentProvider = Provider<double>((ref) {
  return ref.watch(mockBudgetsProvider).fold(0.0, (sum, b) => sum + b.spentAmount);
});
