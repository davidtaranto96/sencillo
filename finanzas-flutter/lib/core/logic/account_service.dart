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
      // 1. Get card to update pending debt
      final card = await (db.select(db.accountsTable)..where((t) => t.id.equals(cardAccountId))).getSingle();

      // 2. Update card account (reduce pending debt)
      await (db.update(db.accountsTable)..where((t) => t.id.equals(cardAccountId))).write(
        AccountsTableCompanion(
          pendingStatementAmount: drift.Value(card.pendingStatementAmount - amount),
        ),
      );

      // 3. Record the transfer transaction
      // Note: accountsStreamProvider already subtracts 'transfer' txs from source balance,
      // so we do NOT modify initialBalance on the source account.
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
      final card = await (db.select(db.accountsTable)..where((t) => t.id.equals(cardAccountId))).getSingle();

      // Restore card pending debt
      await (db.update(db.accountsTable)..where((t) => t.id.equals(cardAccountId))).write(
        AccountsTableCompanion(
          pendingStatementAmount: drift.Value(card.pendingStatementAmount + amount),
        ),
      );

      // Delete the transfer transaction — this automatically restores
      // the source account balance since accountsStreamProvider recalculates
      // balance from initialBalance + transactions.
      await (db.delete(db.transactionsTable)..where((t) => t.id.equals(transactionId))).go();
    });
  }

  /// Importa en lote las transacciones parseadas del PDF a la DB y actualiza
  /// el [pendingStatementAmount] de la tarjeta correspondiente.
  Future<ImportResult> importStatementTransactions({
    required String cardAccountId,
    required List<ParsedTransaction> transactions,
    String? fileName,
    String? cardFormat,
  }) async {
    final selected = transactions.where((t) => t.isSelected).toList();
    if (selected.isEmpty) {
      final card = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals(cardAccountId)))
          .getSingle();
      return ImportResult(imported: 0, total: transactions.length, cardName: card.name);
    }

    late String cardName;
    final txIds = <String>[];

    await db.transaction(() async {
      final card = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals(cardAccountId)))
          .getSingle();
      cardName = card.name;

      // Insertar cada transacción seleccionada
      for (final tx in selected) {
        final txId = const Uuid().v4();
        txIds.add(txId);
        final note = tx.isInstallment ? tx.installmentLabel : null;
        await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
          id: txId,
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
      transactionIds: txIds,
    );
  }

  /// Deshace una importación completa eliminando todas las transacciones del lote
  /// y actualizando el pendingStatementAmount de la tarjeta.
  Future<void> undoImportBatch({
    required String cardAccountId,
    required List<String> transactionIds,
  }) async {
    if (transactionIds.isEmpty) return;

    await db.transaction(() async {
      // Obtener montos de las transacciones a eliminar
      final txRows = await (db.select(db.transactionsTable)
            ..where((t) => t.id.isIn(transactionIds)))
          .get();
      final totalAmount = txRows.fold(0.0, (sum, t) => sum + t.amount);

      // Eliminar transacciones
      await (db.delete(db.transactionsTable)
            ..where((t) => t.id.isIn(transactionIds)))
          .go();

      // Actualizar pendingStatementAmount
      final card = await (db.select(db.accountsTable)
            ..where((t) => t.id.equals(cardAccountId)))
          .getSingle();
      final newPending = (card.pendingStatementAmount - totalAmount).clamp(0.0, double.infinity);
      await (db.update(db.accountsTable)
            ..where((t) => t.id.equals(cardAccountId)))
          .write(AccountsTableCompanion(
        pendingStatementAmount: drift.Value(newPending),
      ));
    });
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
    // Only insert the transaction — accountsStreamProvider recalculates
    // balance from initialBalance + all transactions automatically.
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

