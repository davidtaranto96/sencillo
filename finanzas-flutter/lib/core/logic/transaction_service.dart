import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import 'package:uuid/uuid.dart';

class TransactionService {
  final AppDatabase db;

  TransactionService(this.db);

  /// Adds a new transaction.
  /// Balance is recalculated automatically by accountsStreamProvider
  /// from initialBalance + all transactions — no need to touch initialBalance here.
  Future<void> addTransaction({
    required String title,
    required double amount,
    required String type, // 'income' or 'expense'
    required String categoryId,
    required String accountId,
    DateTime? date,
    String? note,
  }) async {
    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      date: date ?? DateTime.now(),
      note: drift.Value(note),
    ));
  }

  /// Updates any field of an existing transaction.
  /// Handles balance adjustments when amount, type, or account changes.
  Future<void> updateTransaction({
    required String id,
    String? title,
    double? amount,
    String? type,
    String? categoryId,
    String? accountId,
    DateTime? date,
    String? note,
    bool clearNote = false,
  }) async {
    // Just update the transaction row — accountsStreamProvider recalculates
    // balance automatically from initialBalance + all transactions.
    await (db.update(db.transactionsTable)..where((t) => t.id.equals(id))).write(
      TransactionsTableCompanion(
        title: title != null ? drift.Value(title) : const drift.Value.absent(),
        amount: amount != null ? drift.Value(amount) : const drift.Value.absent(),
        type: type != null ? drift.Value(type) : const drift.Value.absent(),
        categoryId: categoryId != null ? drift.Value(categoryId) : const drift.Value.absent(),
        accountId: accountId != null ? drift.Value(accountId) : const drift.Value.absent(),
        date: date != null ? drift.Value(date) : const drift.Value.absent(),
        note: clearNote ? const drift.Value(null) : (note != null ? drift.Value(note) : const drift.Value.absent()),
      ),
    );
  }

  /// Deletes a transaction. Balance recalculates automatically.
  Future<void> deleteTransaction(String id) async {
    await db.transaction(() async {
      await (db.delete(db.transactionsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Adds a retroactive transaction to a past month.
  /// This does NOT modify the account balance — the transaction is tagged
  /// with [retroactivo] in the note so it's excluded from balance calculations
  /// but still appears in monthly overviews.
  Future<void> addRetroactiveTransaction({
    required String title,
    required double amount,
    required String type,
    required String categoryId,
    required String accountId,
    required DateTime date,
    String? note,
  }) async {
    final retroNote = note != null && note.isNotEmpty
        ? '$note [retroactivo]'
        : '[retroactivo]';
    await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      date: date,
      note: drift.Value(retroNote),
    ));
  }

  /// Duplicates a transaction (creates a copy with new id and current date).
  Future<void> duplicateTransaction(String id) async {
    final tx = await (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();

    await addTransaction(
      title: tx.title,
      amount: tx.amount,
      type: tx.type,
      categoryId: tx.categoryId,
      accountId: tx.accountId,
      date: DateTime.now(),
      note: tx.note,
    );
  }
}

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref.watch(databaseProvider));
});
