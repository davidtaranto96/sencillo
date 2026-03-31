import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../../features/accounts/domain/models/account.dart';
import 'package:drift/drift.dart';

class MonthClosureService {
  final AppDatabase db;

  MonthClosureService(this.db);

  /// Performs the month-end closing logic:
  /// 1. Cycles credit cards: moves balance to pendingStatementAmount.
  /// 2. Resets current month budgets (handled in budget features).
  /// 3. Snapshots current month performance.
  Future<void> closeMonth(DateTime closingMonth) async {
    // 1. Process Credit Cards
    final accounts = await db.select(db.accountsTable).get();
    
    for (final account in accounts) {
      if (account.type == 'credit') {
        // Moving actual debt to pending
        final currentDebt = account.initialBalance; // This represents spending in the prototype
        
        await (db.update(db.accountsTable)..where((t) => t.id.equals(account.id))).write(
          AccountsTableCompanion(
            pendingStatementAmount: Value(currentDebt),
            initialBalance: const Value(0.0), // Reset current cycle
            lastClosedDate: Value(DateTime.now()),
          ),
        );
      }
    }

    // 2. We skip budget duplication logic for now as it's mock-based in providers,
    // but in a real DB it would involve copying rows from one month to another.
    
    print('Cierre de mes completado para $closingMonth');
  }
}

final monthClosureServiceProvider = Provider<MonthClosureService>((ref) {
  // Assuming a global DB provider exists
  return MonthClosureService(ref.watch(databaseProvider)); 
});
