import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mercado_pago_service.dart';
import '../services/mp_sync_service.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

// ─── Keys de SharedPreferences ─────────────────────────────────────────────────
const _tokenKey = 'mp_access_token';
const _profileCacheKey = 'mp_profile_cache';
const _balanceCacheKey = 'mp_balance_cache';
const _balanceTimestampKey = 'mp_balance_timestamp';
const _movementsCacheKey = 'mp_movements_cache';
const _movementsTimestampKey = 'mp_movements_timestamp';
const _balanceTtlMinutes = 5;
const _movementsTtlMinutes = 15;
const _autoSyncKey = 'mp_auto_sync_enabled';
const _lastSyncKey = 'mp_last_sync_timestamp';

// ─── Sync state ───────────────────────────────────────────────────────────────

enum MpSyncState { idle, syncing, success, error }

final mpSyncStateProvider = StateProvider<MpSyncState>((ref) => MpSyncState.idle);
final mpSyncProgressProvider = StateProvider<String>((ref) => '');

final mpAutoSyncEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_autoSyncKey) ?? true; // habilitado por defecto
});

Future<void> setMpAutoSync(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_autoSyncKey, enabled);
}

final mpLastSyncProvider = FutureProvider<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final ts = prefs.getString(_lastSyncKey);
  return ts != null ? DateTime.tryParse(ts) : null;
});

final mpSyncedIdsProvider = FutureProvider<Set<String>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('mp_synced_ids')?.toSet() ?? {};
});

// ─── Linked Account ───────────────────────────────────────────────────────────
const _linkedAccountKey = 'mp_linked_account_id';

/// ID of the local account linked to Mercado Pago (null if none).
/// Falls back to searching by ID 'mp_ars' or by name containing 'mercado pago'.
final mpLinkedAccountIdProvider = FutureProvider<String?>((ref) async {
  ref.watch(_mpRefreshCounter);
  final prefs = await SharedPreferences.getInstance();

  // 1. Explicit saved link
  final explicit = prefs.getString(_linkedAccountKey);
  if (explicit != null) return explicit;

  // 2. Only search further if MP is connected
  final token = prefs.getString(_tokenKey);
  if (token == null || token.isEmpty) return null;

  // 3. Search DB for mp_ars or by name
  final db = ref.read(databaseProvider);
  final byId = await (db.select(db.accountsTable)
        ..where((t) => t.id.equals('mp_ars')))
      .getSingleOrNull();
  if (byId != null) {
    await prefs.setString(_linkedAccountKey, byId.id);
    return byId.id;
  }

  // 4. Search by name containing "mercado pago"
  final all = await db.select(db.accountsTable).get();
  for (final a in all) {
    if (a.name.toLowerCase().contains('mercado pago') ||
        a.name.toLowerCase().contains('mercadopago')) {
      await prefs.setString(_linkedAccountKey, a.id);
      return a.id;
    }
  }

  return null;
});

/// Persist which local account is linked to MP.
Future<void> setMpLinkedAccountId(String accountId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_linkedAccountKey, accountId);
}

/// Clear the linked account (on disconnect).
Future<void> clearMpLinkedAccountId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_linkedAccountKey);
}

// ─── Token storage ─────────────────────────────────────────────────────────────

/// Whether MP is connected (token exists)
final mpConnectedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_tokenKey);
  return token != null && token.isNotEmpty;
});

/// Refresh counter para forzar re-fetch
final _mpRefreshCounter = StateProvider<int>((ref) => 0);

/// Obtiene el userId guardado en cache de perfil
Future<int?> _getCachedUserId() async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_profileCacheKey);
  if (cached != null) {
    final data = jsonDecode(cached) as Map<String, dynamic>;
    return data['id'] as int?;
  }
  return null;
}

/// Guarda el access token y valida que funcione
Future<MpUserProfile> connectMercadoPago(String token) async {
  final service = MercadoPagoService(accessToken: token);
  // Validar que el token sirva
  final profile = await service.fetchUserProfile();

  // Guardar token y perfil
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_tokenKey, token);
  await prefs.setString(_profileCacheKey, jsonEncode({
    'id': profile.id,
    'first_name': profile.firstName,
    'last_name': profile.lastName,
    'email': profile.email,
    'nickname': profile.nickname,
  }));

  return profile;
}

/// Desconecta MP: borra token, cache y datos de sync
Future<void> disconnectMercadoPago() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_tokenKey);
  await prefs.remove(_profileCacheKey);
  await prefs.remove(_balanceCacheKey);
  await prefs.remove(_balanceTimestampKey);
  await prefs.remove(_movementsCacheKey);
  await prefs.remove(_movementsTimestampKey);
  await clearMpLinkedAccountId();
  await MpSyncService.clearSyncData();
}

