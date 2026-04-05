import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class DebtDetail extends Equatable {
  final String groupName;
  final double amount;

  const DebtDetail({required this.groupName, required this.amount});

  @override
  List<Object?> get props => [groupName, amount];
}

class Person extends Equatable {
  final String id;
  final String name;
  final String? alias;
  final Color avatarColor;
  final double totalBalance;
  final String? cbu;
  final String? notes;
  final List<DebtDetail> groupDebts;
  final String? linkedUserId; // Firebase UID si está vinculado como amigo
  // Positivo: Ellos me deben plata a mí.
  // Negativo: Yo les debo plata a ellos.

  const Person({
    required this.id,
    required this.name,
    this.alias,
    required this.avatarColor,
    this.totalBalance = 0.0,
    this.cbu,
    this.notes,
    this.groupDebts = const [],
    this.linkedUserId,
  });

  String get displayName => alias ?? name;
  bool get isLinked => linkedUserId != null;
  bool get owesMe => totalBalance > 0;
  bool get iOweThem => totalBalance < 0;

  @override
  List<Object?> get props => [id, name, totalBalance, cbu, notes, groupDebts, linkedUserId];
}
