import 'package:equatable/equatable.dart';

/// Tipo de transacción
enum TransactionType {
  income,        // ingreso
  expense,       // gasto
  transfer,      // transferencia
  loanGiven,     // préstamo a alguien (sale plata)
  loanReceived,  // préstamo de alguien (entra plata)
}

/// Modelo de dominio de una transacción
class Transaction extends Equatable {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final DateTime date;
  final String? note;
  final String? personId;
  final String? groupId;

  // Para gastos compartidos
  final double? sharedTotalAmount;   // total pagado
  final double? sharedOwnAmount;     // parte propia
  final double? sharedOtherAmount;   // parte ajena (a recuperar)
  final double? sharedRecovered;     // ya recuperado
  final bool isShared;

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.date,
    this.note,
    this.personId,
    this.groupId,
    this.sharedTotalAmount,
    this.sharedOwnAmount,
    this.sharedOtherAmount,
    this.sharedRecovered,
    this.isShared = false,
  });

  /// Pendiente a recuperar
  double get pendingToRecover =>
      (sharedOtherAmount ?? 0) - (sharedRecovered ?? 0);

  /// Gasto real (descontando lo que se recuperará)
  double get realExpense => isShared
      ? (sharedOwnAmount ?? amount)
      : amount;

  @override
  List<Object?> get props => [
        id,
        title,
        amount,
        type,
        categoryId,
        accountId,
        date,
        note,
        personId,
        groupId,
        isShared,
      ];
}
