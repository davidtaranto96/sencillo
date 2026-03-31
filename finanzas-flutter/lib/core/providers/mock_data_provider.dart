import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/transactions/domain/models/transaction.dart';
import '../../features/accounts/domain/models/account.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────────────
// Mock de cuentas
// ─────────────────────────────────────────────────────
final mockAccountsProvider = Provider<List<Account>>((ref) {
  return [
    Account(
      id: 'acc_1',
      name: 'Cuenta Banco Nación',
      type: AccountType.bank,
      balance: 450000,
      isDefault: true,
      color: '#7C6EF7',
    ),
    Account(
      id: 'acc_2',
      name: 'Visa Galicia',
      type: AccountType.credit,
      balance: 85000,
      creditLimit: 500000,
      closingDay: 5,
      dueDay: 15,
      color: '#FFB347',
    ),
    Account(
      id: 'acc_3',
      name: 'Efectivo',
      type: AccountType.cash,
      balance: 25000,
      color: '#5ECFB1',
    ),
  ];
});

// ─────────────────────────────────────────────────────
// Mock de transacciones recientes
// ─────────────────────────────────────────────────────
final mockTransactionsProvider = Provider<List<Transaction>>((ref) {
  final now = DateTime.now();
  return [
    Transaction(
      id: _uuid.v4(),
      title: 'Sueldo marzo',
      amount: 850000,
      type: TransactionType.income,
      categoryId: 'salary',
      accountId: 'acc_1',
      date: now.subtract(const Duration(days: 1)),
    ),
    Transaction(
      id: _uuid.v4(),
      title: 'Sushi con Juan y Sofi',
      amount: 60000,
      type: TransactionType.expense,
      categoryId: 'food',
      accountId: 'acc_2',
      date: now.subtract(const Duration(days: 2)),
      isShared: true,
      sharedTotalAmount: 60000,
      sharedOwnAmount: 20000,
      sharedOtherAmount: 40000,
      sharedRecovered: 0,
      personId: 'person_juan',
    ),
    Transaction(
      id: _uuid.v4(),
      title: 'Netflix',
      amount: 4500,
      type: TransactionType.expense,
      categoryId: 'entertainment',
      accountId: 'acc_2',
      date: now.subtract(const Duration(days: 3)),
    ),
    Transaction(
      id: _uuid.v4(),
      title: 'Supermercado',
      amount: 35000,
      type: TransactionType.expense,
      categoryId: 'food',
      accountId: 'acc_1',
      date: now.subtract(const Duration(days: 3)),
    ),
    Transaction(
      id: _uuid.v4(),
      title: 'OSDE',
      amount: 28000,
      type: TransactionType.expense,
      categoryId: 'health',
      accountId: 'acc_1',
      date: now.subtract(const Duration(days: 4)),
    ),
    Transaction(
      id: _uuid.v4(),
      title: 'Freelance diseño',
      amount: 120000,
      type: TransactionType.income,
      categoryId: 'freelance',
      accountId: 'acc_1',
      date: now.subtract(const Duration(days: 5)),
    ),
    Transaction(
      id: _uuid.v4(),
      title: 'Nafta',
      amount: 18000,
      type: TransactionType.expense,
      categoryId: 'transport',
      accountId: 'acc_1',
      date: now.subtract(const Duration(days: 6)),
    ),
    Transaction(
      id: _uuid.v4(),
      title: 'Cena con amigos (Lolla)',
      amount: 90000,
      type: TransactionType.expense,
      categoryId: 'food',
      accountId: 'acc_2',
      date: now.subtract(const Duration(days: 7)),
      isShared: true,
      sharedTotalAmount: 90000,
      sharedOwnAmount: 30000,
      sharedOtherAmount: 60000,
      sharedRecovered: 30000,
      groupId: 'group_lolla',
    ),
  ];
});

// ─────────────────────────────────────────────────────
// Balance del mes
// ─────────────────────────────────────────────────────
final monthlyBalanceProvider = Provider<MonthlyBalance>((ref) {
  final txs = ref.watch(mockTransactionsProvider);
  final now = DateTime.now();
  final monthTxs = txs.where(
    (t) => t.date.month == now.month && t.date.year == now.year,
  );

  final income = monthTxs
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  final expense = monthTxs
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.realExpense);

  final pending = monthTxs
      .where((t) => t.isShared)
      .fold(0.0, (sum, t) => sum + t.pendingToRecover);

  return MonthlyBalance(
    income: income,
    expense: expense,
    pendingToRecover: pending,
  );
});

class MonthlyBalance {
  final double income;
  final double expense;
  final double pendingToRecover;

  const MonthlyBalance({
    required this.income,
    required this.expense,
    required this.pendingToRecover,
  });

  double get balance => income - expense;
  double get savings => income > 0 ? (income - expense) / income : 0;
}
