import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transactions/domain/models/transaction.dart';
import '../../features/transactions/presentation/widgets/add_transaction_bottom_sheet.dart' show kCategoryEmojis;
import '../database/database_providers.dart';

/// Sprint 3.15 — Sugerencias contextuales para el textbox IA.
///
/// Cuando el textfield está vacío, mostrar 3-4 chips clickeables que llenan
/// el input con un texto pre-armado. La lógica combina:
///   1. Historial reciente (top 2 categorías de los últimos 30 días).
///   2. Momento del día (viernes >19hs → "Salida"; día 1 → "Alquiler"; etc.).
///   3. Día de cobro detectado → "Sueldo".
class AiSuggestion {
  final String emoji;
  final String label;     // chip visible
  final String input;     // se inyecta en el textfield al tap
  const AiSuggestion({required this.emoji, required this.label, required this.input});
}

/// Provider público — devuelve max 4 sugerencias relevantes al momento.
final aiSuggestionsProvider = Provider<List<AiSuggestion>>((ref) {
  final txAsync = ref.watch(transactionsStreamProvider);
  final txs = txAsync.valueOrNull ?? const <Transaction>[];
  final profile = ref.watch(userProfileStreamProvider).valueOrNull;
  final now = DateTime.now();

  final suggestions = <AiSuggestion>[];

  // ── 1) Día de cobro ──
  if (profile?.payDay != null && now.day == profile!.payDay) {
    final salary = profile.monthlySalary ?? 0;
    suggestions.add(AiSuggestion(
      emoji: '💰',
      label: 'Sueldo',
      input: salary > 0 ? 'sueldo $salary' : 'sueldo',
    ));
  }

  // ── 2) Día 1 del mes → alquiler / expensas ──
  if (now.day == 1) {
    suggestions.add(const AiSuggestion(
      emoji: '🏠',
      label: 'Alquiler',
      input: 'alquiler',
    ));
  }

  // ── 3) Viernes/sábado >19hs → salida ──
  if ((now.weekday == DateTime.friday || now.weekday == DateTime.saturday) &&
      now.hour >= 19) {
    suggestions.add(const AiSuggestion(
      emoji: '🍻',
      label: 'Salida',
      input: 'salida con amigos',
    ));
  }

  // ── 4) Top categorías de los últimos 30 días ──
  final cutoff = now.subtract(const Duration(days: 30));
  final byCat = <String, _CatStats>{};
  for (final t in txs) {
    if (t.type != TransactionType.expense) continue;
    if (t.date.isBefore(cutoff)) continue;
    final stats = byCat.putIfAbsent(t.categoryId, () => _CatStats());
    stats.add(t.amount);
  }
  if (byCat.isNotEmpty) {
    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));
    for (final entry in sorted.take(2)) {
      final emoji = kCategoryEmojis[entry.key] ?? '💸';
      final label = _categoryDisplayName(entry.key);
      final avg = entry.value.average.round();
      suggestions.add(AiSuggestion(
        emoji: emoji,
        label: '$label \$$avg',
        input: '${label.toLowerCase()} $avg',
      ));
    }
  }

  // Limitar a 4 — y de-duplicar por emoji+label.
  final seen = <String>{};
  final unique = <AiSuggestion>[];
  for (final s in suggestions) {
    final key = '${s.emoji}|${s.label}';
    if (seen.add(key)) unique.add(s);
    if (unique.length >= 4) break;
  }
  return unique;
});

class _CatStats {
  int count = 0;
  double total = 0;
  void add(double amount) {
    count++;
    total += amount;
  }
  double get average => count == 0 ? 0 : total / count;
}

const _kCategoryNames = <String, String>{
  'food': 'Comida',
  'transport': 'Transporte',
  'health': 'Salud',
  'entertainment': 'Ocio',
  'shopping': 'Compras',
  'home': 'Hogar',
  'education': 'Educación',
  'services': 'Servicios',
  'cat_alim': 'Súper',
  'cat_transp': 'Transporte',
  'cat_entret': 'Ocio',
  'cat_salud': 'Salud',
  'cat_delivery': 'Delivery',
  'cat_subs': 'Suscripciones',
  'cat_tecno': 'Tecno',
  'cat_ropa': 'Ropa',
  'cat_hogar': 'Hogar',
  'cat_otros_gasto': 'Otros',
};

String _categoryDisplayName(String id) => _kCategoryNames[id] ?? 'Gasto';
