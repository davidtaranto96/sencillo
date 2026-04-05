import 'package:drift/drift.dart';

@DataClassName('GroupEntity')
class GroupsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get coverImageUrl => text().nullable()();
  RealColumn get totalGroupExpense => real().withDefault(const Constant(0.0))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
