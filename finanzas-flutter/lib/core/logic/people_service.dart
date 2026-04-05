import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import 'package:uuid/uuid.dart';

class PeopleService {
  final AppDatabase db;

  PeopleService(this.db);

  // ─── Person CRUD ───────────────────────────────────────

  Future<String> addPerson({
    required String name,
    String? alias,
    String? cbu,
    String? notes,
  }) async {
    final id = const Uuid().v4();
    final color = _randomAvatarColor();
    await db.into(db.personsTable).insert(PersonsTableCompanion.insert(
      id: id,
      name: name,
      alias: drift.Value(alias),
      colorValue: color,
      cbu: drift.Value(cbu),
      notes: drift.Value(notes),
    ));
    return id;
  }

  Future<void> updatePerson({
    required String personId,
    String? name,
    String? alias,
    String? cbu,
    String? notes,
    bool clearCbu = false,
    bool clearNotes = false,
  }) async {
    final companion = PersonsTableCompanion(
      name: name != null ? drift.Value(name) : const drift.Value.absent(),
      alias: alias != null ? drift.Value(alias) : const drift.Value.absent(),
      cbu: clearCbu ? const drift.Value(null) : (cbu != null ? drift.Value(cbu) : const drift.Value.absent()),
      notes: clearNotes ? const drift.Value(null) : (notes != null ? drift.Value(notes) : const drift.Value.absent()),
    );
    await (db.update(db.personsTable)..where((t) => t.id.equals(personId)))
        .write(companion);
  }

  /// Vincula (o desvincula) una persona local con un UID de Firebase.
  Future<void> setLinkedUser(String personId, String? linkedUserId) async {
    await (db.update(db.personsTable)..where((t) => t.id.equals(personId)))
        .write(PersonsTableCompanion(
          linkedUserId: drift.Value(linkedUserId),
        ));
  }

  /// Crea una transacción local a partir de un gasto compartido entrante
  /// (registrado por el amigo en Firestore). [iOwe] = true cuando el amigo
  /// pagó todo y yo debo mi parte.
  /// Devuelve el ID de la transacción creada.
  Future<String> addSharedExpenseFromIncoming({
    required String personId,
    required String title,
    required double totalAmount,
    required double ownAmount,
    required double otherAmount,
    required DateTime date,
    String? categoryId,
    bool iOwe = true,
  }) async {
    final txId = const Uuid().v4();
    await db.transaction(() async {
      final person = await (db.select(db.personsTable)
            ..where((t) => t.id.equals(personId)))
          .getSingle();

      // iOwe: el amigo pagó → yo le debo mi parte → balance baja
      final balanceDelta = iOwe ? -ownAmount : otherAmount;
      await (db.update(db.personsTable)..where((t) => t.id.equals(personId)))
          .write(PersonsTableCompanion(
        totalBalance: drift.Value(person.totalBalance + balanceDelta),
      ));

      await db.into(db.transactionsTable).insert(
        TransactionsTableCompanion.insert(
          id: txId,
          title: title,
          amount: ownAmount,
          type: 'expense',
          categoryId: categoryId ?? 'other_expense',
          accountId: 'cash_ars',
          date: date,
          personId: drift.Value(personId),
          isShared: const drift.Value(true),
          sharedTotalAmount: drift.Value(totalAmount),
          sharedOwnAmount: drift.Value(ownAmount),
          sharedOtherAmount: drift.Value(otherAmount),
          note: drift.Value('[compartido_entrante]'),
        ),
      );
    });
    return txId;
  }

  Future<void> deletePerson(String personId) async {
    // Remove from all groups
    await (db.delete(db.groupMembersTable)
          ..where((t) => t.personId.equals(personId)))
        .go();
    // Remove person
    await (db.delete(db.personsTable)..where((t) => t.id.equals(personId)))
        .go();
  }

  // ─── Group CRUD ───────────────────────────────────────

