import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/goal.dart';
import '../../../../core/theme/app_theme.dart';

final mockGoalsProvider = Provider<List<Goal>>((ref) {
  return [
    Goal(
      id: '1',
      name: 'Fondo de Emergencia',
      targetAmount: 1000000,
      savedAmount: 650000,
      icon: Icons.shield_rounded,
      color: AppTheme.colorTransfer, // Celeste
    ),
    Goal(
      id: '2',
      name: 'Viaje a Brasil',
      targetAmount: 2500000,
      savedAmount: 500000,
      deadline: DateTime(2027, 1, 15),
      icon: Icons.flight_takeoff_rounded,
      color: Colors.yellowAccent,
    ),
    Goal(
      id: '3',
      name: 'Cambiar el auto',
      targetAmount: 8000000,
      savedAmount: 1200000,
      deadline: DateTime(2028, 5, 20),
      icon: Icons.directions_car_rounded,
      color: Colors.purpleAccent,
    ),
    Goal(
      id: '4',
      name: 'Nueva Notebook',
      targetAmount: 1500000,
      savedAmount: 1500000, // Meta completada
      icon: Icons.laptop_mac_rounded,
      color: Colors.greenAccent,
    ),
  ];
});

final activeGoalsProvider = Provider<List<Goal>>((ref) {
  return ref.watch(mockGoalsProvider).where((g) => !g.isCompleted).toList();
});

final completedGoalsProvider = Provider<List<Goal>>((ref) {
  return ref.watch(mockGoalsProvider).where((g) => g.isCompleted).toList();
});
