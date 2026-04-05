import 'package:equatable/equatable.dart';

import 'person.dart';

class ExpenseGroup extends Equatable {
  final String id;
  final String name;
  final List<Person> members;
  final String? coverImageUrl;
  final double totalGroupExpense;
  final DateTime? startDate;
  final DateTime? endDate;

  const ExpenseGroup({
    required this.id,
    required this.name,
    this.members = const [],
    this.coverImageUrl,
    this.totalGroupExpense = 0.0,
    this.startDate,
    this.endDate,
  });

  bool get hasDates => startDate != null || endDate != null;

  @override
  List<Object?> get props => [id, name, members, startDate, endDate];
}
