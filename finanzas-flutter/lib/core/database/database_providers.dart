import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'app_database.dart';
import '../../features/accounts/domain/models/account.dart' as dom;
import '../../features/transactions/domain/models/transaction.dart' as dom_tx;
import '../../features/people/domain/models/person.dart' as dom_p;
import '../../features/goals/domain/models/goal.dart' as dom_g;
import '../../features/budget/domain/models/budget.dart' as dom_b;
import '../../features/people/domain/models/group.dart' as dom_grp;

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// Accounts Stream with real-time balance calculation
final accountsStreamProvider = StreamProvider<List<dom.Account>>((ref) {
  final db = ref.watch(databaseProvider);
  
  // Combine account stream with transaction stream for real-time balance calculation
  return db.select(db.accountsTable).watch().asyncMap((entities) async {
    final List<dom.Account> accounts = [];
    
    for (final e in entities) {
      // Get all transactions for this account
      final txs = await (db.select(db.transactionsTable)
        ..where((t) => t.accountId.equals(e.id))).get();
      
      double currentBalance = e.initialBalance;
      for (final tx in txs) {
        // Skip retroactive transactions — they are for historical monthly
        // overview only and must NOT affect the current real balance.
        if (tx.note != null && tx.note!.contains('[retroactivo]')) continue;

        if (tx.type == dom_tx.TransactionType.income.name) {
          currentBalance += tx.amount;
        } else if (tx.type == dom_tx.TransactionType.expense.name) {
          currentBalance -= tx.amount;
        }
        // Transfers are tricky, but in this app they usually target a specific account
        // If type is transfer and account matches, it was a debit.
        // In this schema, transfers usually have source/target in a different way or are just expenses.
        if (tx.type == 'transfer') {
          currentBalance -= tx.amount;
        }
      }

      accounts.add(dom.Account(
        id: e.id,
        name: e.name,
        type: _parseAccountType(e.type),
        balance: currentBalance,
        currencyCode: e.currencyCode,
        icon: e.iconName,
        color: e.colorValue != null ? '#${e.colorValue!.toRadixString(16)}' : null,
        isDefault: e.isDefault,
        closingDay: e.closingDay,
        dueDay: e.dueDay,
        creditLimit: e.creditLimit,
        pendingStatementAmount: e.pendingStatementAmount,
        lastClosedDate: e.lastClosedDate,
        alias: e.alias,
        cvu: e.cvu,
      ));
    }
    return accounts;
  });
});

// Transactions Stream
final transactionsStreamProvider = StreamProvider<List<dom_tx.Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactionsTable)
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch()
      .map((entities) {
    return entities.map((e) {
      return dom_tx.Transaction(
        id: e.id,
        title: e.title,
        amount: e.amount,
        type: _parseTransactionType(e.type),
        categoryId: e.categoryId,
        accountId: e.accountId,
        date: e.date,
        note: e.note,
        personId: e.personId,
        groupId: e.groupId,
        isShared: e.isShared,
        sharedTotalAmount: e.sharedTotalAmount,
        sharedOwnAmount: e.sharedOwnAmount,
        sharedOtherAmount: e.sharedOtherAmount,
        sharedRecovered: e.sharedRecovered,
      );
    }).toList();
  });
});

// People Stream
final peopleStreamProvider = StreamProvider<List<dom_p.Person>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.personsTable).watch().map((entities) {
    return entities.map((e) {
      return dom_p.Person(
        id: e.id,
        name: e.name,
        alias: e.alias,
        totalBalance: e.totalBalance,
        avatarColor: Color(e.colorValue),
        cbu: e.cbu,
        notes: e.notes,
      );
    }).toList();
  });
});

final globalPeopleBalanceProvider = Provider<double>((ref) {
  final peopleAsync = ref.watch(peopleStreamProvider);
  return peopleAsync.when(
    data: (list) => list.fold(0.0, (sum, p) => sum + p.totalBalance),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

// Categories Stream
final categoriesStreamProvider = StreamProvider<List<CategoryEntity>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categoriesTable).watch();
});

