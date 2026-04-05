import 'package:equatable/equatable.dart';

/// Monthly totals for income and expense
class MonthlyTotal extends Equatable {
  final int year;
  final int month;
  final double totalIncome;
  final double totalExpense;
  final int transactionCount;

  const MonthlyTotal({
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactionCount,
  });

  double get balance => totalIncome - totalExpense;

  @override
  List<Object?> get props => [year, month, totalIncome, totalExpense, transactionCount];
}

/// Monthly spending for a specific category
class MonthlyCategoryAmount extends Equatable {
  final int year;
  final int month;
  final String categoryId;
  final double amount;

  const MonthlyCategoryAmount({
    required this.year,
    required this.month,
    required this.categoryId,
    required this.amount,
  });

  @override
  List<Object?> get props => [year, month, categoryId, amount];
}

/// Comparison between current and previous month
class MonthComparison {
  final MonthlyTotal current;
  final MonthlyTotal? previous;

  const MonthComparison({required this.current, this.previous});

  double get expenseDelta => previous != null && previous!.totalExpense > 0
      ? ((current.totalExpense - previous!.totalExpense) / previous!.totalExpense)
      : 0.0;

  double get incomeDelta => previous != null && previous!.totalIncome > 0
      ? ((current.totalIncome - previous!.totalIncome) / previous!.totalIncome)
      : 0.0;

  bool get isExpenseUp => current.totalExpense > (previous?.totalExpense ?? 0);
}
