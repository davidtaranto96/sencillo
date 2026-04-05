import 'package:drift/drift.dart';
import '../../features/transactions/domain/models/transaction.dart' as t;
import 'app_database.dart';

class DatabaseSeeder {
  final AppDatabase db;
  DatabaseSeeder(this.db);

  Future<void> clearAndSeedMockData() async {
    // 1. Clear all tables
    await db.delete(db.transactionsTable).go();
    await db.delete(db.accountsTable).go();
    await db.delete(db.categoriesTable).go();
    await db.delete(db.personsTable).go();
    await db.delete(db.groupsTable).go();
    await db.delete(db.groupMembersTable).go();
    await db.delete(db.budgetsTable).go();
    await db.delete(db.goalsTable).go();
    await db.delete(db.wishlistTable).go();
    await db.delete(db.userProfileTable).go();

    // 2. User Profile
    await db.into(db.userProfileTable).insert(UserProfileTableCompanion.insert(
      id: 'user_profile_singleton',
      name: const Value('David'),
      monthlySalary: const Value(850000),
      payDay: const Value(5),
    ));

    // 3. Categories
    final categories = <(String, String, String, int, bool)>[
      ('food', 'Comida', 'restaurant', 0xFFFF8A65, false),
      ('transport', 'Transporte', 'directions_car', 0xFF4FC3F7, false),
      ('health', 'Salud', 'favorite', 0xFFEF5350, false),
      ('entertainment', 'Entretenimiento', 'movie', 0xFFBA68C8, false),
      ('shopping', 'Compras', 'shopping_bag', 0xFFFFD54F, false),
      ('home', 'Hogar', 'home', 0xFF81C784, true),
      ('education', 'Educación', 'school', 0xFF7986CB, false),
      ('services', 'Servicios', 'build', 0xFFFFB74D, true),
      ('salary', 'Sueldo', 'payments', 0xFF66BB6A, false),
      ('freelance', 'Freelance', 'computer', 0xFF4DB6AC, false),
      ('other_expense', 'Otro gasto', 'receipt', 0xFF90A4AE, false),
      ('other_income', 'Otro ingreso', 'attach_money', 0xFF66BB6A, false),
    ];
    for (final c in categories) {
      await db.into(db.categoriesTable).insert(CategoriesTableCompanion.insert(
        id: c.$1,
        name: c.$2,
        iconName: c.$3,
        colorValue: c.$4,
        isFixed: Value(c.$5),
      ));
    }

    // 4. Accounts
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'mp_ars',
      name: 'Mercado Pago',
      type: 'bank',
      currencyCode: const Value('ARS'),
      iconName: const Value('account_balance_wallet'),
      colorValue: const Value(0xFF00B1EA),
      initialBalance: const Value(692932),
      isDefault: const Value(true),
    ));
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'ap_usd',
      name: 'AstroPay',
      type: 'bank',
      currencyCode: const Value('USD'),
      iconName: const Value('payments'),
      colorValue: const Value(0xFF7C6EF7),
      initialBalance: const Value(0),
    ));
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'mc_credit',
      name: 'Mastercard Black',
      type: 'credit',
      currencyCode: const Value('ARS'),
      iconName: const Value('credit_card'),
      colorValue: const Value(0xFF7C6EF7),
      initialBalance: const Value(0),
      pendingStatementAmount: const Value(1522588),
      closingDay: const Value(26),
      dueDay: const Value(8),
    ));
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'visa_credit',
      name: 'Visa Signature',
      type: 'credit',
      currencyCode: const Value('ARS'),
      iconName: const Value('credit_card'),
      colorValue: const Value(0xFFFF5C6E),
      initialBalance: const Value(0),
      pendingStatementAmount: const Value(511659),
      closingDay: const Value(20),
      dueDay: const Value(3),
    ));
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'cash_ars',
      name: 'Efectivo',
      type: 'cash',
      currencyCode: const Value('ARS'),
      iconName: const Value('payments'),
      colorValue: const Value(0xFF81C784),
      initialBalance: const Value(50000),
    ));

    // 5. Persons
    await db.into(db.personsTable).insert(PersonsTableCompanion.insert(
      id: 'p_sofi',
      name: 'Sofía',
      alias: const Value('Sovi'),
      colorValue: 0xFFE91E63,
      totalBalance: const Value(27944),
    ));
    await db.into(db.personsTable).insert(PersonsTableCompanion.insert(
      id: 'p_juan',
      name: 'Juan',
      alias: const Value('Juancito'),
      colorValue: 0xFF2196F3,
      totalBalance: const Value(14138),
    ));

    // 6. Groups
    await db.into(db.groupsTable).insert(GroupsTableCompanion.insert(
      id: 'grp_viaje',
      name: 'Viaje a Córdoba',
      totalGroupExpense: const Value(85000),
      startDate: Value(DateTime(2026, 3, 1)),
      endDate: Value(DateTime(2026, 3, 5)),
    ));
    await db.into(db.groupMembersTable).insert(
        GroupMembersTableCompanion.insert(
            groupId: 'grp_viaje', personId: 'p_sofi'));
    await db.into(db.groupMembersTable).insert(
        GroupMembersTableCompanion.insert(
            groupId: 'grp_viaje', personId: 'p_juan'));

    // 7. Budgets
    await db.into(db.budgetsTable).insert(BudgetsTableCompanion.insert(
      id: 'bud_food',
      categoryId: 'food',
      limitAmount: 200000,
    ));
    await db.into(db.budgetsTable).insert(BudgetsTableCompanion.insert(
      id: 'bud_transport',
      categoryId: 'transport',
      limitAmount: 80000,
    ));
    await db.into(db.budgetsTable).insert(BudgetsTableCompanion.insert(
      id: 'bud_entertainment',
      categoryId: 'entertainment',
      limitAmount: 100000,
    ));
    await db.into(db.budgetsTable).insert(BudgetsTableCompanion.insert(
      id: 'bud_shopping',
      categoryId: 'shopping',
      limitAmount: 150000,
    ));
    await db.into(db.budgetsTable).insert(BudgetsTableCompanion.insert(
      id: 'bud_services',
      categoryId: 'services',
      limitAmount: 120000,
    ));

    // 8. Goals
    await db.into(db.goalsTable).insert(GoalsTableCompanion.insert(
      id: 'goal_emergency',
      name: 'Fondo de emergencia',
      targetAmount: 2000000,
      currentAmount: const Value(450000),
      iconName: const Value('shield'),
      colorValue: 0xFF66BB6A,
      deadline: Value(DateTime(2026, 12, 31)),
    ));
    await db.into(db.goalsTable).insert(GoalsTableCompanion.insert(
      id: 'goal_vacation',
      name: 'Vacaciones 2027',
      targetAmount: 1500000,
      currentAmount: const Value(120000),
      iconName: const Value('flight'),
      colorValue: 0xFF4FC3F7,
      deadline: Value(DateTime(2027, 1, 15)),
    ));

    // 9. Wishlist
    await db.into(db.wishlistTable).insert(WishlistTableCompanion.insert(
      id: 'wish_kindle',
      title: 'Kindle Paperwhite',
      estimatedCost: 244000,
      createdAt: DateTime(2026, 3, 20),
      url: const Value('https://mercadolibre.com.ar'),
      installments: const Value(6),
      note: const Value('La versión 2024 con pantalla más grande'),
    ));
    await db.into(db.wishlistTable).insert(WishlistTableCompanion.insert(
      id: 'wish_monitor',
      title: 'Monitor LG 27"',
      estimatedCost: 380000,
      createdAt: DateTime(2026, 3, 15),
      installments: const Value(12),
      note: const Value('Para trabajar más cómodo'),
    ));

    // 10. Transactions — spread across March and April for historical data
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);

    // Salary
    await _tx('salary_mar', 'Sueldo Marzo', 850000, t.TransactionType.income,
        'salary', 'mp_ars', DateTime(lastMonth.year, lastMonth.month, 5));
    await _tx('salary_apr', 'Sueldo Abril', 850000, t.TransactionType.income,
        'salary', 'mp_ars', DateTime(thisMonth.year, thisMonth.month, 5));

    // Freelance
    await _tx('freelance_mar', 'Proyecto freelance', 120000,
        t.TransactionType.income, 'freelance', 'mp_ars',
        DateTime(lastMonth.year, lastMonth.month, 15));

    // March expenses
    await _tx('tx_m1', 'Supermercado Coto', 85200, t.TransactionType.expense,
        'food', 'mc_credit', DateTime(lastMonth.year, lastMonth.month, 10));
    await _tx('tx_m2', 'Restaurante Sushi', 45000, t.TransactionType.expense,
        'food', 'visa_credit', DateTime(lastMonth.year, lastMonth.month, 15));
    await _tx('tx_m3', 'Nafta', 35000, t.TransactionType.expense,
        'transport', 'mp_ars', DateTime(lastMonth.year, lastMonth.month, 8));
    await _tx('tx_m4', 'Netflix + Spotify', 12000, t.TransactionType.expense,
        'services', 'mc_credit', DateTime(lastMonth.year, lastMonth.month, 1));
    await _tx('tx_m5', 'Farmacia', 18500, t.TransactionType.expense,
        'health', 'mp_ars', DateTime(lastMonth.year, lastMonth.month, 20));
    await _tx('tx_m6', 'Cine', 15000, t.TransactionType.expense,
        'entertainment', 'mp_ars', DateTime(lastMonth.year, lastMonth.month, 22));
    await _tx('tx_m7', 'Ropa', 67000, t.TransactionType.expense,
        'shopping', 'visa_credit', DateTime(lastMonth.year, lastMonth.month, 18));
    await _tx('tx_m8', 'Internet Fibertel', 28000, t.TransactionType.expense,
        'services', 'mp_ars', DateTime(lastMonth.year, lastMonth.month, 5));
    await _tx('tx_m9', 'Curso Udemy', 22000, t.TransactionType.expense,
        'education', 'mc_credit', DateTime(lastMonth.year, lastMonth.month, 12));

    // April expenses (current month)
    await _tx('tx_a1', 'Carrefour', 52000, t.TransactionType.expense,
        'food', 'mp_ars', DateTime(thisMonth.year, thisMonth.month, 2));
    await _tx('tx_a2', 'Uber', 8500, t.TransactionType.expense,
        'transport', 'mp_ars', DateTime(thisMonth.year, thisMonth.month, 1));
    await _tx('tx_a3', 'Almuerzo trabajo', 12000, t.TransactionType.expense,
        'food', 'cash_ars', DateTime(thisMonth.year, thisMonth.month, 3));
    await _tx('tx_a4', 'Pago resumen MC', 79987, t.TransactionType.expense,
        'other_expense', 'mp_ars', DateTime(thisMonth.year, thisMonth.month, 4));

    // Shared expense
    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: 'tx_shared1',
      title: 'Cena compartida con Sofi',
      amount: 34000,
      type: t.TransactionType.expense.name,
      categoryId: 'food',
      accountId: 'mp_ars',
      date: DateTime(thisMonth.year, thisMonth.month, 3),
      personId: const Value('p_sofi'),
      isShared: const Value(true),
      sharedTotalAmount: const Value(34000),
      sharedOwnAmount: const Value(17000),
      sharedOtherAmount: const Value(17000),
      sharedRecovered: const Value(0),
    ));

    // Loan
    await _tx('tx_loan1', 'Préstamo a Juan', 15000,
        t.TransactionType.loanGiven, 'other_expense', 'mp_ars',
        DateTime(thisMonth.year, thisMonth.month, 2),
        personId: 'p_juan');
  }

  Future<void> _tx(String id, String title, double amount,
      t.TransactionType type, String categoryId, String accountId,
      DateTime date, {String? personId}) async {
    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: id,
      title: title,
      amount: amount,
      type: type.name,
      categoryId: categoryId,
      accountId: accountId,
      date: date,
      personId: personId != null ? Value(personId) : const Value.absent(),
    ));
  }
}
