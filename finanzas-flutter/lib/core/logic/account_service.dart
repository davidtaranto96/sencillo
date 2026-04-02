import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../core/models/parsed_transaction.dart';
export '../../core/models/parsed_transaction.dart' show ImportResult;
import 'package:uuid/uuid.dart';

class AccountService {
  final AppDatabase db;

  AccountService(this.db);

  /// Pays a credit card statement using funds from another account.
  /// Returns the transaction ID for undo support.
  Future<String> payCardStatement({
    required String sourceAccountId,
    required String cardAccountId,
    required double amount,
  }) async {
    final txId = const Uuid().v4();
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
        id: txId,
        title: 'Pago Tarjeta: ${card.name}',
        amount: amount,
        type: 'transfer',
        categoryId: 'cat_financial',
        accountId: sourceAccountId,
        date: DateTime.now(),
        note: const drift.Value('Pago manual de resumen'),
      ));
    });
    return txId;
  }

  /// Undoes a credit card payment by restoring balances and deleting the transaction.
  Future<void> undoPayCardStatement({
    required String sourceAccountId,
    required String cardAccountId,
    required double amount,
    required String transactionId,
  }) async {
    await db.transaction(() async {
      final source = await (db.select(db.accountsTable)..where((t) => t.id.equals(sourceAccountId))).getSingle();
      final card = await (db.select(db.accountsTable)..where((t) => t.id.equals(cardAccountId))).getSingle();

      // Restore source balance
      await (db.update(db.accountsTable)..where((t) => t.id.equals(sourceAccountId))).write(
        AccountsTableCompanion(
          initialBalance: drift.Value(source.initialBalance + amount),
        ),
      );

      // Restore card pending debt
      await (db.update(db.accountsTable)..where((t) => t.id.equals(cardAccountId))).write(
        AccountsTableCompanion(
          pendingStatementAmount: drift.Value(card.pendingStatementAmount + amount),
        ),
      );

      // Delete the transfer transaction
      await (db.delete(db.transactionsTable)..where((t) => t.id.equals(transactionId))).go();
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
    int? closingDay,
    int? dueDay,
    double? creditLimit,
    double pendingStatementAmount = 0,
    String? alias,
    String? cvu,
  }) async {
    await db.into(db.accountsTable).insert(AccountsTableCompanion.insert(
      id: const Uuid().v4(),
      name: name,
      type: type,
      currencyCode: drift.Value(currencyCode),
      initialBalance: drift.Value(initialBalance),
      iconName: drift.Value(iconName),
      colorValue: drift.Value(colorValue),
      closingDay: drift.Value(closingDay),
      dueDay: drift.Value(dueDay),
      creditLimit: drift.Value(creditLimit),
      pendingStatementAmount: drift.Value(pendingStatementAmount),
      alias: drift.Value(alias),
      cvu: drift.Value(cvu),
    ));
  }

  /// Updates an existing account.
  Future<void> updateAccount({
    required String id,
    String? name,
    String? type,
    String? currencyCode,
    double? initialBalance,
    String? iconName,
    int? colorValue,
    int? closingDay,
    int? dueDay,
    bool clearClosingDay = false,
    bool clearDueDay = false,
    double? creditLimit,
    bool clearCreditLimit = false,
    double? pendingStatementAmount,
    String? alias,
    bool clearAlias = false,
    String? cvu,
    bool clearCvu = false,
  }) async {
    await (db.update(db.accountsTable)..where((t) => t.id.equals(id))).write(
      AccountsTableCompanion(
        name: name != null ? drift.Value(name) : const drift.Value.absent(),
        type: type != null ? drift.Value(type) : const drift.Value.absent(),
        currencyCode: currencyCode != null ? drift.Value(currencyCode) : const drift.Value.absent(),
        initialBalance: initialBalance != null ? drift.Value(initialBalance) : const drift.Value.absent(),
        iconName: iconName != null ? drift.Value(iconName) : const drift.Value.absent(),
        colorValue: colorValue != null ? drift.Value(colorValue) : const drift.Value.absent(),
        closingDay: clearClosingDay ? const drift.Value(null) : (closingDay != null ? drift.Value(closingDay) : const drift.Value.absent()),
        dueDay: clearDueDay ? const drift.Value(null) : (dueDay != null ? drift.Value(dueDay) : const drift.Value.absent()),
        creditLimit: clearCreditLimit ? const drift.Value(null) : (creditLimit != null ? drift.Value(creditLimit) : const drift.Value.absent()),
        pendingStatementAmount: pendingStatementAmount != null ? drift.Value(pendingStatementAmount) : const drift.Value.absent(),
        alias: clearAlias ? const drift.Value(null) : (alias != null ? drift.Value(alias) : const drift.Value.absent()),
        cvu: clearCvu ? const drift.Value(null) : (cvu != null ? drift.Value(cvu) : const drift.Value.absent()),
      ),
    );
  }

  /// Adds a manual transaction (deposit or withdrawal) to an account.
  /// Returns the transaction ID for undo support.
  Future<String> addManualTransaction({
    required String accountId,
    required String title,
    required double amount,
    required String type, // 'income' or 'expense'
  }) async {
    final txId = const Uuid().v4();
    await db.transaction(() async {
      await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
        id: txId,
        title: title,
        amount: amount,
        type: type,
        categoryId: type == 'income' ? 'cat_income' : 'cat_other',
        accountId: accountId,
        date: DateTime.now(),
        note: const drift.Value('Movimiento manual'),
      ));

      // Update account balance
      final account = await (db.select(db.accountsTable)..where((t) => t.id.equals(accountId))).getSingle();
      double newBalance = account.initialBalance;
      if (type == 'expense') {
        newBalance -= amount;
      } else if (type == 'income') {
        newBalance += amount;
      }
      await (db.update(db.accountsTable)..where((t) => t.id.equals(accountId))).write(
        AccountsTableCompanion(initialBalance: drift.Value(newBalance)),
      );
    });
    return txId;
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