// Budgets with real spending calculated from current month transactions.
// Uses a StreamController that listens to BOTH budgets and transactions tables
// to ensure spending recalculates whenever either changes.
final budgetsStreamProvider = StreamProvider<List<dom_b.Budget>>((ref) {
  final db = ref.watch(databaseProvider);

  final controller = StreamController<List<dom_b.Budget>>();
  bool disposed = false;

  Future<void> recalculate() async {
    if (disposed) return;
    try {
      final budgets = await db.select(db.budgetsTable).get();
      if (budgets.isEmpty) {
        if (!disposed) controller.add([]);
        return;
      }

      final cats = await db.select(db.categoriesTable).get();
      final catMap = {for (final c in cats) c.id: c};

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month);
      final monthEnd = DateTime(now.year, now.month + 1);
      final monthYear = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final allTxs = await db.select(db.transactionsTable).get();
      final txs = allTxs.where((t) =>
          t.type == 'expense' &&
          !t.date.isBefore(monthStart) &&
          t.date.isBefore(monthEnd));

      final spentByCategory = <String, double>{};
      for (final tx in txs) {
        spentByCategory[tx.categoryId] =
            (spentByCategory[tx.categoryId] ?? 0) + tx.amount;
      }

      final result = budgets.map((b) {
        final cat = catMap[b.categoryId];
        return dom_b.Budget(
          id: b.id,
          categoryId: b.categoryId,
          categoryName: cat?.name ?? 'Sin categoría',
          iconKey: cat?.iconName ?? 'pie_chart',
          colorValue: cat?.colorValue ?? 0xFF6C63FF,
          limitAmount: b.limitAmount,
          spentAmount: spentByCategory[b.categoryId] ?? 0.0,
          monthYear: monthYear,
          isFixed: cat?.isFixed ?? false,
        );
      }).toList();

      if (!disposed) controller.add(result);
    } catch (e) {
      if (!disposed) controller.addError(e);
    }
  }

  // Listen to both tables — recalculate when either changes
  final sub1 = db.select(db.budgetsTable).watch().listen((_) => recalculate());
  final sub2 = db.select(db.transactionsTable).watch().listen((_) => recalculate());
  final sub3 = db.select(db.categoriesTable).watch().listen((_) => recalculate());

  ref.onDispose(() {
    disposed = true;
    sub1.cancel();
    sub2.cancel();
    sub3.cancel();
    controller.close();
  });

  return controller.stream;
});

// Goals Stream
final goalsStreamProvider = StreamProvider<List<dom_g.Goal>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.goalsTable).watch().map((entities) {
    return entities.map((e) => dom_g.Goal(
      id: e.id,
      name: e.name,
      targetAmount: e.targetAmount,
      savedAmount: e.currentAmount,
      colorValue: e.colorValue,
      iconName: e.iconName ?? 'flag',
      deadline: e.deadline,
    )).toList();
  });
});

final groupsStreamProvider = StreamProvider<List<dom_grp.ExpenseGroup>>((ref) {
  final db = ref.watch(databaseProvider);
  final people = ref.watch(peopleStreamProvider).valueOrNull ?? [];
  final personMap = {for (final p in people) p.id: p};

  return db.select(db.groupsTable).watch().asyncMap((entities) async {
    final List<dom_grp.ExpenseGroup> groups = [];
    for (final e in entities) {
      final memberRows = await (db.select(db.groupMembersTable)
            ..where((t) => t.groupId.equals(e.id)))
          .get();
      final members = memberRows
          .map((r) => personMap[r.personId])
          .whereType<dom_p.Person>()
          .toList();
      groups.add(dom_grp.ExpenseGroup(
        id: e.id,
        name: e.name,
        members: members,
        coverImageUrl: e.coverImageUrl,
        totalGroupExpense: e.totalGroupExpense,
        startDate: e.startDate,
        endDate: e.endDate,
      ));
    }
    return groups;
  });
});

/// Transactions for a specific person
final personTransactionsProvider =
    StreamProvider.family<List<dom_tx.Transaction>, String>((ref, personId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactionsTable)
        ..where((t) => t.personId.equals(personId))
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch()
      .map((entities) => entities
          .map((e) => dom_tx.Transaction(
                id: e.id,
                title: e.title,
                amount: e.amount,
                type: _parseTransactionType(e.type),
                categoryId: e.categoryId,
                accountId: e.accountId,
                date: e.date,
                note: e.note,
                personId: e.personId,
                groupId: e.groupId,
                isShared: e.isShared,
                sharedTotalAmount: e.sharedTotalAmount,
                sharedOwnAmount: e.sharedOwnAmount,
                sharedOtherAmount: e.sharedOtherAmount,
                sharedRecovered: e.sharedRecovered,
              ))
          .toList());
});

/// Transactions for a specific group
final groupTransactionsProvider =
    StreamProvider.family<List<dom_tx.Transaction>, String>((ref, groupId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactionsTable)
        ..where((t) => t.groupId.equals(groupId))
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch()
      .map((entities) => entities
          .map((e) => dom_tx.Transaction(
                id: e.id,
                title: e.title,
                amount: e.amount,
                type: _parseTransactionType(e.type),
                categoryId: e.categoryId,
                accountId: e.accountId,
                date: e.date,
                note: e.note,
                personId: e.personId,
                groupId: e.groupId,
                isShared: e.isShared,
                sharedTotalAmount: e.sharedTotalAmount,
                sharedOwnAmount: e.sharedOwnAmount,
                sharedOtherAmount: e.sharedOtherAmount,
                sharedRecovered: e.sharedRecovered,
              ))
          .toList());
});

// User Profile Stream
final userProfileStreamProvider = StreamProvider<UserProfileEntity?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.userProfileTable)
        ..where((t) => t.id.equals('user_profile_singleton')))
      .watchSingleOrNull();
});

dom.AccountType _parseAccountType(String type) {
  return dom.AccountType.values.firstWhere(
    (e) => e.name == type,
    orElse: () => dom.AccountType.bank,
  );
}

dom_tx.TransactionType _parseTransactionType(String type) {
  return dom_tx.TransactionType.values.firstWhere(
    (e) => e.name == type,
    orElse: () => dom_tx.TransactionType.expense,
  );
}
