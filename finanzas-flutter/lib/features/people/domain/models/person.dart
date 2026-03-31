import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Person extends Equatable {
  final String id;
  final String name;
  final String? alias;
  final Color avatarColor;
  final double totalBalance; 
  // Positivo: Ellos me deben plata a mí.
  // Negativo: Yo les debo plata a ellos.

  const Person({
    required this.id,
    required this.name,
    this.alias,
    required this.avatarColor,
    this.totalBalance = 0.0,
  });

  String get displayName => alias ?? name;
  
  bool get owesMe => totalBalance > 0;
  bool get iOweThem => totalBalance < 0;

  @override
  List<Object?> get props => [id, name, totalBalance];
}
