import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/wishlist_item.dart';

class WishlistNotifier extends StateNotifier<List<WishlistItem>> {
  WishlistNotifier() : super(_initialData);

  static final List<WishlistItem> _initialData = [
    WishlistItem(
      id: 'w1',
      title: 'PlayStation 5 Pro',
      estimatedCost: 1200000,
      createdAt: DateTime.now().subtract(const Duration(days: 9)), 
      note: 'Para jugar al GTA VI',
    ),
    WishlistItem(
      id: 'w2',
      title: 'Zapatillas Running',
      estimatedCost: 180000,
      createdAt: DateTime.now().subtract(const Duration(days: 2)), 
      note: 'Las viejas ya están rotas',
    ),
    WishlistItem(
      id: 'w3',
      title: 'Silla Ergonómica',
      estimatedCost: 450000,
      createdAt: DateTime.now().subtract(const Duration(days: 15)), 
    ),
  ];

  void add(WishlistItem item) {
    state = [item, ...state];
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void updateItem(WishlistItem updatedItem) {
    state = state.map((item) => item.id == updatedItem.id ? updatedItem : item).toList();
  }
}

final mockWishlistProvider = StateNotifierProvider<WishlistNotifier, List<WishlistItem>>((ref) {
  return WishlistNotifier();
});

final safeBudgetProvider = StateProvider<double>((ref) => 350000.0);

// Sueldo mock para calcular "horas de vida" / "horas de trabajo"
final mockHourlyRateProvider = Provider<double>((ref) {
  // Suponiendo un sueldo de 1.200.000 trabajando 160hs al mes
  // 1.200.000 / 160 = 7500 pesos la hora.
  return 7500.0;
});
