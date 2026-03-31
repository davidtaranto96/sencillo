import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../core/models/parsed_transaction.dart';
import 'package:uuid/uuid.dart';

class AccountService {
  final AppDatabase db;

  AccountService(this.db);

  /// Pays a credit card statement using funds from another account.
  Future<void> payCardStatement({
    required String sourceAccountId,
    required String cardAccountId,
    required double amount,
  }) async {
    await db.transaction(() async {
      // 1. Get current balances
      final source = await (db.select(db.accountsTable)..where((t) => t.id.equals(sourceAccountId))).getSingle();
      final card = await (db.select(db.accountsTable)..where((t) => t.id.equals(cardAccountId))).getSingle();

      // 2. Update source account (debit)
      await (db.update(db.accountsTable)..where((t) => t.id.equals(sourceAccountId))).write(
        AccountsTableCompanion(
          initialBalance: drift.Value(source.initialBalance - amount),
        ),
      );

      // 3. Update card account (reduce pending debt)
      await (db.update(db.accountsTable)..where((t) => t.id.equals(cardAccountId))).write(
        AccountsTableCompanion(
          pendingStatementAmount: drift.Value(card.pendingStatementAmount - amount),
        ),
      );

      // 4. Record the transaction
      await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
        id: const Uuid().v4(),
        title: 'Pago Tarjeta: ${card.name}',
        amount: amount,
        type: 'transfer',
        categoryId: 'cat_financial',
        accountId: sourceAccountId,
        date: DateTime.now(),
        note: const drift.Value('Pago manual de resumen'),
      ));
    });
  }

  /// Importa en lote las transacciones parseadas del PDF a la DB y actualiza
  /// el [pendingStatementAmount] de la tarjeta correspondiente.
  Future<ImportResult> importStatementTransactions({
    required String cardAccountId,
    required List<ParsedTransaction> transactions,
  }) async {
    final selected = transactions.where((t) => t.isSelected).toList();
    if (selected.isEmpty) {
      final card = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals(cardAccountId)))
          .getSingle();
      return ImportResult(imported: 0, total: transactions.length, cardName: card.name);
    }

    late String cardName;

    await db.transaction(() async {
      final card = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals(cardAccountId)))
          .getSingle();
      cardName = card.name;

      // Insertar cada transacción seleccionada
      for (final tx in selected) {
        final note = tx.isInstallment ? tx.installmentLabel : null;
        await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
          id: const Uuid().v4(),
          title: tx.description,
          amount: tx.amount,
          type: 'expense',
          categoryId: tx.suggestedCategoryId,
          accountId: cardAccountId,
          date: tx.date,
          note: drift.Value(note),
        ));
      }

      // Actualizar pendingStatementAmount con el total importado
      final total = selected.fold(0.0, (sum, t) => sum + t.amount);
      await (db.update(db.accountsTable)
          ..where((t) => t.id.equals(cardAccountId)))
          .write(AccountsTableCompanion(
        pendingStatementAmount: drift.Value(card.pendingStatementAmount + total),
      ));
    });

    return ImportResult(
      imported: selected.length,
      total: transactions.length,
      cardName: cardName,
    );
  }

  /// Adds a new account to the database.
  Future<void> addAccount({
    required String name,
    required String type,
    required String currencyCode,
    double initialBalance = 0,
    String? iconName,
    int? colorValue,
  }) async {
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: const Uuid().v4(),
      name: name,
      type: type,
      currencyCode: drift.Value(currencyCode),
      initialBalance: drift.Value(initialBalance),
      iconName: drift.Value(iconName),
      colorValue: drift.Value(colorValue),
    ));
  }

  /// Updates an existing account.
  Future<void> updateAccount({
    required String id,
    String? name,
    String? type,
    String? currencyCode,
    double? initialBalance,
  }) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id))).write(
      AccountsTableCompanion(
        name: name != null ? drift.Value(name) : const drift.Value.absent(),
        type: type != null ? drift.Value(type) : const drift.Value.absent(),
        currencyCode: currencyCode != null ? drift.Value(currencyCode) : const drift.Value.absent(),
        initialBalance: initialBalance != null ? drift.Value(initialBalance) : const drift.Value.absent(),
      ),
    );
  }

  /// Deletes an account and its transactions.
  Future<void> deleteAccount(String id) async {
    await db.transaction(() async {
      // 1. Delete transactions
      await (db.delete(db.transactionsTable)..where((t) => t.accountId.equals(id))).go();
      // 2. Delete account
      await (db.delete(db.accountsTable)..where((t) => t.id.equals(id))).go();
    });
  }
}

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(ref.watch(databaseProvider));
});
