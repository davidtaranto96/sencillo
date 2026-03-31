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

    // 2. Insertar Cuentas
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'a1',
      name: 'Efectivo',
      iconName: 'wallet',
      colorValue: Colors.green.value,
      initialBalance: const Value(25000),
    ));

    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'a2',
      name: 'Galicia',
      iconName: 'account_balance',
      colorValue: Colors.orange.value,
      initialBalance: const Value(810000),
    ));

    // 3. Insertar Personas
    await db.into(db.personsTable).insert(PersonsTableCompanion.insert(
      id: 'p1',
      name: 'Sofía',
      alias: const Value('Sofi'),
      colorValue: Colors.pinkAccent.value,
      totalBalance: const Value(45000), // Me debe
    ));
    await db.into(db.personsTable).insert(PersonsTableCompanion.insert(
      id: 'p2',
      name: 'Juan Perez',
      alias: const Value('Juancito'),
      colorValue: Colors.blueAccent.value,
      totalBalance: const Value(-15000), // Le debo
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
