import 'package:drift/drift.dart';

@DataClassName('PersonEntity')
class PersonsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get alias => text().nullable()();
  IntColumn get colorValue => integer()();
  RealColumn get totalBalance => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}
