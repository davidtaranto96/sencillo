import 'package:drift/drift.dart';

@DataClassName('TransactionEntity')
class TransactionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  RealColumn get amount => real()();
  // We'll store TransactionType as an integer using Drift's type converters later, 
  // or simply as text. Let's use text for simplicity and robustness.
  TextColumn get type => text()(); 
  
  TextColumn get categoryId => text()(); // Should be a foreign key to Categories
  TextColumn get accountId => text()();  // Should be a foreign key to Accounts
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  
  TextColumn get personId => text().nullable()(); // FK to Persons
  TextColumn get groupId => text().nullable()();  // FK to Groups

  // Shared Expenses fields
  RealColumn get sharedTotalAmount => real().nullable()();
  RealColumn get sharedOwnAmount => real().nullable()();
  RealColumn get sharedOtherAmount => real().nullable()();
  RealColumn get sharedRecovered => real().nullable()();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
