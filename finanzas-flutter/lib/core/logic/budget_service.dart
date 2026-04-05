import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/database_providers.dart';

class BudgetService {
  final AppDatabase db;
  BudgetService(this.db);

  /// Creates a budget linked to a predefined transaction category.
  /// If the category doesn't exist in the DB yet, it creates it.
  Future<void> addBudgetForCategory({
    required String categoryId,
    required String categoryName,
    required double limitAmount,
    required bool isFixed,
    required int colorValue,
    required String iconKey,
  }) async {
    await db.transaction(() async {
      // Ensure the category exists (upsert)
      final existing = await (db.select(db.categoriesTable)
            ..where((t) => t.id.equals(categoryId)))
          .getSingleOrNull();
      if (existing == null) {
        await db.into(db.categoriesTable).insert(
          CategoriesTableCompanion.insert(
            id: categoryId,
            name: categoryName,
            iconName: iconKey,
            colorValue: colorValue,
            isFixed: drift.Value(isFixed),
          ),
        );
      } else if (existing.name != categoryName) {
        // Update category name if user customized it
        await (db.update(db.categoriesTable)
              ..where((t) => t.id.equals(categoryId)))
            .write(CategoriesTableCompanion(
          name: drift.Value(categoryName),
          iconName: drift.Value(iconKey),
          colorValue: drift.Value(colorValue),
          isFixed: drift.Value(isFixed),
        ));
      }
      await db.into(db.budgetsTable).insert(
        BudgetsTableCompanion.insert(
          id: const Uuid().v4(),
          categoryId: categoryId,
          limitAmount: limitAmount,
        ),
      );
    });
  }

  /// Creates a budget with a new custom category (UUID-based).
  /// Returns the budget ID.
  Future<String> addBudget({
    required String categoryName,
    required double limitAmount,
    required bool isFixed,
    required int colorValue,
    required String iconKey,
  }) async {
    final budgetId = const Uuid().v4();
    await db.transaction(() async {
      final categoryId = const Uuid().v4();
      await db.into(db.categoriesTable).insert(
        CategoriesTableCompanion.insert(
          id: categoryId,
          name: categoryName,
          iconName: iconKey,
          colorValue: colorValue,
          isFixed: drift.Value(isFixed),
        ),
      );
      await db.into(db.budgetsTable).insert(
        BudgetsTableCompanion.insert(
          id: budgetId,
          categoryId: categoryId,
          limitAmount: limitAmount,
        ),
      );
    });
    return budgetId;
  }

  Future<void> updateBudget(
    String budgetId,
    String categoryId, {
    String? categoryName,
    double? limitAmount,
    bool? isFixed,
    int? colorValue,
    String? iconKey,
  }) async {
    await db.transaction(() async {
      await (db.update(db.categoriesTable)
            ..where((t) => t.id.equals(categoryId)))
          .write(CategoriesTableCompanion(
        name: categoryName != null
            ? drift.Value(categoryName)
            : const drift.Value.absent(),
        iconName: iconKey != null
            ? drift.Value(iconKey)
            : const drift.Value.absent(),
        colorValue: colorValue != null
            ? drift.Value(colorValue)
            : const drift.Value.absent(),
        isFixed: isFixed != null
            ? drift.Value(isFixed)
            : const drift.Value.absent(),
      ));
      if (limitAmount != null) {
        await (db.update(db.budgetsTable)
              ..where((t) => t.id.equals(budgetId)))
            .write(BudgetsTableCompanion(
          limitAmount: drift.Value(limitAmount),
        ));
      }
    });
  }

  Future<void> deleteBudget(String budgetId, String categoryId) async {
    await db.transaction(() async {
      await (db.delete(db.budgetsTable)
            ..where((t) => t.id.equals(budgetId)))
          .go();
      await (db.delete(db.categoriesTable)
            ..where((t) => t.id.equals(categoryId)))
          .go();
    });
  }
}

final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService(ref.watch(databaseProvider));
});
