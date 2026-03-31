import 'package:equatable/equatable.dart';

enum CategoryType { income, expense }

class Category extends Equatable {
  final String id;
  final String name;
  final CategoryType type;
  final String icon;
  final String color;  // hex

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  @override
  List<Object?> get props => [id, name, type];
}

/// Categorías por defecto del sistema
class DefaultCategories {
  static const expense = [
    Category(id: 'food', name: 'Comida', type: CategoryType.expense, icon: '🍔', color: '#FF6B6B'),
    Category(id: 'transport', name: 'Transporte', type: CategoryType.expense, icon: '🚗', color: '#4ECDC4'),
    Category(id: 'health', name: 'Salud', type: CategoryType.expense, icon: '🏥', color: '#45B7D1'),
    Category(id: 'entertainment', name: 'Entretenimiento', type: CategoryType.expense, icon: '🎬', color: '#96CEB4'),
    Category(id: 'shopping', name: 'Compras', type: CategoryType.expense, icon: '🛍️', color: '#FFEAA7'),
    Category(id: 'home', name: 'Hogar', type: CategoryType.expense, icon: '🏠', color: '#DDA0DD'),
    Category(id: 'education', name: 'Educación', type: CategoryType.expense, icon: '📚', color: '#98D8C8'),
    Category(id: 'other_expense', name: 'Otro', type: CategoryType.expense, icon: '💸', color: '#B8C4C2'),
  ];

  static const income = [
    Category(id: 'salary', name: 'Sueldo', type: CategoryType.income, icon: '💼', color: '#5ECFB1'),
    Category(id: 'freelance', name: 'Freelance', type: CategoryType.income, icon: '💻', color: '#7C6EF7'),
    Category(id: 'investment_income', name: 'Inversiones', type: CategoryType.income, icon: '📈', color: '#FFB347'),
    Category(id: 'other_income', name: 'Otro ingreso', type: CategoryType.income, icon: '💰', color: '#B8C4C2'),
  ];
}
