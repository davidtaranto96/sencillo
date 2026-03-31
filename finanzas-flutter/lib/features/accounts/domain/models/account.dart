import 'package:equatable/equatable.dart';

enum AccountType {
  cash,      // efectivo
  bank,      // cuenta bancaria
  credit,    // tarjeta de crédito
  savings,   // caja de ahorro
  investment, // inversión
}

class Account extends Equatable {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final String currencyCode;
  final String? color;       // hex color
  final String? icon;
  final bool isDefault;

  // Para tarjetas de crédito
  final double? creditLimit;
  final int? closingDay;     // día de cierre
  final int? dueDay;         // día de vencimiento

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.currencyCode = 'ARS',
    this.color,
    this.icon,
    this.isDefault = false,
    this.creditLimit,
    this.closingDay,
    this.dueDay,
  });

  bool get isCreditCard => type == AccountType.credit;

  double get availableCredit =>
      isCreditCard ? (creditLimit ?? 0) - balance : balance;

  @override
  List<Object?> get props => [id, name, type, balance, currencyCode];
}
