import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Goal extends Equatable {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final IconData icon;
  final Color color;

  const Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    this.deadline,
    required this.icon,
    required this.color,
  });

  double get remaining => targetAmount > savedAmount ? targetAmount - savedAmount : 0.0;
  double get progress => targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => savedAmount >= targetAmount;

  @override
  List<Object?> get props => [id, savedAmount, targetAmount];
}
