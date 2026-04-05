import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado global de búsqueda en la pestaña de Movimientos
final txSearchActiveProvider = StateProvider<bool>((ref) => false);
final txSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtro global de tipo de transacción (accesible desde home para pre-filtrar)
enum TxFilterType { all, income, expense, shared }
final txFilterProvider = StateProvider<TxFilterType>((ref) => TxFilterType.all);

/// Request navigation to a specific tab by ID (e.g. 'transactions')
/// Shell watches this and jumps the PageView accordingly, then resets to null.
final navigateToTabProvider = StateProvider<String?>((ref) => null);
