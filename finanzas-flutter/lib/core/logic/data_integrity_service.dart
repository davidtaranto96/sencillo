import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_providers.dart';
import 'people_service.dart';

/// Servicio de integridad de datos.
/// Detecta y corrige inconsistencias: balances de personas desincronizados,
/// transacciones huérfanas, totales de grupos incorrectos, etc.
///
/// Diseñado para ejecutarse en pull-to-refresh. Es idempotente y seguro.
class DataIntegrityService {
  final AppDatabase db;
  final PeopleService peopleService;

  DataIntegrityService(this.db, this.peopleService);

  /// Ejecuta todas las verificaciones y devuelve un resumen de lo corregido.
  Future<DataIntegrityReport> runFullCheck() async {
    final personsFixed = await peopleService.fixOrphanedPersonBalances();
    final groupsFixed = await _fixGroupTotals();
    final accountsFixed = await _fixSharedExpenseDoubleCount();

    return DataIntegrityReport(
      personsFixed: personsFixed,
      groupsFixed: groupsFixed,
      accountsFixed: accountsFixed,
    );
  }

  /// Recalcula el total de gastos de cada grupo desde las transacciones reales.
  Future<int> _fixGroupTotals() async {
    int fixed = 0;
    final groups = await db.select(db.groupsTable).get();

    for (final group in groups) {
      final txs = await (db.select(db.transactionsTable)
            ..where((t) => t.groupId.equals(group.id)))
          .get();

      final realTotal = txs.fold(
        0.0,
        (sum, tx) => sum + (tx.sharedTotalAmount ?? tx.amount),
      );

      if ((group.totalGroupExpense - realTotal).abs() > 0.01) {
        await (db.update(db.groupsTable)..where((t) => t.id.equals(group.id)))
            .write(GroupsTableCompanion(
          totalGroupExpense: drift.Value(realTotal),
        ));
        fixed++;
      }
    }
    return fixed;
  }

  /// Repara el double-counting de gastos compartidos.
  ///
  /// Bug histórico: `recordSharedExpense` (iPaid=true) restaba `totalAmount`
  /// del `initialBalance` de la cuenta, ADEMÁS de crear una tx expense que
  /// también descuenta del balance calculado. Resultado: balance se veía
  /// el doble de negativo.
  ///
  /// Fix: por cada tx shared con iPaid, sumar `sharedTotalAmount` de vuelta
  /// al `initialBalance` de la cuenta afectada.
  Future<int> _fixSharedExpenseDoubleCount() async {
    int fixed = 0;
    final sharedTxs = await (db.select(db.transactionsTable)
          ..where((t) =>
              t.isShared.equals(true) &
              t.accountId.isNotValue('shared_obligation') &
              t.type.equals('expense')))
        .get();

    // Agrupar correcciones por cuenta
    final corrections = <String, double>{};
    for (final tx in sharedTxs) {
      final amount = tx.sharedTotalAmount ?? tx.amount;
      corrections[tx.accountId] = (corrections[tx.accountId] ?? 0) + amount;
    }

    for (final entry in corrections.entries) {
      if (entry.value.abs() < 0.01) continue;
      final account = await (db.select(db.accountsTable)
            ..where((t) => t.id.equals(entry.key)))
          .getSingleOrNull();
      if (account == null) continue;

      await (db.update(db.accountsTable)
            ..where((t) => t.id.equals(entry.key)))
          .write(AccountsTableCompanion(
        initialBalance: drift.Value(account.initialBalance + entry.value),
      ));
      fixed++;
    }
    return fixed;
  }
}

class DataIntegrityReport {
  final int personsFixed;
  final int groupsFixed;
  final int accountsFixed;

  const DataIntegrityReport({
    required this.personsFixed,
    required this.groupsFixed,
    this.accountsFixed = 0,
  });

  bool get hadIssues =>
      personsFixed > 0 || groupsFixed > 0 || accountsFixed > 0;

  @override
  String toString() =>
      'DataIntegrityReport(personas: $personsFixed, grupos: $groupsFixed, cuentas: $accountsFixed)';
}

final dataIntegrityServiceProvider = Provider<DataIntegrityService>((ref) {
  return DataIntegrityService(
    ref.watch(databaseProvider),
    ref.watch(peopleServiceProvider),
  );
});
