import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';

/// Stream de gastos compartidos entrantes (que el amigo registró y yo no acepté)
final incomingSharedExpensesProvider =
    StreamProvider<List<IncomingSharedExpense>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.watchIncomingExpenses();
});

/// Conteo de gastos compartidos pendientes (para badge)
final incomingExpensesCountProvider = Provider<int>((ref) {
  return ref.watch(incomingSharedExpensesProvider).valueOrNull?.length ?? 0;
});
