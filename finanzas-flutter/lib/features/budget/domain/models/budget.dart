import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Budget extends Equatable {
  final String id;
  final String categoryName;
  final IconData icon;
  final Color color;
  final double limitAmount;
  final double spentAmount;
  final String monthYear; // "2026-03"
  final bool isFixed; // Para separar Fijos de Variables

  const Budget({
    required this.id,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.limitAmount,
    required this.spentAmount,
    required this.monthYear,
    this.isFixed = false,
  });

  double get remaining => limitAmount - spentAmount;
  double get progress => spentAmount / limitAmount;
  bool get isOverBudget => spentAmount > limitAmount;
  double get usedPercent => (progress * 100).clamp(0, 100);

  @override
  List<Object?> get props => [id, monthYear];
}
