import 'package:drift/drift.dart';

@DataClassName('AccountEntity')
class AccountsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get iconName => text()();
  IntColumn get colorValue => integer()();
  RealColumn get initialBalance => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}
