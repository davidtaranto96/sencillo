import 'package:drift/drift.dart';

@DataClassName('GroupMemberEntity')
class GroupMembersTable extends Table {
  TextColumn get groupId => text()();
  TextColumn get personId => text()();

  @override
  Set<Column> get primaryKey => {groupId, personId};
}