/// Obtiene el service con el token guardado (null si no hay)
Future<MercadoPagoService?> _getService() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_tokenKey);
  if (token == null || token.isEmpty) return null;
  return MercadoPagoService(accessToken: token);
}

// ─── Perfil del usuario MP ─────────────────────────────────────────────────────

final mpProfileProvider = FutureProvider<MpUserProfile?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_profileCacheKey);
  if (cached != null) {
    final data = jsonDecode(cached) as Map<String, dynamic>;
    return MpUserProfile.fromJson(data);
  }
  return null;
});

// ─── Balance con cache de 5 min ────────────────────────────────────────────────

final mpBalanceProvider = FutureProvider.autoDispose<MpBalance?>((ref) async {
  ref.watch(_mpRefreshCounter);
  final service = await _getService();
  if (service == null) return null;

  final prefs = await SharedPreferences.getInstance();

  // Intentar cache
  final tsStr = prefs.getString(_balanceTimestampKey);
  if (tsStr != null) {
    final ts = DateTime.tryParse(tsStr);
    if (ts != null &&
        DateTime.now().difference(ts).inMinutes < _balanceTtlMinutes) {
      final cached = prefs.getString(_balanceCacheKey);
      if (cached != null) {
        return MpBalance.fromJson(
            jsonDecode(cached) as Map<String, dynamic>);
      }
    }
  }

  // Fetch fresco
  try {
    final userId = await _getCachedUserId();
    final balance = await service.fetchBalance(userId: userId);
    if (balance != null) {
      await prefs.setString(_balanceCacheKey, jsonEncode({
        'available_balance': balance.availableBalance,
        'total_amount': balance.totalAmount,
        'unavailable_balance': balance.unavailableAmount,
        'currency_id': balance.currencyId,
      }));
      await prefs.setString(
          _balanceTimestampKey, DateTime.now().toIso8601String());
    }
    return balance;
  } catch (_) {
    // Si falla, devolver cache viejo
    final cached = prefs.getString(_balanceCacheKey);
    if (cached != null) {
      return MpBalance.fromJson(
          jsonDecode(cached) as Map<String, dynamic>);
    }
    return null; // No disponible
  }
});

// ─── Movimientos con cache de 15 min ───────────────────────────────────────────

