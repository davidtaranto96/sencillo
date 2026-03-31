import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../features/transactions/domain/models/transaction.dart';
import '../theme/app_theme.dart';

/// Formatea montos en ARS
String formatAmount(double amount, {bool compact = false}) {
  if (compact && amount.abs() >= 1000000) {
    return '\$${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (compact && amount.abs() >= 1000) {
    return '\$${(amount / 1000).toStringAsFixed(0)}K';
  }
  final formatter = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

/// Formatea fecha de forma amigable
String formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);

  if (d == today) return 'Hoy';
  if (d == yesterday) return 'Ayer';

  final diff = today.difference(d).inDays;
  if (diff < 7) return DateFormat('EEEE', 'es').format(date);
  return DateFormat('d MMM', 'es').format(date);
}

/// Formatea fecha completa
String formatFullDate(DateTime date) {
  return DateFormat('d MMMM yyyy', 'es').format(date);
}

/// Color según tipo de transacción
Color colorForType(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return AppTheme.colorIncome;
    case TransactionType.expense:
      return AppTheme.colorExpense;
    case TransactionType.transfer:
      return AppTheme.colorTransfer;
    case TransactionType.loanGiven:
      return AppTheme.colorWarning;
    case TransactionType.loanReceived:
      return AppTheme.colorIncome;
  }
}

/// Signo según tipo
String signForType(TransactionType type) {
  switch (type) {
    case TransactionType.income:
      return '+';
    case TransactionType.expense:
      return '-';
    case TransactionType.transfer:
      return '↔';
    case TransactionType.loanGiven:
      return '-';
    case TransactionType.loanReceived:
      return '+';
  }
}