  Future<String> addGroup({
    required String name,
    List<String> memberIds = const [],
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final id = const Uuid().v4();
    await db.transaction(() async {
      await db.into(db.groupsTable).insert(GroupsTableCompanion.insert(
        id: id,
        name: name,
        startDate: drift.Value(startDate),
        endDate: drift.Value(endDate),
      ));
      for (final memberId in memberIds) {
        await db.into(db.groupMembersTable).insert(
          GroupMembersTableCompanion.insert(groupId: id, personId: memberId),
        );
      }
    });
    return id;
  }

  Future<void> updateGroup({
    required String groupId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) async {
    final companion = GroupsTableCompanion(
      name: name != null ? drift.Value(name) : const drift.Value.absent(),
      startDate: clearStartDate ? const drift.Value(null) : (startDate != null ? drift.Value(startDate) : const drift.Value.absent()),
      endDate: clearEndDate ? const drift.Value(null) : (endDate != null ? drift.Value(endDate) : const drift.Value.absent()),
    );
    await (db.update(db.groupsTable)..where((t) => t.id.equals(groupId)))
        .write(companion);
  }

  Future<void> deleteGroup(String groupId) async {
    await db.transaction(() async {
      await (db.delete(db.groupMembersTable)
            ..where((t) => t.groupId.equals(groupId)))
          .go();
      await (db.delete(db.groupsTable)..where((t) => t.id.equals(groupId)))
          .go();
    });
  }

  Future<void> addMemberToGroup(String groupId, String personId) async {
    await db.into(db.groupMembersTable).insertOnConflictUpdate(
      GroupMembersTableCompanion.insert(groupId: groupId, personId: personId),
    );
  }

  Future<void> removeMemberFromGroup(String groupId, String personId) async {
    await (db.delete(db.groupMembersTable)
          ..where((t) =>
              t.groupId.equals(groupId) & t.personId.equals(personId)))
        .go();
  }

  Future<List<String>> getGroupMemberIds(String groupId) async {
    final rows = await (db.select(db.groupMembersTable)
          ..where((t) => t.groupId.equals(groupId)))
        .get();
    return rows.map((r) => r.personId).toList();
  }

  // ─── Shared Expenses ──────────────────────────────────

  /// Liquidates (pays) a debt with a person.
  /// [amount] is positive when they pay me, negative when I pay them.
  /// [accountId] is optional — if null, only adjusts the person balance (no account/transaction).
  Future<void> liquidateDebt({
    required String personId,
    required double amount,
    String? accountId,
  }) async {
    await db.transaction(() async {
      final person = await (db.select(db.personsTable)
            ..where((t) => t.id.equals(personId)))
          .getSingle();
      await (db.update(db.personsTable)..where((t) => t.id.equals(personId)))
          .write(PersonsTableCompanion(
        totalBalance: drift.Value(person.totalBalance - amount),
      ));

      if (accountId != null) {
        final account = await (db.select(db.accountsTable)
              ..where((t) => t.id.equals(accountId)))
            .getSingle();
        await (db.update(db.accountsTable)
              ..where((t) => t.id.equals(accountId)))
            .write(AccountsTableCompanion(
          initialBalance: drift.Value(account.initialBalance + amount),
        ));

        final categoryId = amount > 0 ? 'other_income' : 'other_expense';
        await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            id: const Uuid().v4(),
            title: amount > 0
                ? '${person.name} te pagó'
                : 'Pago a ${person.name}',
            amount: amount.abs(),
            type: amount > 0 ? 'income' : 'expense',
            categoryId: categoryId,
            accountId: accountId,
            date: DateTime.now(),
            personId: drift.Value(personId),
          ),
        );
      }
    });
  }

  /// Adjusts a person's balance directly (for pre-existing debts/loans).
  /// Does not affect any account or create a transaction.
  Future<void> adjustBalance({
    required String personId,
    required double delta,
  }) async {
    final person = await (db.select(db.personsTable)
          ..where((t) => t.id.equals(personId)))
        .getSingle();
    await (db.update(db.personsTable)..where((t) => t.id.equals(personId)))
        .write(PersonsTableCompanion(
      totalBalance: drift.Value(person.totalBalance + delta),
    ));
  }

