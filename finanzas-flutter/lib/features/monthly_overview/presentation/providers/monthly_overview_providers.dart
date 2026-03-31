import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_providers.dart';
import '../../../transactions/domain/models/transaction.dart';

/// Month selected in the Monthly Overview
final selectedOverviewMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Selected Account ID for filtering
final selectedOverviewAccountIdProvider = StateProvider<String?>((ref) => null);

/// Selected Category ID for filtering
final selectedOverviewCategoryIdProvider = StateProvider<String?>((ref) => null);

/// Transactions for the selected month
final monthlyTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactionsAsync = ref.watch(transactionsStreamProvider);
  final selectedMonth = ref.watch(selectedOverviewMonthProvider);

  return transactionsAsync.maybeWhen(
    data: (transactions) {
      return transactions.where((t) {
        return t.date.year == selectedMonth.year && 
               t.date.month == selectedMonth.month;
      }).toList();
    },
    orElse: () => [],
  );
});

/// Filtered transactions based on Account and Category
final filteredMonthlyTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  final accId = ref.watch(selectedOverviewAccountIdProvider);
  final catId = ref.watch(selectedOverviewCategoryIdProvider);

  return transactions.where((t) {
    final matchAcc = accId == null || t.accountId == accId;
    final matchCat = catId == null || t.categoryId == catId;
    return matchAcc && matchCat;
  }).toList();
});

/// Map of categoryId -> total amount
final monthlyCategoryTotalsProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(filteredMonthlyTransactionsProvider);
  final totals = <String, double>{};

  for (final tx in transactions) {
    if (tx.type == TransactionType.expense) {
      totals[tx.categoryId] = (totals[tx.categoryId] ?? 0.0) + tx.amount;
    }
  }
  return totals;
});

/// Map of accountId -> total amount
final monthlyAccountTotalsProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(filteredMonthlyTransactionsProvider);
  final totals = <String, double>{};

  for (final tx in transactions) {
    if (tx.type == TransactionType.expense) {
      totals[tx.accountId] = (totals[tx.accountId] ?? 0.0) + tx.amount;
    }
  }
  return totals;
});
