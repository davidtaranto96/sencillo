import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/person.dart';
import '../../domain/models/group.dart';


final mockPeopleProvider = Provider<List<Person>>((ref) {
  return [
    Person(
      id: 'p1',
      name: 'Sofía',
      avatarColor: Colors.pinkAccent,
      totalBalance: 45000,   // Sofi me debe a mí
    ),
    Person(
      id: 'p2',
      name: 'Juan Perez',
      alias: 'Juancito',
      avatarColor: Colors.blueAccent,
      totalBalance: -15000,  // Yo le debo a Juan
    ),
    Person(
      id: 'p3',
      name: 'Martin',
      avatarColor: Colors.greenAccent,
      totalBalance: 120000,  // Martin me debe mucho (préstamo o similar)
    ),
    Person(
      id: 'p4',
      name: 'Laura',
      avatarColor: Colors.orangeAccent,
      totalBalance: 0,       // Estamos saldados
    ),
  ];
});

final mockGroupsProvider = Provider<List<ExpenseGroup>>((ref) {
  final people = ref.read(mockPeopleProvider);
  return [
    ExpenseGroup(
      id: 'g1',
      name: 'Viaje a Bariloche',
      members: people,
      totalGroupExpense: 450000, // Lo que costó todo en grupo
    ),
    ExpenseGroup(
      id: 'g2',
      name: 'Departamento',
      members: [people[0], people[1]], // Solo Sofi y Juan
      totalGroupExpense: 90000,
    ),
  ];
});

/// Filtros para la vista
final peopleThatOweMeProvider = Provider<List<Person>>((ref) {
  return ref.watch(mockPeopleProvider).where((p) => p.owesMe).toList();
});

final peopleIOweProvider = Provider<List<Person>>((ref) {
  return ref.watch(mockPeopleProvider).where((p) => p.iOweThem).toList();
});

final globalPeopleBalanceProvider = Provider<double>((ref) {
  return ref.watch(mockPeopleProvider).fold(0.0, (sum, p) => sum + p.totalBalance);
});
