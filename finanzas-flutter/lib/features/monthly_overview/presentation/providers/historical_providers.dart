import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../domain/models/historical_data.dart';
import 'monthly_overview_providers.dart';

/// Last 12 months of monthly totals
final historicalMonthlyTotalsProvider = Provider<List<MonthlyTotal>>((ref) {
  final txsAsync = ref.watch(transactionsStreamProvider);

  return txsAsync.maybeWhen(
    data: (transactions) {
      final now = DateTime.now();
      final totals = <MonthlyTotal>[];

      for (int i = 11; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i);
        final monthTxs = transactions.where((t) =>
            t.date.year == month.year && t.date.month == month.month).toList();

        double income = 0, expense = 0;
        for (final tx in monthTxs) {
          if (tx.type == TransactionType.income || tx.type == TransactionType.loanReceived) {
            income += tx.amount;
          } else if (tx.type == TransactionType.expense || tx.type == TransactionType.loanGiven) {
            expense += tx.amount;
          }
        }

        totals.add(MonthlyTotal(
          year: month.year,
          month: month.month,
          totalIncome: income,
          totalExpense: expense,
          transactionCount: monthTxs.length,
        ));
      }

      return totals;
    },
    orElse: () => [],
  );
});

/// Category spending trends for the last 6 months
final historicalCategoryTrendsProvider = Provider<Map<String, List<MonthlyCategoryAmount>>>((ref) {
  final txsAsync = ref.watch(transactionsStreamProvider);

  return txsAsync.maybeWhen(
    data: (transactions) {
      final now = DateTime.now();
      final result = <String, List<MonthlyCategoryAmount>>{};

      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i);
        final monthTxs = transactions.where((t) =>
            t.date.year == month.year &&
            t.date.month == month.month &&
            (t.type == TransactionType.expense || t.type == TransactionType.loanGiven));

        final catTotals = <String, double>{};
        for (final tx in monthTxs) {
          catTotals[tx.categoryId] = (catTotals[tx.categoryId] ?? 0) + tx.amount;
        }

        for (final entry in catTotals.entries) {
          result.putIfAbsent(entry.key, () => []);
          result[entry.key]!.add(MonthlyCategoryAmount(
            year: month.year,
            month: month.month,
            categoryId: entry.key,
            amount: entry.value,
          ));
        }
      }

      return result;
    },
    orElse: () => {},
  );
});

/// Comparison of selected month vs previous month
final monthComparisonProvider = Provider<MonthComparison?>((ref) {
  final totals = ref.watch(historicalMonthlyTotalsProvider);
  final selected = ref.watch(selectedOverviewMonthProvider);

  MonthlyTotal? findMonth(int year, int month) {
    try {
      return totals.firstWhere((t) => t.year == year && t.month == month);
    } catch (_) {
      return null;
    }
  }

  final current = findMonth(selected.year, selected.month);
  if (current == null) {
    return MonthComparison(
      current: MonthlyTotal(
        year: selected.year,
        month: selected.month,
        totalIncome: 0,
        totalExpense: 0,
        transactionCount: 0,
      ),
    );
  }

  final prevDate = DateTime(selected.year, selected.month - 1);
  final previous = findMonth(prevDate.year, prevDate.month);

  return MonthComparison(current: current, previous: previous);
});
