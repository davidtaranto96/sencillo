import 'package:drift/drift.dart';

@DataClassName('BudgetEntity')
class BudgetsTable extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()(); // FK to category
  RealColumn get limitAmount => real()();
  RealColumn get spentAmount => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}
