import 'package:equatable/equatable.dart';

import 'person.dart';

class ExpenseGroup extends Equatable {
  final String id;
  final String name;
  final List<Person> members;
  final String? coverImageUrl;
  final double totalGroupExpense; // Total gastado en el grupo

  const ExpenseGroup({
    required this.id,
    required this.name,
    this.members = const [],
    this.coverImageUrl,
    this.totalGroupExpense = 0.0,
  });

  @override
  List<Object?> get props => [id, name, members];
}
