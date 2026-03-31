import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import '../../features/accounts/domain/models/account.dart' as dom;
import '../../features/transactions/domain/models/transaction.dart' as dom_tx;
import '../../features/people/domain/models/person.dart' as dom_p;
import 'package:flutter/material.dart';

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
      ));
    }
    return accounts;
  });
});

// Transactions Stream
final transactionsStreamProvider = StreamProvider<List<dom_tx.Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.transactionsTable).watch().map((entities) {
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
        avatarColor: Color(e.colorValue ?? 0xFF7C6EF7),
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
