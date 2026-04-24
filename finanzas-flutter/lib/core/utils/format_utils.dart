import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../features/transactions/domain/models/transaction.dart';
import '../theme/app_theme.dart';

/// Formatea montos: $1.234.567 (default ARS, prefijo).
///
/// Parámetros:
/// - [compact]: usa K/M para montos grandes (>= 1.000).
/// - [symbol]: símbolo a usar antes del número. Default `$`. Para multi-moneda
///   pasar e.g. `'USD '` y se renderiza como `USD 1.234`.
/// - [decimals]: cantidad de decimales (default 0). Pone separador de miles `.`
///   y decimal `,` siguiendo locale es_AR.
String formatAmount(double amount, {bool compact = false, String symbol = '\$', int decimals = 0}) {
  final negative = amount < 0;
  final abs = amount.abs();
  if (compact && abs >= 1000000) {
    return '${negative ? '-' : ''}$symbol${(abs / 1000000).toStringAsFixed(1)}M';
  }
  if (compact && abs >= 1000) {
    return '${negative ? '-' : ''}$symbol${(abs / 1000).toStringAsFixed(0)}K';
  }
  final pattern = decimals > 0
      ? '#,##0.${'0' * decimals}'
      : '#,##0';
  final formatter = NumberFormat(pattern, 'es_AR');
  return '${negative ? '-' : ''}$symbol${formatter.format(abs)}';
}

/// Atajo: `formatAmount(x, compact: true)`. Útil para refactors automatizados.
String formatAmountCompact(double amount) => formatAmount(amount, compact: true);

/// TextInputFormatter que agrega separadores de miles (puntos) mientras escribís.
/// Acepta solo dígitos, formatea como 1.234.567
class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Solo dígitos
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '', selection: const TextSelection.collapsed(offset: 0));
    }

    final number = int.tryParse(digits) ?? 0;
    final formatted = NumberFormat('#,##0', 'es_AR').format(number);

    // Calcular posición del cursor
    final oldDigits = oldValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final addedDigits = digits.length - oldDigits.length;

    int newOffset;
    if (addedDigits >= 0) {
      // Escribiendo: cursor al final del texto formateado
      // Contar cuántos dígitos hay hasta la posición original del cursor
      int digitsBeforeCursor = 0;
      int rawPos = newValue.selection.baseOffset.clamp(0, newValue.text.length);
      for (int i = 0; i < rawPos && i < newValue.text.length; i++) {
        if (RegExp(r'\d').hasMatch(newValue.text[i])) digitsBeforeCursor++;
      }
      // Encontrar la posición en el texto formateado que corresponde
      int count = 0;
      newOffset = formatted.length;
      for (int i = 0; i < formatted.length; i++) {
        if (RegExp(r'\d').hasMatch(formatted[i])) count++;
        if (count == digitsBeforeCursor) {
          newOffset = i + 1;
          break;
        }
      }
    } else {
      // Borrando
      int digitsBeforeCursor = 0;
      int rawPos = newValue.selection.baseOffset.clamp(0, newValue.text.length);
      for (int i = 0; i < rawPos && i < newValue.text.length; i++) {
        if (RegExp(r'\d').hasMatch(newValue.text[i])) digitsBeforeCursor++;
      }
      int count = 0;
      newOffset = 0;
      for (int i = 0; i < formatted.length; i++) {
        if (RegExp(r'\d').hasMatch(formatted[i])) count++;
        if (count == digitsBeforeCursor) {
          newOffset = i + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset.clamp(0, formatted.length)),
    );
  }
}

/// Parsea un string formateado con separadores de miles a double
double parseFormattedAmount(String text) {
  final clean = text.replaceAll('.', '').replaceAll(',', '.').trim();
  return double.tryParse(clean) ?? 0;
}

/// Formatea un número para usar como valor inicial en un TextEditingController
/// Ejemplo: 1500000.0 → "1.500.000"
String formatInitialAmount(double amount) {
  if (amount == 0) return '';
  return NumberFormat('#,##0', 'es_AR').format(amount.abs().truncate());
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
