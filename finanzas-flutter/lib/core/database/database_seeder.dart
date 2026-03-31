import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import '../../features/transactions/domain/models/transaction.dart' as t;
import 'app_database.dart';

class DatabaseSeeder {
  final AppDatabase db;
  DatabaseSeeder(this.db);

  Future<void> clearAndSeedMockData() async {
    // 1. Borrar Todo
    await db.delete(db.transactionsTable).go();
    await db.delete(db.accountsTable).go();
    await db.delete(db.categoriesTable).go();
    await db.delete(db.personsTable).go();
    await db.delete(db.groupsTable).go();
    await db.delete(db.budgetsTable).go();
    await db.delete(db.goalsTable).go();

    // 2. Insertar Cuentas Reales
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'mp_ars',
      name: 'Mercado Pago',
      type: 'bank',
      currencyCode: const Value('ARS'),
      iconName: const Value('account_balance_wallet'),
      colorValue: const Value(0xFF00B1EA),
      initialBalance: const Value(692932.13),
      isDefault: const Value(true),
    ));

    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'ap_usd',
      name: 'AstroPay',
      type: 'bank',
      currencyCode: const Value('USD'),
      iconName: const Value('payments'),
      colorValue: const Value(0xFF7C6EF7),
      initialBalance: const Value(2101.12),
    ));

    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'mc_credit',
      name: 'Mastercard',
      type: 'credit',
      currencyCode: const Value('ARS'),
      iconName: const Value('credit_card'),
      colorValue: const Value(0xFFFF5C6E),
      initialBalance: const Value(79987.00), // Lo que se debe hoy
      closingDay: const Value(26),
      dueDay: const Value(8),
    ));

    // 3. Insertar Personas Reales
    await db.into(db.personsTable).insert(PersonsTableCompanion.insert(
      id: 'p_sofi',
      name: 'Sofía Taranto',
      alias: const Value('Sovi'),
      colorValue: const Value(0xFFE91E63),
      totalBalance: const Value(27944.33), // Te debe
    ));

    await db.into(db.personsTable).insert(PersonsTableCompanion.insert(
      id: 'p_juan',
      name: 'Juan Taranto',
      alias: const Value('Juancito'),
      colorValue: const Value(0xFF2196F3),
      totalBalance: const Value(141380.67), // Te debe
    ));

    // 4. Insertar Transacciones (Ejemplos)
    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: 'tx1',
      title: 'Sueldo Febrero',
      amount: 950000,
      type: t.TransactionType.income.name,
      categoryId: 'cat_salary',
      accountId: 'a2',
      date: DateTime.now().subtract(const Duration(days: 3)),
    ));

    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: 'tx2',
      title: 'Supermercado Coto',
      amount: 85000,
      type: t.TransactionType.expense.name,
      categoryId: 'cat_super',
      accountId: 'a2',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ));

    // Compartido
    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: 'tx3',
      title: 'Sushi con Juan y Sofi',
      amount: 45000,
      type: t.TransactionType.expense.name,
      categoryId: 'cat_food',
      accountId: 'a1',
      date: DateTime.now(),
      isShared: const Value(true),
      sharedTotalAmount: const Value(45000),
      sharedOwnAmount: const Value(15000),
      sharedOtherAmount: const Value(30000),
      sharedRecovered: const Value(0),
    ));
  }
}
