import 'package:drift/drift.dart';

@DataClassName('CategoryEntity')
class CategoriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get iconName => text()();
  IntColumn get colorValue => integer()();
  RealColumn get monthlyBudget => real().nullable()();
  BoolColumn get isFixed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
