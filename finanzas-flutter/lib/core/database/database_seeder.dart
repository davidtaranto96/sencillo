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

    // Mastercard 1.5M (Resumen Mar)
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'mc_credit',
      name: 'Mastercard Black',
      type: 'credit',
      currencyCode: const Value('ARS'),
      iconName: const Value('credit_card'),
      colorValue: const Value(0xFF7C6EF7),
      initialBalance: const Value(1522588.00), 
      closingDay: const Value(26),
      dueDay: const Value(8),
    ));

    // Visa 511k (Resumen Abr)
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: 'visa_credit',
      name: 'Visa Signature',
      type: 'credit',
      currencyCode: const Value('ARS'),
      iconName: const Value('credit_card'),
      colorValue: const Value(0xFFFF5C6E),
      initialBalance: const Value(511659.00),
      closingDay: const Value(20),
      dueDay: const Value(3),
    ));

    // 3. Insertar Personas Reales
    await db.into(db.personsTable).insert(PersonsTableCompanion.insert(
      id: 'p_sofi',
      name: 'Sofía Taranto',
      alias: const Value('Sovi'),
      colorValue: const Value(0xFFE91E63),
      totalBalance: const Value(27944.33),
    ));

    await db.into(db.personsTable).insert(PersonsTableCompanion.insert(
      id: 'p_juan',
      name: 'Juan Taranto',
      alias: const Value('Juancito'),
      colorValue: const Value(0xFF2196F3),
      totalBalance: const Value(141380.67),
    ));

    // 4. Detalle de Gastos (Extraídos de PDF)
    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: 'tx_pdf_1',
      title: 'Restaurante Sushi',
      amount: 45000,
      type: t.TransactionType.expense.name,
      categoryId: 'cat_food',
      accountId: 'visa_credit',
      date: DateTime(2026, 3, 15),
    ));
    
    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: 'tx_pdf_2',
      title: 'Supermercado Coto 02/03',
      amount: 85200,
      type: t.TransactionType.expense.name,
      categoryId: 'cat_super',
      accountId: 'mc_credit',
      date: DateTime(2026, 3, 10),
    ));

    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: 'tx_pdf_3',
      title: 'Pago Tarjeta Mastercard',
      amount: 79987,
      type: t.TransactionType.expense.name,
      categoryId: 'cat_financial',
      accountId: 'mp_ars',
      date: DateTime(2026, 4, 8),
    ));
  }
}