  /// Records a shared expense between the user and another person.
  Future<void> recordSharedExpense({
    required String personId,
    required double totalAmount,
    required bool iPaid,
    required double ownAmount,
    required double otherAmount,
    required String description,
    String? accountId,
    String? groupId,
    DateTime? date,
  }) async {
    final txDate = date ?? DateTime.now();

    await db.transaction(() async {
      final person = await (db.select(db.personsTable)
            ..where((t) => t.id.equals(personId)))
          .getSingle();

      if (iPaid) {
        if (accountId != null) {
          final account = await (db.select(db.accountsTable)
                ..where((t) => t.id.equals(accountId)))
              .getSingle();
          await (db.update(db.accountsTable)
                ..where((t) => t.id.equals(accountId)))
              .write(AccountsTableCompanion(
            initialBalance: drift.Value(account.initialBalance - totalAmount),
          ));
        }

        await (db.update(db.personsTable)
              ..where((t) => t.id.equals(personId)))
            .write(PersonsTableCompanion(
          totalBalance: drift.Value(person.totalBalance + otherAmount),
        ));

        await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            id: const Uuid().v4(),
            title: description,
            amount: totalAmount,
            type: 'expense',
            categoryId: 'other_expense',
            accountId: accountId ?? 'cash_ars',
            date: txDate,
            personId: drift.Value(personId),
            groupId: drift.Value(groupId),
            isShared: const drift.Value(true),
            sharedTotalAmount: drift.Value(totalAmount),
            sharedOwnAmount: drift.Value(ownAmount),
            sharedOtherAmount: drift.Value(otherAmount),
          ),
        );
      } else {
        await (db.update(db.personsTable)
              ..where((t) => t.id.equals(personId)))
            .write(PersonsTableCompanion(
          totalBalance: drift.Value(person.totalBalance - ownAmount),
        ));

        await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            id: const Uuid().v4(),
            title: description,
            amount: ownAmount,
            type: 'expense',
            categoryId: 'other_expense',
            accountId: 'cash_ars',
            date: txDate,
            personId: drift.Value(personId),
            groupId: drift.Value(groupId),
            isShared: const drift.Value(true),
            sharedTotalAmount: drift.Value(totalAmount),
            sharedOwnAmount: drift.Value(ownAmount),
            sharedOtherAmount: drift.Value(otherAmount),
          ),
        );
      }

      // Update group total if applicable
      if (groupId != null) {
        final group = await (db.select(db.groupsTable)
              ..where((t) => t.id.equals(groupId)))
            .getSingleOrNull();
        if (group != null) {
          await (db.update(db.groupsTable)
                ..where((t) => t.id.equals(groupId)))
              .write(GroupsTableCompanion(
            totalGroupExpense:
                drift.Value(group.totalGroupExpense + totalAmount),
          ));
        }
      }
    });
  }

  /// Records a direct debt/loan.
  Future<void> recordDirectDebt({
    required String personId,
    required double amount,
    required bool iLent,
    required String description,
    String? accountId,
    DateTime? date,
  }) async {
    final txDate = date ?? DateTime.now();
    await db.transaction(() async {
      final person = await (db.select(db.personsTable)
            ..where((t) => t.id.equals(personId)))
          .getSingle();

      final deltaPerson = iLent ? amount : -amount;
      final deltaAccount = iLent ? -amount : amount;

      await (db.update(db.personsTable)..where((t) => t.id.equals(personId)))
          .write(PersonsTableCompanion(
        totalBalance: drift.Value(person.totalBalance + deltaPerson),
      ));

      if (accountId != null) {
        final account = await (db.select(db.accountsTable)
              ..where((t) => t.id.equals(accountId)))
            .getSingle();
        await (db.update(db.accountsTable)
              ..where((t) => t.id.equals(accountId)))
            .write(AccountsTableCompanion(
          initialBalance: drift.Value(account.initialBalance + deltaAccount),
        ));
      }

      await db.into(db.transactionsTable).insert(
        TransactionsTableCompanion.insert(
          id: const Uuid().v4(),
          title: description,
          amount: amount,
          type: iLent ? 'loanGiven' : 'loanReceived',
          categoryId: iLent ? 'other_expense' : 'other_income',
          accountId: accountId ?? 'cash_ars',
          date: txDate,
          personId: drift.Value(personId),
        ),
      );
    });
  }

  /// Get all transactions for a specific person.
  Future<List<TransactionEntity>> getPersonTransactions(
      String personId) async {
    return (db.select(db.transactionsTable)
          ..where((t) => t.personId.equals(personId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Get all transactions for a specific group.
  Future<List<TransactionEntity>> getGroupTransactions(String groupId) async {
    return (db.select(db.transactionsTable)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Updates a shared expense transaction and recalculates person balance.
  Future<void> updateSharedExpense({
    required String txId,
    required double newTotal,
    required double newOwn,
    required double newOther,
    String? description,
  }) async {
    await db.transaction(() async {
      final tx = await (db.select(db.transactionsTable)
            ..where((t) => t.id.equals(txId)))
          .getSingle();

      if (tx.personId != null) {
        final person = await (db.select(db.personsTable)
              ..where((t) => t.id.equals(tx.personId!)))
            .getSingle();

        // Reverse old balance effect
        final oldOther = tx.sharedOtherAmount ?? 0;
        final oldOwn = tx.sharedOwnAmount ?? 0;
        final wasPaidByMe = tx.type == 'expense' && tx.accountId != 'shared_obligation';
        double balanceDelta;
        if (wasPaidByMe) {
          balanceDelta = -oldOther + newOther; // they owed oldOther, now owe newOther
        } else {
          balanceDelta = oldOwn - newOwn; // I owed oldOwn, now owe newOwn
        }

        await (db.update(db.personsTable)
              ..where((t) => t.id.equals(tx.personId!)))
            .write(PersonsTableCompanion(
          totalBalance: drift.Value(person.totalBalance + balanceDelta),
        ));
      }

      // Update transaction
      await (db.update(db.transactionsTable)..where((t) => t.id.equals(txId)))
          .write(TransactionsTableCompanion(
        title: description != null ? drift.Value(description) : const drift.Value.absent(),
        amount: drift.Value(newTotal),
        sharedTotalAmount: drift.Value(newTotal),
        sharedOwnAmount: drift.Value(newOwn),
        sharedOtherAmount: drift.Value(newOther),
      ));
    });
  }

  int _randomAvatarColor() {
    const colors = [
      0xFF5ECFB1, 0xFF7C6EF7, 0xFFFF5C6E, 0xFFFFB347,
      0xFF4FC3F7, 0xFFBA68C8, 0xFF81C784, 0xFFFF8A65,
      0xFF64B5F6, 0xFFE57373, 0xFFA1887F, 0xFF90A4AE,
    ];
    return colors[Random().nextInt(colors.length)];
  }
}

final peopleServiceProvider = Provider<PeopleService>((ref) {
  return PeopleService(ref.watch(databaseProvider));
});
