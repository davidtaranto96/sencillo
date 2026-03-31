import 'package:drift/drift.dart';

@DataClassName('AccountEntity')
class AccountsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text()(); // AccountType as simple string
  RealColumn get initialBalance => real().withDefault(const Constant(0.0))();
  TextColumn get currencyCode => text().withLength(min:3, max:3).withDefault(const Constant('ARS'))();
  TextColumn get iconName => text().nullable()();
  IntColumn get colorValue => integer().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  // Credit Cards specific
  RealColumn get creditLimit => real().nullable()();
  IntColumn get closingDay => integer().nullable()();
  IntColumn get dueDay => integer().nullable()();
  
  // Tracking for Statement Cycles (Cierre de Mes)
  RealColumn get pendingStatementAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get lastClosedDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
