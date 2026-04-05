import 'package:drift/drift.dart';

@DataClassName('WishlistEntity')
class WishlistTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get estimatedCost => real()();
  TextColumn get note => text().nullable()();
  TextColumn get url => text().nullable()();
  IntColumn get installments => integer().withDefault(const Constant(1))();
  BoolColumn get hasPromo => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isPurchased => boolean().withDefault(const Constant(false))();
  DateTimeColumn get purchasedAt => dateTime().nullable()();
  TextColumn get purchaseMethod => text().nullable()(); // 'account', 'cash', 'regalo'
  TextColumn get purchaseAccountId => text().nullable()();
  TextColumn get linkedBudgetId => text().nullable()();
  IntColumn get reminderDays => integer().nullable()();
  DateTimeColumn get reminderSnoozedUntil => dateTime().nullable()();
  BoolColumn get reminderDismissed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
