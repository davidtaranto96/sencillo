/// Sprint 3.14 — Diccionario de comercios argentinos → categoría.
///
/// Match por substring lowercase. Cuando el usuario escribe "uber 25k", el
/// parser intenta resolver categoría con [resolveCategoryFromText] antes de
/// caer al fallback regex/Haiku.
///
/// El IDs de categoría coinciden con los de `database_seeder.dart`.
library;

const Map<String, String> kMerchantToCategory = {
  // ── Supermercado ──
  'coto': 'cat_alim',
  'disco': 'cat_alim',
  'jumbo': 'cat_alim',
  'carrefour': 'cat_alim',
  'changomas': 'cat_alim',
  'changomás': 'cat_alim',
  'dia': 'cat_alim',
  'día': 'cat_alim',
  'super': 'cat_alim',
  'lucciano': 'cat_alim',
  'walmart': 'cat_alim',
  'vea': 'cat_alim',
  'la anonima': 'cat_alim',
  'la anónima': 'cat_alim',
  'mercado central': 'cat_alim',

  // ── Comida / Resto ──
  'mostaza': 'food',
  'mcdonald': 'food',
  'burger king': 'food',
  'kfc': 'food',
  'subway': 'food',
  'starbucks': 'food',
  'havanna': 'food',
  'almuerzo': 'food',
  'cena': 'food',
  'desayuno': 'food',
  'merienda': 'food',
  'café': 'food',
  'cafe': 'food',
  'pizza': 'food',
  'parrilla': 'food',
  'restaurante': 'food',
  'resto': 'food',

  // ── Transporte ──
  'sube': 'cat_transp',
  'uber': 'cat_transp',
  'didi': 'cat_transp',
  'cabify': 'cat_transp',
  'taxi': 'cat_transp',
  'remis': 'cat_transp',
  'colectivo': 'cat_transp',
  'subte': 'cat_transp',
  'tren': 'cat_transp',
  'ypf': 'cat_transp',
  'shell': 'cat_transp',
  'puma': 'cat_transp',
  'axion': 'cat_transp',
  'estación de servicio': 'cat_transp',
  'nafta': 'cat_transp',
  'gnc': 'cat_transp',
  'peaje': 'cat_transp',

  // ── Delivery ──
  'rappi': 'cat_delivery',
  'pedidosya': 'cat_delivery',
  'pedidos ya': 'cat_delivery',
  'pedidos': 'cat_delivery',

  // ── Suscripciones / Streaming ──
  'netflix': 'cat_subs',
  'spotify': 'cat_subs',
  'disney': 'cat_subs',
  'hbo': 'cat_subs',
  'apple tv': 'cat_subs',
  'apple music': 'cat_subs',
  'amazon prime': 'cat_subs',
  'paramount': 'cat_subs',
  'youtube premium': 'cat_subs',
  'duolingo': 'cat_subs',
  'chatgpt': 'cat_subs',
  'claude': 'cat_subs',
  'github copilot': 'cat_subs',

  // ── Servicios (luz, gas, agua, internet, telefonía) ──
  'edesur': 'cat_services',
  'edenor': 'cat_services',
  'eden': 'cat_services',
  'metrogas': 'cat_services',
  'naturgy': 'cat_services',
  'aysa': 'cat_services',
  'movistar': 'cat_services',
  'personal': 'cat_services',
  'claro': 'cat_services',
  'telecom': 'cat_services',
  'fibertel': 'cat_services',
  'telecentro': 'cat_services',
  'expensas': 'cat_services',
  'alquiler': 'cat_services',

  // ── Salud ──
  'farmacia': 'cat_salud',
  'farmacity': 'cat_salud',
  'farmaplus': 'cat_salud',
  'osde': 'cat_salud',
  'galeno': 'cat_salud',
  'swiss medical': 'cat_salud',
  'medico': 'cat_salud',
  'médico': 'cat_salud',
  'odontologo': 'cat_salud',
  'odontólogo': 'cat_salud',
  'kinesiólogo': 'cat_salud',
  'kinesiologo': 'cat_salud',
  'psicólogo': 'cat_salud',
  'psicologo': 'cat_salud',

  // ── Tecnología ──
  'mercadolibre': 'cat_tecno',
  'mercado libre': 'cat_tecno',
  'apple': 'cat_tecno',
  'samsung': 'cat_tecno',
  'tienda diggit': 'cat_tecno',
  'tiendadiggit': 'cat_tecno',

  // ── Entretenimiento ──
  'cine': 'cat_entret',
  'cinemark': 'cat_entret',
  'hoyts': 'cat_entret',
  'showcase': 'cat_entret',
  'teatro': 'cat_entret',
  'concierto': 'cat_entret',
  'recital': 'cat_entret',

  // ── Ropa ──
  'zara': 'cat_ropa',
  'h&m': 'cat_ropa',
  'levi': 'cat_ropa',
  'nike': 'cat_ropa',
  'adidas': 'cat_ropa',
  'topper': 'cat_ropa',
  'kevingston': 'cat_ropa',
};

/// Devuelve el categoryId que mejor matchea el texto, o null si ninguno.
/// Match: substring lowercase. El primer match gana (orden del mapa).
String? resolveCategoryFromText(String text) {
  final lower = text.toLowerCase();
  for (final entry in kMerchantToCategory.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Devuelve un offset de días según palabras temporales del input.
/// Ejemplo: "ayer cine" → -1, "antes de ayer" → -2, "lunes" → último lunes.
/// Devuelve 0 si no detecta nada (= hoy).
int parseDateOffset(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('antes de ayer') || lower.contains('anteayer')) return -2;
  if (lower.contains('ayer')) return -1;
  if (lower.contains('hoy')) return 0;

  const weekdays = {
    'lunes': DateTime.monday,
    'martes': DateTime.tuesday,
    'miércoles': DateTime.wednesday,
    'miercoles': DateTime.wednesday,
    'jueves': DateTime.thursday,
    'viernes': DateTime.friday,
    'sábado': DateTime.saturday,
    'sabado': DateTime.saturday,
    'domingo': DateTime.sunday,
  };
  for (final entry in weekdays.entries) {
    if (lower.contains(entry.key)) {
      final now = DateTime.now();
      final today = now.weekday;
      var diff = today - entry.value;
      if (diff < 0) diff += 7;
      // Si es el mismo día, asumir hoy (offset 0)
      return -diff;
    }
  }
  return 0;
}

/// Detecta hints de cuenta: "con tarjeta" → 'credit', "en efectivo" → 'cash',
/// "MP"/"mercado pago" → 'mp_linked', "del banco" → 'bank'.
String? resolveAccountHintFromText(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('mercado pago') || RegExp(r'\bmp\b').hasMatch(lower)) {
    return 'mp_linked';
  }
  if (lower.contains('efectivo')) return 'cash';
  if (lower.contains('crédito') || lower.contains('credito') ||
      lower.contains('tarjeta de cred') || lower.contains('con tarjeta')) {
    return 'credit';
  }
  if (lower.contains('débito') || lower.contains('debito') ||
      lower.contains('del banco')) {
    return 'bank';
  }
  return null;
}

/// Detecta hint de moneda foreign: "usd", "us\$", "dólar", "dolar".
bool isForeignCurrencyText(String text) {
  final lower = text.toLowerCase();
  return RegExp(r'\b(usd|us\$|d[óo]lar(?:es)?)\b').hasMatch(lower);
}