final mpMovementsProvider =
    FutureProvider.autoDispose<List<MpMovement>>((ref) async {
  ref.watch(_mpRefreshCounter);
  final service = await _getService();
  if (service == null) return [];

  final prefs = await SharedPreferences.getInstance();
  final userId = await _getCachedUserId();

  // Intentar cache
  final tsStr = prefs.getString(_movementsTimestampKey);
  if (tsStr != null) {
    final ts = DateTime.tryParse(tsStr);
    if (ts != null &&
        DateTime.now().difference(ts).inMinutes < _movementsTtlMinutes) {
      final cached = prefs.getString(_movementsCacheKey);
      if (cached != null) {
        final list = jsonDecode(cached) as List<dynamic>;
        return list
            .map((e) =>
                MpMovement.fromCacheJson(e as Map<String, dynamic>))
            .toList();
      }
    }
  }

  // Fetch fresco
  try {
    final movements = await service.fetchMovements(limit: 50, userId: userId);
    await prefs.setString(
        _movementsCacheKey,
        jsonEncode(movements.map((m) => m.toJson()).toList()));
    await prefs.setString(
        _movementsTimestampKey, DateTime.now().toIso8601String());
    return movements;
  } catch (_) {
    // Cache viejo
    final cached = prefs.getString(_movementsCacheKey);
    if (cached != null) {
      final list = jsonDecode(cached) as List<dynamic>;
      return list
          .map((e) =>
              MpMovement.fromCacheJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
});

/// Fuerza refresh de balance y movimientos
void refreshMercadoPago(WidgetRef ref) {
  _clearMpCache();
  ref.read(_mpRefreshCounter.notifier).state++;
}

Future<void> _clearMpCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_balanceTimestampKey);
  await prefs.remove(_balanceCacheKey);
  await prefs.remove(_movementsTimestampKey);
  await prefs.remove(_movementsCacheKey);
}

// ─── Sync completo ────────────────────────────────────────────────────────────

/// Ejecuta sincronización de movimientos + balance.
/// Retorna el resultado o null si no hay conexión.
Future<MpSyncResult?> syncMercadoPago(WidgetRef ref, {String? targetAccountId}) async {
  final service = await _getService();
  if (service == null) return null;

  ref.read(mpSyncStateProvider.notifier).state = MpSyncState.syncing;
  ref.read(mpSyncProgressProvider.notifier).state = 'Iniciando sync...';

  try {
    final db = ref.read(databaseProvider);
    final userId = await _getCachedUserId();
    final syncService = MpSyncService(
      db: db,
      mpService: service,
      userId: userId,
      targetAccountId: targetAccountId,
    );

    final result = await syncService.syncMovements(
      onProgress: (current, total) {
        ref.read(mpSyncProgressProvider.notifier).state =
            'Importando $current de $total...';
      },
    );

    // Persist linked account ID
    await setMpLinkedAccountId(result.accountId);

    // Refresh cache
    _clearMpCache();
    ref.read(_mpRefreshCounter.notifier).state++;

    ref.read(mpSyncStateProvider.notifier).state = MpSyncState.success;
    ref.read(mpSyncProgressProvider.notifier).state = '';
    ref.invalidate(mpLastSyncProvider);
    ref.invalidate(mpSyncedIdsProvider);

    return result;
  } catch (e) {
    ref.read(mpSyncStateProvider.notifier).state = MpSyncState.error;
    ref.read(mpSyncProgressProvider.notifier).state = 'Error: $e';
    return null;
  }
}

// ─── Insights de transacciones MP en DB ──────────────────────────────────────

class MpInsights {
  final int totalImported;
  final double totalExpenses;
  final double totalIncomes;
  final Map<String, double> expensesByCategory;
  final String topCategory;

  const MpInsights({
    required this.totalImported,
    required this.totalExpenses,
    required this.totalIncomes,
    required this.expensesByCategory,
    required this.topCategory,
  });
}

final mpInsightsProvider = FutureProvider<MpInsights?>((ref) async {
  final db = ref.watch(databaseProvider);
  final allTxs = await db.select(db.transactionsTable).get();
  final mpTxs = allTxs.where(
      (tx) => tx.note != null && tx.note!.contains('mp_sync:')).toList();

  if (mpTxs.isEmpty) return null;

  double totalExpenses = 0;
  double totalIncomes = 0;
  final expensesByCategory = <String, double>{};

  for (final tx in mpTxs) {
    if (tx.type == 'expense') {
      totalExpenses += tx.amount;
      expensesByCategory[tx.categoryId] =
          (expensesByCategory[tx.categoryId] ?? 0) + tx.amount;
    } else if (tx.type == 'income') {
      totalIncomes += tx.amount;
    }
  }

  final topCategory = expensesByCategory.isEmpty
      ? 'other_expense'
      : (expensesByCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;

  return MpInsights(
    totalImported: mpTxs.length,
    totalExpenses: totalExpenses,
    totalIncomes: totalIncomes,
    expensesByCategory: expensesByCategory,
    topCategory: topCategory,
  );
});

/// Invierte el tipo (income↔expense) de una transacción MP importada
Future<void> flipMpTransactionType(WidgetRef ref, String txId, String currentType) async {
  final db = ref.read(databaseProvider);
  final newType = currentType == 'income' ? 'expense' : 'income';
  await (db.update(db.transactionsTable)
        ..where((t) => t.id.equals(txId)))
      .write(TransactionsTableCompanion(
    type: drift.Value(newType),
  ));
}

/// Borra todas las transacciones importadas de MP y resetea sync
Future<int> clearMpImports(WidgetRef ref) async {
  final service = await _getService();
  if (service == null) return 0;

  final db = ref.read(databaseProvider);
  final userId = await _getCachedUserId();
  final syncService = MpSyncService(db: db, mpService: service, userId: userId);
  final deleted = await syncService.deleteImportedTransactions();

  ref.invalidate(mpSyncedIdsProvider);
  ref.invalidate(mpLastSyncProvider);
  ref.read(mpSyncStateProvider.notifier).state = MpSyncState.idle;
  ref.read(mpSyncProgressProvider.notifier).state = '';

  return deleted;
}

/// Sync silencioso para auto-sync (usa Ref genérico)
Future<void> autoSyncMercadoPago(dynamic db) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_tokenKey);
  if (token == null || token.isEmpty) return;

  final autoSync = prefs.getBool(_autoSyncKey) ?? true;
  if (!autoSync) return;

  // Cooldown 15 min
  final lastSync = prefs.getString(_lastSyncKey);
  if (lastSync != null) {
    final ts = DateTime.tryParse(lastSync);
    if (ts != null && DateTime.now().difference(ts).inMinutes < 15) return;
  }

  try {
    final userId = await _getCachedUserId();
    final service = MercadoPagoService(accessToken: token);
    final syncService = MpSyncService(db: db as AppDatabase, mpService: service, userId: userId);
    await syncService.syncMovements();
  } catch (_) {
    // Silencioso — no interrumpir al usuario
  }
}
