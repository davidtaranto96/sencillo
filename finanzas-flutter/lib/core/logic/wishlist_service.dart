import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/database_providers.dart';
import '../../features/wishlist/domain/models/wishlist_item.dart';

class WishlistService {
  final AppDatabase db;
  WishlistService(this.db);

  Stream<List<WishlistItem>> watchActive() {
    return (db.select(db.wishlistTable)
          ..where((t) => t.isPurchased.equals(false))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  Stream<List<WishlistItem>> watchAll() {
    return (db.select(db.wishlistTable)
          ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  Future<void> addItem({
    required String title,
    required double estimatedCost,
    String? note,
    String? url,
    int installments = 1,
    bool hasPromo = false,
    int? reminderDays,
  }) async {
    await db.into(db.wishlistTable).insert(WishlistTableCompanion.insert(
      id: const Uuid().v4(),
      title: title,
      estimatedCost: estimatedCost,
      note: drift.Value(note),
      url: drift.Value(url),
      installments: drift.Value(installments),
      hasPromo: drift.Value(hasPromo),
      createdAt: DateTime.now(),
      reminderDays: drift.Value(reminderDays),
    ));
  }

  Future<void> updateItem(
    String id, {
    String? title,
    double? estimatedCost,
    String? note,
    String? url,
    int? installments,
    bool? hasPromo,
    int? reminderDays,
  }) async {
    await (db.update(db.wishlistTable)..where((t) => t.id.equals(id))).write(
      WishlistTableCompanion(
        title: title != null ? drift.Value(title) : const drift.Value.absent(),
        estimatedCost: estimatedCost != null ? drift.Value(estimatedCost) : const drift.Value.absent(),
        note: note != null ? drift.Value(note) : const drift.Value.absent(),
        url: url != null ? drift.Value(url) : const drift.Value.absent(),
        installments: installments != null ? drift.Value(installments) : const drift.Value.absent(),
        hasPromo: hasPromo != null ? drift.Value(hasPromo) : const drift.Value.absent(),
        reminderDays: reminderDays != null ? drift.Value(reminderDays) : const drift.Value.absent(),
      ),
    );
  }

  Future<void> deleteItem(String id) async {
    await (db.delete(db.wishlistTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> markAsPurchased(
    String id, {
    required String method,
    String? accountId,
  }) async {
    await (db.update(db.wishlistTable)..where((t) => t.id.equals(id))).write(
      WishlistTableCompanion(
        isPurchased: const drift.Value(true),
        purchasedAt: drift.Value(DateTime.now()),
        purchaseMethod: drift.Value(method),
        purchaseAccountId: drift.Value(accountId),
      ),
    );
  }

  Future<void> snoozeReminder(String id, Duration duration) async {
    await (db.update(db.wishlistTable)..where((t) => t.id.equals(id))).write(
      WishlistTableCompanion(
        reminderSnoozedUntil: drift.Value(DateTime.now().add(duration)),
      ),
    );
  }

  Future<void> dismissReminder(String id) async {
    await (db.update(db.wishlistTable)..where((t) => t.id.equals(id))).write(
      const WishlistTableCompanion(
        reminderDismissed: drift.Value(true),
      ),
    );
  }

  Future<void> linkBudget(String itemId, String budgetId) async {
    await (db.update(db.wishlistTable)..where((t) => t.id.equals(itemId))).write(
      WishlistTableCompanion(
        linkedBudgetId: drift.Value(budgetId),
      ),
    );
  }

  Future<void> unlinkBudget(String itemId) async {
    await (db.update(db.wishlistTable)..where((t) => t.id.equals(itemId))).write(
      const WishlistTableCompanion(
        linkedBudgetId: drift.Value(null),
      ),
    );
  }

  static WishlistItem _toModel(WishlistEntity e) {
    return WishlistItem(
      id: e.id,
      title: e.title,
      estimatedCost: e.estimatedCost,
      note: e.note,
      url: e.url,
      installments: e.installments,
      hasPromo: e.hasPromo,
      createdAt: e.createdAt,
      isPurchased: e.isPurchased,
      purchasedAt: e.purchasedAt,
      purchaseMethod: e.purchaseMethod,
      purchaseAccountId: e.purchaseAccountId,
      linkedBudgetId: e.linkedBudgetId,
      reminderDays: e.reminderDays,
      reminderSnoozedUntil: e.reminderSnoozedUntil,
      reminderDismissed: e.reminderDismissed,
    );
  }
}

final wishlistServiceProvider = Provider<WishlistService>((ref) {
  return WishlistService(ref.watch(databaseProvider));
});
