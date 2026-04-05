import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'mercado_pago_service.dart';

// ─── Keys ──────────────────────────────────────────────────────────────────────
const _syncedIdsKey = 'mp_synced_ids';
const _lastSyncKey = 'mp_last_sync_timestamp';
const _autoSyncKey = 'mp_auto_sync_enabled';
const _apiKeyPref = 'anthropic_api_key';

// ─── AI Classification result ──────────────────────────────────────────────────
class _AiClassification {
  final String type;     // 'income' | 'expense'
  final String category; // valid categoryId

  const _AiClassification({required this.type, required this.category});
}

// ─── Result model ──────────────────────────────────────────────────────────────
class MpSyncResult {
  final int imported;
  final int skipped;
  final int total;
  final int failed;
  final String accountId;

  const MpSyncResult({
    required this.imported,
    required this.skipped,
    required this.total,
    required this.failed,
    required this.accountId,
  });
}

// ─── Sync Service ──────────────────────────────────────────────────────────────
class MpSyncService {
  final AppDatabase db;
  final MercadoPagoService mpService;
  final int? userId;

  MpSyncService({required this.db, required this.mpService, this.userId});

  // ── Resolver / crear cuenta MP ────────────────────────────────────────────

  Future<String> resolveOrCreateMpAccount() async {
    // 1. Buscar por ID exacto
    final byId = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals('mp_ars')))
        .getSingleOrNull();
    if (byId != null) return byId.id;

    // 2. Buscar por nombre similar
    final all = await db.select(db.accountsTable).get();
    for (final a in all) {
      if (a.name.toLowerCase().contains('mercado pago') ||
          a.name.toLowerCase().contains('mercadopago')) {
        return a.id;
      }
    }

    // 3. Crear nueva
    await db.into(db.accountsTable).insert(
      AccountsTableCompanion.insert(
        id: 'mp_ars',
        name: 'Mercado Pago',
        type: 'bank',
        currencyCode: const drift.Value('ARS'),
        iconName: const drift.Value('account_balance_wallet'),
        colorValue: const drift.Value(0xFF00B1EA),
        initialBalance: const drift.Value(0),
      ),
    );
    return 'mp_ars';
  }

  // ── Tracking de IDs importados ────────────────────────────────────────────

  Future<Set<String>> getImportedMpIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_syncedIdsKey)?.toSet() ?? {};
  }

  Future<void> _saveImportedMpIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_syncedIdsKey, ids.toList());
  }

  // ── Categorización heurística ─────────────────────────────────────────────

  String categorizeSingle(String? description, bool isExpense) {
    if (description == null) {
      return isExpense ? 'other_expense' : 'other_income';
    }
    final d = description.toLowerCase();

    // Transporte
    if (d.contains('uber') ||
        d.contains('cabify') ||
        d.contains('didi') ||
        d.contains('sube') ||
        d.contains('peaje') ||
        d.contains('estacionamiento')) {
      return 'transport';
    }
    // Comida
    if (d.contains('rappi') ||
        d.contains('pedidosya') ||
        d.contains('mcdonald') ||
        d.contains('burger') ||
        d.contains('restaurant') ||
        d.contains('cafe') ||
        d.contains('almuerzo') ||
        d.contains('cena') ||
        d.contains('supermercado') ||
        d.contains('carrefour') ||
        d.contains('coto') ||
        d.contains('dia') ||
        d.contains('jumbo')) {
      return 'food';
    }
    // Entretenimiento
    if (d.contains('spotify') ||
        d.contains('netflix') ||
        d.contains('disney') ||
        d.contains('hbo') ||
        d.contains('youtube') ||
        d.contains('steam') ||
        d.contains('cine') ||
        d.contains('xbox') ||
        d.contains('playstation')) {
      return 'entertainment';
    }
    // Servicios
    if (d.contains('luz') ||
        d.contains('gas') ||
        d.contains('agua') ||
        d.contains('edenor') ||
        d.contains('edesur') ||
        d.contains('metrogas') ||
        d.contains('aysa') ||
        d.contains('telecentro') ||
        d.contains('personal') ||
        d.contains('claro') ||
        d.contains('movistar') ||
        d.contains('internet')) {
      return 'services';
    }
    // Salud
    if (d.contains('farmacia') ||
        d.contains('hospital') ||
        d.contains('osde') ||
        d.contains('swiss') ||
        d.contains('medic')) {
      return 'health';
    }
    // Educación
    if (d.contains('universidad') ||
        d.contains('curso') ||
        d.contains('udemy') ||
        d.contains('coursera')) {
      return 'education';
    }
    // Compras
    if (d.contains('mercadolibre') ||
        d.contains('amazon') ||
        d.contains('tienda') ||
        d.contains('ropa') ||
        d.contains('zara') ||
        d.contains('nike')) {
      return 'shopping';
    }
    // Sueldo / ingreso
    if (!isExpense) {
      if (d.contains('sueldo') ||
          d.contains('salario') ||
          d.contains('haberes')) {
        return 'salary';
      }
      if (d.contains('freelance') || d.contains('trabajo')) {
        return 'freelance';
      }
      return 'other_income';
    }

    return 'other_expense';
  }

  // ── Clasificación completa con IA (dirección + categoría) ───────────────

  /// La IA determina tanto la dirección como la categoría de cada movimiento.
  // ignore: library_private_types_in_public_api
  Future<Map<int, _AiClassification>> classifyBatchWithAI(
      List<MpMovement> movements) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyPref);
    if (apiKey == null || apiKey.isEmpty) return {};

    const validCategories = [
      'food', 'transport', 'health', 'entertainment', 'shopping',
      'home', 'education', 'services', 'salary', 'freelance',
      'other_expense', 'other_income',
    ];

    final result = <int, _AiClassification>{};

    for (var batchStart = 0; batchStart < movements.length; batchStart += 20) {
      final batchEnd = (batchStart + 20).clamp(0, movements.length);
      final batch = movements.sublist(batchStart, batchEnd);

      final lines = batch.asMap().entries.map((e) {
        final m = e.value;
        final opType = m.type;
        return '${e.key + 1}. desc="${m.description ?? 'Sin descripción'}" op_type="$opType" monto=\$${m.absAmount.toStringAsFixed(0)}';
      }).join('\n');

      try {
        final response = await http.post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': 'claude-haiku-4-5-20251001',
            'max_tokens': 512,
            'messages': [
              {
                'role': 'user',
                'content': '''Sos un asistente financiero argentino. Clasificá estos movimientos de Mercado Pago.
Para cada uno determiná:
- "type": "income" si es un ingreso (sueldo recibido, transferencia recibida, reintegro, venta, etc.)
         "expense" si es un egreso (compra, pago, propina, suscripción, servicio pagado, pago de tarjeta, etc.)
- "category": una de: ${validCategories.join(', ')}

Reglas clave:
- "Pago Tarjeta" / "Tarjeta" → expense, category=services
- "Propina" → expense, category=other_expense
- "Bank Transfer" recibido → income, category=other_income (si parece sueldo: salary)
- "Sueldo" / "Haberes" → income, category=salary
- Compras en comercios → expense, categoría según rubro
- Spotify/Netflix/etc → expense, category=entertainment
- Rappi/PedidosYa/etc → expense, category=food
- Uber/Cabify → expense, category=transport

Respondé SOLO un JSON array en orden, sin texto extra:
[{"type":"income","category":"salary"}, ...]

Movimientos:
$lines

Respuesta:''',
              }
            ],
          }),
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final content = body['content'] as List<dynamic>;
          final text = content.first['text'] as String;

          final match = RegExp(r'\[.*?\]', dotAll: true).firstMatch(text);
          if (match != null) {
            final raw = jsonDecode(match.group(0)!) as List<dynamic>;
            for (var i = 0; i < raw.length && i < batch.length; i++) {
              final item = raw[i] as Map<String, dynamic>;
              final type = item['type'] as String? ?? '';
              final cat = item['category'] as String? ?? '';
              if ((type == 'income' || type == 'expense') &&
                  validCategories.contains(cat)) {
                result[batchStart + i] = _AiClassification(
                  type: type,
                  category: cat,
                );
              }
            }
          }
        }
      } catch (_) {
        // Si falla la IA, el caller usa heurística
      }
    }

    return result;
  }

  // ── Categorización heurística simple ─────────────────────────────────────

  // ── Sync principal ────────────────────────────────────────────────────────

  Future<MpSyncResult> syncMovements({
    void Function(int current, int total)? onProgress,
  }) async {
    final accountId = await resolveOrCreateMpAccount();

    // Reparar saldo si fue corrompido por sync anterior
    await repairBalance(accountId);

    final importedIds = await getImportedMpIds();

    // Fetch últimos 50 movimientos aprobados de MP
    final movements = await mpService.fetchMovements(limit: 50, userId: userId);

    // Filtrar los que ya fueron importados
    final newMovements =
        movements.where((m) => !importedIds.contains(m.id)).toList();

    if (newMovements.isEmpty) {
      return MpSyncResult(
        imported: 0,
        skipped: movements.length,
        total: movements.length,
        failed: 0,
        accountId: accountId,
      );
    }

    // Clasificar con IA (dirección + categoría en un solo paso)
    final aiClassifications = await classifyBatchWithAI(newMovements);

    int imported = 0;
    int failed = 0;

    for (var i = 0; i < newMovements.length; i++) {
      final m = newMovements[i];
      onProgress?.call(i + 1, newMovements.length);

      try {
        final aiResult = aiClassifications[i];

        // IA determina dirección y categoría. Si no hay IA, usar heurística.
        final String type;
        final String categoryId;

        if (aiResult != null) {
          type = aiResult.type;
          categoryId = aiResult.category;
        } else {
          // Fallback heurístico: usar dirección de la API + categoría local
          type = m.isExpense ? 'expense' : 'income';
          categoryId = categorizeSingle(m.description, m.isExpense);
        }

        // Insertar como transacción real
        await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            id: const Uuid().v4(),
            title: m.description ?? 'Movimiento MP',
            amount: m.absAmount,
            type: type,
            categoryId: categoryId,
            accountId: accountId,
            date: m.date,
            note: drift.Value('mp_sync:${m.id}'),
          ),
        );

        importedIds.add(m.id);
        imported++;
      } catch (_) {
        failed++;
      }
    }

    // Guardar IDs importados
    await _saveImportedMpIds(importedIds);

    // Guardar timestamp de última sync
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

    return MpSyncResult(
      imported: imported,
      skipped: movements.length - newMovements.length,
      total: movements.length,
      failed: failed,
      accountId: accountId,
    );
  }

  // ── Reparar saldo ─────────────────────────────────────────────────────────

  /// Repara el initialBalance de la cuenta MP.
  /// Los movimientos de MP (mp_sync:) se excluyen del cálculo de balance,
  /// así que solo sumamos las transacciones NO-MP para determinar el
  /// initialBalance correcto.
  Future<void> repairBalance(String accountId) async {
    final txs = await (db.select(db.transactionsTable)
          ..where((t) => t.accountId.equals(accountId)))
        .get();

    // Solo contar transacciones que NO son de MP sync
    // (las manuales del usuario)
    double sumManualIncomes = 0;
    double sumManualExpenses = 0;

    for (final tx in txs) {
      if (tx.note != null && tx.note!.contains('[retroactivo]')) continue;
      if (tx.note != null && tx.note!.contains('mp_sync:')) continue;

      if (tx.type == 'income') {
        sumManualIncomes += tx.amount;
      } else if (tx.type == 'expense') {
        sumManualExpenses += tx.amount;
      } else if (tx.type == 'transfer') {
        sumManualExpenses += tx.amount;
      }
    }

    // Obtener el initialBalance actual
    final account = await (db.select(db.accountsTable)
          ..where((t) => t.id.equals(accountId)))
        .getSingleOrNull();

    if (account == null) return;

    // El balance mostrado = initialBalance + manualIncomes - manualExpenses
    // Si el initialBalance fue corrompido por syncBalance, lo reseteamos a 0
    // para que el balance = 0 + manualIncomes - manualExpenses
    // El usuario puede editarlo manualmente si necesita un valor distinto
    final currentShownBalance = account.initialBalance + sumManualIncomes - sumManualExpenses;

    // Si el balance es absurdamente alto (fue corrompido), resetear a 0
    if (currentShownBalance.abs() > 10000000) {
      await (db.update(db.accountsTable)
            ..where((t) => t.id.equals(accountId)))
          .write(const AccountsTableCompanion(
        initialBalance: drift.Value(0),
      ));
    }
  }

  // ── Borrar transacciones importadas ────────────────────────────────────────

  /// Elimina TODAS las transacciones importadas de MP (las que tienen mp_sync: en nota)
  /// y resetea los IDs importados. No toca transacciones manuales del usuario.
  Future<int> deleteImportedTransactions() async {
    // Obtener todas las transacciones con mp_sync: en la nota
    final allTxs = await db.select(db.transactionsTable).get();
    final mpTxs = allTxs.where(
        (tx) => tx.note != null && tx.note!.contains('mp_sync:')).toList();

    for (final tx in mpTxs) {
      await (db.delete(db.transactionsTable)
            ..where((t) => t.id.equals(tx.id)))
          .go();
    }

    // Limpiar IDs importados
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncedIdsKey);
    await prefs.remove(_lastSyncKey);

    // Reparar initialBalance de la cuenta MP
    final accountId = await resolveOrCreateMpAccount();
    await (db.update(db.accountsTable)
          ..where((t) => t.id.equals(accountId)))
        .write(const AccountsTableCompanion(
      initialBalance: drift.Value(0),
    ));

    return mpTxs.length;
  }

  // ── Limpiar datos de sync ─────────────────────────────────────────────────

  static Future<void> clearSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncedIdsKey);
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_autoSyncKey);
  }
}
