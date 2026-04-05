import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cotización individual (compra / venta)
class CurrencyRate {
  final String casa;    // 'blue', 'oficial', 'mep', 'ccl', 'tarjeta'
  final String label;   // "Dólar Blue", "Oficial", etc.
  final double compra;
  final double venta;
  final DateTime updatedAt;

  const CurrencyRate({
    required this.casa,
    required this.label,
    required this.compra,
    required this.venta,
    required this.updatedAt,
  });

  factory CurrencyRate.fromJson(Map<String, dynamic> json) {
    return CurrencyRate(
      casa: (json['casa'] as String? ?? '').toLowerCase(),
      label: _labelFor(json['nombre'] as String? ?? json['casa'] as String? ?? ''),
      compra: (json['compra'] as num?)?.toDouble() ?? 0,
      venta: (json['venta'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.tryParse(json['fechaActualizacion'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static String _labelFor(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('blue')) return 'Blue';
    if (n.contains('oficial') || n.contains('minorista')) return 'Oficial';
    if (n.contains('tarjeta') || n.contains('turista') || n.contains('solidario')) return 'Tarjeta';
    if (n.contains('mep') || n.contains('bolsa')) return 'MEP';
    if (n.contains('ccl') || n.contains('contado')) return 'CCL';
    if (n.contains('cripto')) return 'Cripto';
    if (n.contains('mayorista')) return 'Mayorista';
    return nombre;
  }
}

const _cacheKey = 'currency_rates_cache';
const _cacheTimestampKey = 'currency_rates_timestamp';
const _cacheTtlMinutes = 5;

/// Counter que se incrementa al hacer refresh manual para invalidar el provider
final _currencyRefreshCounter = StateProvider<int>((ref) => 0);

/// FutureProvider con caché de 5 minutos en SharedPreferences.
/// Fuente: dolarapi.com (sin auth, gratuita)
final currencyRatesProvider = FutureProvider.autoDispose<List<CurrencyRate>>((ref) {
  // Watch del counter para que se re-ejecute al hacer refresh manual
  ref.watch(_currencyRefreshCounter);
  return _fetchRates();
});

/// Forzar refresh manual de cotizaciones (ignora caché)
void refreshCurrencyRates(WidgetRef ref) {
  _clearCache();
  ref.read(_currencyRefreshCounter.notifier).state++;
}

/// Forzar refresh manual desde un Ref genérico (para auto-refresh timer)
void refreshCurrencyRatesFromRef(Ref ref) {
  _clearCache();
  ref.read(_currencyRefreshCounter.notifier).state++;
}

Future<void> _clearCache() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_cacheTimestampKey);
  await prefs.remove(_cacheKey);
}

Future<List<CurrencyRate>> _fetchRates() async {
  final prefs = await SharedPreferences.getInstance();

  // ── Intentar cache ──
  final tsStr = prefs.getString(_cacheTimestampKey);
  if (tsStr != null) {
    final ts = DateTime.tryParse(tsStr);
    if (ts != null && DateTime.now().difference(ts).inMinutes < _cacheTtlMinutes) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        return _parseRates(cached);
      }
    }
  }

  // ── Fetch fresco ──
  final response = await http
      .get(Uri.parse('https://dolarapi.com/v1/dolares'))
      .timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}');
  }

  // Guardar en cache
  await prefs.setString(_cacheKey, response.body);
  await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());

  return _parseRates(response.body);
}

List<CurrencyRate> _parseRates(String body) {
  final list = jsonDecode(body) as List<dynamic>;
  final rates = list
      .map((e) => CurrencyRate.fromJson(e as Map<String, dynamic>))
      .where((r) => r.venta > 0)
      .toList();

  // Orden preferido: Blue primero, luego Oficial, Tarjeta, MEP, CCL
  const order = ['blue', 'oficial', 'tarjeta', 'mep', 'ccl', 'mayorista', 'cripto'];
  rates.sort((a, b) {
    final ai = order.contains(a.casa) ? order.indexOf(a.casa) : 999;
    final bi = order.contains(b.casa) ? order.indexOf(b.casa) : 999;
    return ai.compareTo(bi);
  });

  return rates;
}
