import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import 'package:uuid/uuid.dart';

class PeopleService {
  final AppDatabase db;

  PeopleService(this.db);
  
  /// Liquidates (pays) a debt with a person.
  /// If amount > 0, they paid us (MP increases).
  /// If amount < 0, we paid them (MP decreases).
  Future<void> liquidateDebt({
    required String personId,
    required double amount,
    required String accountId,
  }) async {
    await db.transaction(() async {
      // 1. Update Person Balance
      final person = await (db.select(db.personsTable)..where((t) => t.id.equals(personId))).getSingle();
      await (db.update(db.personsTable)..where((t) => t.id.equals(personId))).write(
        PersonsTableCompanion(
          totalBalance: drift.Value(person.totalBalance - amount),
        ),
      );

      // 2. Update Account Balance
      final account = await (db.select(db.accountsTable)..where((t) => t.id.equals(accountId))).getSingle();
      await (db.update(db.accountsTable)..where((t) => t.id.equals(accountId))).write(
        AccountsTableCompanion(
          initialBalance: drift.Value(account.initialBalance + amount),
        ),
      );

      // 3. Record Transaction
      await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
        id: const Uuid().v4(),
        title: 'Liquidación: ${person.name}',
        amount: amount.abs(),
        type: amount > 0 ? 'income' : 'expense',
        categoryId: 'cat_peer_to_peer',
        accountId: accountId,
        date: DateTime.now(),
        personId: drift.Value(personId),
      ));
    });
  }

  /// Records a shared expense between the user and another person.
  /// [totalAmount] is the total cost of the item/service.
  /// [iPaid] is true if the user paid, false if the other person paid.
  /// [ownAmount] is the portion the user is responsible for.
  /// [otherAmount] is the portion the other person is responsible for.
  Future<void> recordSharedExpense({
    required String personId,
    required double totalAmount,
    required bool iPaid,
    required double ownAmount,
    required double otherAmount,
    required String description,
    String? accountId,
    DateTime? date,
  }) async {
    final txDate = date ?? DateTime.now();

    await db.transaction(() async {
      final person = await (db.select(db.personsTable)..where((t) => t.id.equals(personId))).getSingle();

      if (iPaid) {
        // 1. Debit my account full amount (if I paid the total)
        if (accountId != null) {
          final account = await (db.select(db.accountsTable)..where((t) => t.id.equals(accountId))).getSingle();
          await (db.update(db.accountsTable)..where((t) => t.id.equals(accountId))).write(
            AccountsTableCompanion(
              initialBalance: drift.Value(account.initialBalance - totalAmount),
            ),
          );
        }

        // 2. Increase person balance (they owe me their share)
        await (db.update(db.personsTable)..where((t) => t.id.equals(personId))).write(
          PersonsTableCompanion(
            totalBalance: drift.Value(person.totalBalance + otherAmount),
          ),
        );

        // 3. Record transaction
        await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
          id: const Uuid().v4(),
          title: description,
          amount: totalAmount,
          type: 'expense',
          categoryId: 'cat_peer_to_peer',
          accountId: accountId ?? 'unknown',
          date: txDate,
          personId: drift.Value(personId),
          isShared: const drift.Value(true),
          sharedTotalAmount: drift.Value(totalAmount),
          sharedOwnAmount: drift.Value(ownAmount),
          sharedOtherAmount: drift.Value(otherAmount),
        ));
      } else {
        // They paid, I owe them my portion.
        // 1. My account balance does NOT change (they paid externally).
        
        // 2. Decrease person balance (I owe them my share)
        await (db.update(db.personsTable)..where((t) => t.id.equals(personId))).write(
          PersonsTableCompanion(
            totalBalance: drift.Value(person.totalBalance - ownAmount),
          ),
        );

        // 3. Record transaction
        await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
          id: const Uuid().v4(),
          title: description,
          amount: ownAmount,
          type: 'expense',
          categoryId: 'cat_peer_to_peer',
          accountId: 'shared_obligation',
          date: txDate,
          personId: drift.Value(personId),
          isShared: const drift.Value(true),
          sharedTotalAmount: drift.Value(totalAmount),
          sharedOwnAmount: drift.Value(ownAmount),
          sharedOtherAmount: drift.Value(otherAmount),
        ));
      }
    });
  }

  /// Records a direct debt/loan without a split (e.g., "I lent you $100" or "You lent me $100").
  Future<void> recordDirectDebt({
    required String personId,
    required double amount,
    required bool iLent,
    required String description,
    String? accountId, // Only if money moved via accounts
    DateTime? date,
  }) async {
    final txDate = date ?? DateTime.now();
    await db.transaction(() async {
      final person = await (db.select(db.personsTable)..where((t) => t.id.equals(personId))).getSingle();

      // If iLent=true (Positive balance for user): account decreases, person.totalBalance increases
      // If iLent=false (Negative balance for user): account increases, person.totalBalance decreases
      
      final deltaPerson = iLent ? amount : -amount;
      final deltaAccount = iLent ? -amount : amount;

      await (db.update(db.personsTable)..where((t) => t.id.equals(personId))).write(
        PersonsTableCompanion(totalBalance: drift.Value(person.totalBalance + deltaPerson)),
      );

      if (accountId != null) {
        final account = await (db.select(db.accountsTable)..where((t) => t.id.equals(accountId))).getSingle();
        await (db.update(db.accountsTable)..where((t) => t.id.equals(accountId))).write(
          AccountsTableCompanion(initialBalance: drift.Value(account.initialBalance + deltaAccount)),
        );
      }

      await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
        id: const Uuid().v4(),
        title: description,
        amount: amount,
        type: iLent ? 'expense' : 'income',
        categoryId: 'cat_peer_to_peer',
        accountId: accountId ?? (iLent ? 'cash_lent' : 'cash_borrowed'),
        date: txDate,
        personId: drift.Value(personId),
      ));
    });
  }
}

final peopleServiceProvider = Provider<PeopleService>((ref) {
  return PeopleService(ref.watch(databaseProvider));
});
