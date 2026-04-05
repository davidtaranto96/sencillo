import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/parsed_transaction.dart';

/// Motor de ingesta de resúmenes de tarjeta de crédito ICBC (Visa y Mastercard).
///
/// Soporta:
///  - Mastercard ICBC: "DD-Mon-YY DESCRIPCION [CC/TT] NNNNN MONTO"
///  - Visa ICBC: "DD Mon DD NNNNNN * DESCRIPCION [REF] MONTO"
class PdfParserService {
  PdfParserService._();

  // ─── Categorías sugeridas por keywords ───────────────────────────────────

  static const Map<String, _CategoryHint> _keywordMap = {
    // ── Delivery ──────────────────────────────────────────────────────
    'PEDIDOSYA': _CategoryHint('cat_delivery', 'Delivery'),
    'RAPPI': _CategoryHint('cat_delivery', 'Delivery'),
    'GLOVO': _CategoryHint('cat_delivery', 'Delivery'),

    // ── Suscripciones / Streaming ────────────────────────────────────
    'MEMBRESIA': _CategoryHint('cat_subs', 'Suscripción'),
    'DISNEY PLUS': _CategoryHint('cat_subs', 'Streaming'),
    'DISNEY': _CategoryHint('cat_subs', 'Streaming'),
    'NETFLIX': _CategoryHint('cat_subs', 'Streaming'),
    'SPOTIFY': _CategoryHint('cat_subs', 'Streaming'),
    'HBO': _CategoryHint('cat_subs', 'Streaming'),
    'PARAMOUNT': _CategoryHint('cat_subs', 'Streaming'),
    'AMAZON PRIME': _CategoryHint('cat_subs', 'Streaming'),
    'YOUTUBE': _CategoryHint('cat_subs', 'Streaming'),
    'XBOX': _CategoryHint('cat_subs', 'Gaming'),
    'BRAWL': _CategoryHint('cat_subs', 'Gaming'),
    'GENSHIN': _CategoryHint('cat_subs', 'Gaming'),
    'GOOGLE ONE': _CategoryHint('cat_subs', 'Suscripción'),

    // ── Supermercados / Alimentación ─────────────────────────────────
    'SUPERMERCADO': _CategoryHint('cat_alim', 'Supermercado'),
    'COTO': _CategoryHint('cat_alim', 'Supermercado'),
    'CARREFOUR': _CategoryHint('cat_alim', 'Supermercado'),
    'DISCO': _CategoryHint('cat_alim', 'Supermercado'),
    'JUMBO': _CategoryHint('cat_alim', 'Supermercado'),
    'DIA': _CategoryHint('cat_alim', 'Supermercado'),
    'DESPENSA': _CategoryHint('cat_alim', 'Almacén'),
    'DRUGSTORE': _CategoryHint('cat_alim', 'Almacén'),

    // ── Restaurantes / Comida ────────────────────────────────────────
    'LUCCIANO': _CategoryHint('cat_alim', 'Heladería'),
    'GRIDO': _CategoryHint('cat_alim', 'Heladería'),
    'HELADERI': _CategoryHint('cat_alim', 'Heladería'),
    'MC DONALD': _CategoryHint('cat_alim', 'Restaurante'),
    'MCDONALD': _CategoryHint('cat_alim', 'Restaurante'),
    'ANGOLO': _CategoryHint('cat_alim', 'Restaurante'),
    'BONAPETIT': _CategoryHint('cat_alim', 'Restaurante'),
    'THE FARM': _CategoryHint('cat_alim', 'Restaurante'),
    'BALI ORAN': _CategoryHint('cat_alim', 'Restaurante'),
    'JARRITO': _CategoryHint('cat_alim', 'Restaurante'),
    'TREWA': _CategoryHint('cat_alim', 'Restaurante'),
    'PESCADERIA': _CategoryHint('cat_alim', 'Alimentos'),
    'CRUCIJUEGOS': _CategoryHint('cat_entret', 'Entretenimiento'),
    'CINE': _CategoryHint('cat_entret', 'Cine'),
    'FESTIVAL': _CategoryHint('cat_entret', 'Entretenimiento'),
    'TEATRO': _CategoryHint('cat_entret', 'Entretenimiento'),
    'TEATRINO': _CategoryHint('cat_entret', 'Entretenimiento'),

    // ── Combustible / Transporte ─────────────────────────────────────
    'APPYPF': _CategoryHint('cat_transp', 'Combustible'),
    'SHELL': _CategoryHint('cat_transp', 'Combustible'),
    'YPF': _CategoryHint('cat_transp', 'Combustible'),
    'AXION': _CategoryHint('cat_transp', 'Combustible'),
    'PETROBRAS': _CategoryHint('cat_transp', 'Combustible'),
    'COMBUST': _CategoryHint('cat_transp', 'Combustible'),
    'JETSMART': _CategoryHint('cat_transp', 'Viajes'),
    'AEROLINEAS': _CategoryHint('cat_transp', 'Viajes'),
    'LATAM': _CategoryHint('cat_transp', 'Viajes'),
    'AEROL': _CategoryHint('cat_transp', 'Viajes'),
    'DESPEGAR': _CategoryHint('cat_transp', 'Viajes'),
    'UBER': _CategoryHint('cat_transp', 'Transporte'),
    'CABIFY': _CategoryHint('cat_transp', 'Transporte'),
    'ALTO VERDE': _CategoryHint('cat_transp', 'Transporte'),

    // ── Farmacias / Salud ────────────────────────────────────────────
    'FCIA': _CategoryHint('cat_salud', 'Farmacia'),
    'FARMACIA': _CategoryHint('cat_salud', 'Farmacia'),
    'DSA-': _CategoryHint('cat_salud', 'Farmacia'),
    'SANC': _CategoryHint('cat_salud', 'Salud'),
    'MUTUAL': _CategoryHint('cat_salud', 'Salud'),

    // ── Compras online / MercadoLibre ────────────────────────────────
    'MERCADOLIBRE': _CategoryHint('cat_otros_gasto', 'Compras online'),
    'TIENDAMIA': _CategoryHint('cat_otros_gasto', 'Compras online'),

    // ── Tecnología ───────────────────────────────────────────────────
    'MONOBLOCK': _CategoryHint('cat_tecno', 'Tecnología'),
    'DIGGIT': _CategoryHint('cat_tecno', 'Tecnología'),
    'ELECTROWORLD': _CategoryHint('cat_tecno', 'Tecnología'),

    // ── Ropa ─────────────────────────────────────────────────────────
    'MANKI': _CategoryHint('cat_ropa', 'Ropa'),
    'ZARA': _CategoryHint('cat_ropa', 'Ropa'),
    'KEOPS': _CategoryHint('cat_ropa', 'Ropa'),
    'VENTI': _CategoryHint('cat_ropa', 'Ropa'),

    // ── Mascotas ─────────────────────────────────────────────────────
    'MASCOTA': _CategoryHint('cat_hogar', 'Mascotas'),
    'SUPERMASCOTAS': _CategoryHint('cat_hogar', 'Mascotas'),

    // ── Hogar / Auto ─────────────────────────────────────────────────
    'NEUMATI': _CategoryHint('cat_hogar', 'Auto'),
    'ACCESORIOS DEL NORTE': _CategoryHint('cat_hogar', 'Auto'),

    // ── Transferencias MercadoPago (genérico, va último) ─────────────
    'MERPAGO': _CategoryHint('cat_otros_gasto', 'MercadoPago'),
  };

  // ─── Meses en español (Mastercard usa abreviaturas de 3 letras) ──────────

  static const Map<String, int> _meses = {
    'Ene': 1, 'Feb': 2, 'Mar': 3, 'Abr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Ago': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dic': 12,
    // Visa usa nombres completos en el header
    'Enero': 1, 'Febrero': 2, 'Marzo': 3, 'Abril': 4, 'Mayo': 5, 'Junio': 6,
    'Julio': 7, 'Agosto': 8, 'Septiembre': 9, 'Octubre': 10, 'Noviembre': 11, 'Diciembre': 12,
  };

  // ─── API pública ─────────────────────────────────────────────────────────

  /// Extrae el texto completo de un PDF dado sus bytes.
  static String extractText(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
    }
    document.dispose();
    return buffer.toString();
  }

  /// Detecta el formato del PDF y parsea las transacciones.
  /// Todas las transacciones se asignan al mes de cierre del resumen,
  /// porque la tarjeta cobra el total en la fecha de cierre sin importar
  /// cuándo se realizó la compra.
  static List<ParsedTransaction> parse(String text) {
    final format = _detectFormat(text);
    List<ParsedTransaction> results;
    switch (format) {
      case CardFormat.mastercardICBC:
        results = _parseMastercard(text);
      case CardFormat.visaICBC:
        results = _parseVisa(text);
      case CardFormat.unknown:
        results = [];
    }
    // Fallback: if specific parser returned nothing, try generic
    if (results.isEmpty) {
      results = _parseGeneric(text);
    }

    // Reassign all transactions to the statement closing month.
    // Credit card statements charge everything on the closing date,
    // so Feb purchases in a March statement should appear in March.
    final stInfo = detectStatementInfo(text);
    if (stInfo.month != null && stInfo.year != null) {
      final stMonth = stInfo.month!;
      final stYear = stInfo.year!;
      final daysInStMonth = DateTime(stYear, stMonth + 1, 0).day;
      results = results.map((tx) {
        if (tx.date.month == stMonth && tx.date.year == stYear) return tx;
        // Keep original day but move to statement month
        final clampedDay = tx.date.day.clamp(1, daysInStMonth);
        return ParsedTransaction(
          date: DateTime(stYear, stMonth, clampedDay),
          description: tx.description,
          amount: tx.amount,
          isInstallment: tx.isInstallment,
          installmentCurrent: tx.installmentCurrent,
          installmentTotal: tx.installmentTotal,
          suggestedCategoryId: tx.suggestedCategoryId,
          suggestedCategoryName: tx.suggestedCategoryName,
          isSelected: tx.isSelected,
        );
      }).toList();
    }

    // Deduplicate: same date + description + amount = duplicate from
    // multi-page PDF extraction or overlapping regex matches.
    // Use normalized key (uppercase, no spaces) to catch near-duplicates.
    final seen = <String>{};
    results = results.where((tx) {
      final normDesc = tx.description.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      final key = '${tx.date.year}-${tx.date.month}-${tx.date.day}|$normDesc|${tx.amount.toStringAsFixed(2)}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();

    return results;
  }

  /// Returns diagnostic info about the extracted text for debugging.
  static Map<String, dynamic> debugExtraction(String text) {
    final rawLines = text.split('\n');
    final normalized = _normalizeText(text);
    final normLines = normalized.split('\n').where((l) => l.trim().isNotEmpty).length;
    final format = _detectFormat(text);
    final datePatterns = RegExp(r'\d{2}-\w{3}-\d{2}|\d{1,2}\s+\d{6}');
    final amountPatterns = RegExp(r'[\d.]+,\d{2}');
    final datesFound = datePatterns.allMatches(text).length;
    final amountsFound = amountPatterns.allMatches(text).length;

    return {
      'totalLines': rawLines.length,
      'normalizedLines': normLines,
      'format': format.name,
      'datesFound': datesFound,
      'amountsFound': amountsFound,
      'preview': normalized.substring(0, normalized.length.clamp(0, 800)),
      'containsMastercard':
          text.contains('MASTCLI') || text.contains('MASTERCARD'),
      'containsVisa': text.contains('VISA') || text.contains('Visa'),
    };
  }

  /// Detecta el banco/formato a partir del texto extraído.
  static CardFormat detectFormat(String text) => _detectFormat(text);

  /// Detecta información del período del resumen: mes, año, nombre del banco.
  /// Útil para auto-completar campos antes de importar.
  static ({int? month, int? year, String? bankName}) detectStatementInfo(String text) {
    final format = _detectFormat(text);
    String? bankName;
    int? month, year;

    switch (format) {
      case CardFormat.mastercardICBC:
        bankName = 'Mastercard ICBC';
        // Buscar header de período: "PERÍODO 01/02/26 al 28/02/26"
        final periodoRe = RegExp(r'(?:PER[ÍI]ODO|PERIODO|CIERRE)\s.*?(\d{1,2})/(\d{1,2})/(\d{2,4})');
        final pm = periodoRe.firstMatch(text);
        if (pm != null) {
          month = int.tryParse(pm.group(2)!);
          final y = int.tryParse(pm.group(3)!);
          if (y != null) year = y < 100 ? 2000 + y : y;
        }
        // Fallback: extraer del mes más frecuente en las transacciones
        if (month == null) {
          final normalized = _normalizeText(text);
          final dateRe = RegExp(r'(\d{2})-(\w{3})-(\d{2})');
          final dates = dateRe.allMatches(normalized).toList();
          if (dates.isNotEmpty) {
            final monthCounts = <int, int>{};
            for (final m in dates) {
              final mo = _meses[m.group(2)!];
              if (mo != null) monthCounts[mo] = (monthCounts[mo] ?? 0) + 1;
            }
            if (monthCounts.isNotEmpty) {
              month = monthCounts.entries
                  .reduce((a, b) => a.value >= b.value ? a : b)
                  .key;
            }
            final y = int.tryParse(dates.first.group(3)!);
            if (y != null) year = y < 100 ? 2000 + y : y;
          }
        }
      case CardFormat.visaICBC:
        bankName = 'Visa ICBC';
        final headerRe = RegExp(r'CIERRE\s+\d+\s+(\w+)\s+(\d{2})');
        final hm = headerRe.firstMatch(text);
        if (hm != null) {
          month = _meses[hm.group(1)!];
          final y = int.tryParse(hm.group(2)!);
          if (y != null) year = 2000 + y;
        }
      case CardFormat.unknown:
        // Intentar con fechas genéricas
        final normalized = _normalizeText(text);
        final dateRe = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})');
        final dates = dateRe.allMatches(normalized).toList();
        if (dates.isNotEmpty) {
          final monthCounts = <int, int>{};
          for (final m in dates) {
            final mo = int.tryParse(m.group(2)!);
            if (mo != null && mo >= 1 && mo <= 12) {
              monthCounts[mo] = (monthCounts[mo] ?? 0) + 1;
            }
          }
          if (monthCounts.isNotEmpty) {
            month = monthCounts.entries
                .reduce((a, b) => a.value >= b.value ? a : b)
                .key;
          }
          final y = int.tryParse(dates.first.group(3)!);
          if (y != null) year = y < 100 ? 2000 + y : y;
        }
    }

    return (month: month, year: year, bankName: bankName);
  }

  // ─── Preprocesamiento ───────────────────────────────────────────────────
  //
  // Syncfusion extractText() concatena el texto sin preservar saltos de línea
  // entre transacciones. Insertamos \n antes de cada patrón de fecha para que
  // los regex con ^ y $ funcionen correctamente.

  static String _normalizeText(String raw) {
    var text = raw;

    // Mastercard dates: DD-Mon-YY (ej: "19-Feb-26")
    text = text.replaceAllMapped(
      RegExp(r'(\d{2}-(?:Ene|Feb|Mar|Abr|May|Jun|Jul|Ago|Sep|Oct|Nov|Dic)-\d{2})'),
      (m) => '\n${m.group(1)}',
    );

    // Visa: insert \n before month headers like "26 Febrero", "26 Marzo"
    // These appear between transactions and break the end-of-line regex match.
    text = text.replaceAllMapped(
      RegExp(r'(?<!\n)(\d{1,2}\s+(?:Enero|Febrero|Marzo|Abril|Mayo|Junio|Julio|Agosto|Septiembre|Octubre|Noviembre|Diciembre)\b)'),
      (m) => '\n${m.group(1)}',
    );

    // Visa: insert \n before "Tarjeta NNNN Total" summary lines
    text = text.replaceAllMapped(
      RegExp(r'(?<!\n)(Tarjeta\s+\d+)'),
      (m) => '\n${m.group(1)}',
    );

    // Visa dates: DD NNNNNN * (ej: "4 301234 *")
    text = text.replaceAllMapped(
      RegExp(r'(?<!\n)(\d{1,2}\s+\d{6}\s+\*)'),
      (m) => '\n${m.group(1)}',
    );

    // Genérico: DD/MM/YY o DD/MM/YYYY
    text = text.replaceAllMapped(
      RegExp(r'(?<!\n)(\d{1,2}/\d{1,2}/\d{2,4})'),
      (m) => '\n${m.group(1)}',
    );

    return text;
  }

  // ─── Detección ───────────────────────────────────────────────────────────

  static CardFormat _detectFormat(String text) {
    if (text.contains('MASTCLI') || text.contains('MASTERCARD')) {
      return CardFormat.mastercardICBC;
    }
    if (text.contains('EXCLUSIVE ICBC CLUB') || text.contains('TARJETA 2550') || text.contains('Visa ICBC') || text.contains('VISA') || text.contains('visa')) {
      return CardFormat.visaICBC;
    }
    return CardFormat.unknown;
  }

  // ─── Parser Mastercard ICBC ───────────────────────────────────────────────
  //
  // Formato compras: "DD-Mon-YY DESCRIPCION NNNNN MONTO"
  // Formato cuotas:  "DD-Mon-YY DESCRIPCION CC/TT NNNNN MONTO"
  // Montos: "26040,00" o "1.522.588,23" (punto = miles, coma = decimal)

  // Patrones a ignorar (headers, totales, info del resumen)
  static final _skipDescPatterns = RegExp(
    r'SALDO|PAGO MINIMO|COMPRAS? ANTERIOR|VENCIMIENTO|CIERRE|TOTAL|LIMITE|CUOTAS A VENCER|PROXIMO|ESTADO DE CUENTA|HOJA|MASTCLI|CUIT|MASTERCARD|CONSUMIDOR|GAF:|SUBTOTAL|I\.V\.A|RESUMEN CONSOLIDADO|SU PAGO|PENDIENTE|COMISIONES|DEV PER|COMISION PAQUETE|DB IVA|PAGO EN PESOS|PERCEP|SALTA DTO|INFORMACION|DEBITAREMOS|TARJETA \d+|BENEFICIOS|VISA|EXCLUSIVE|N317',
    caseSensitive: false,
  );

  static List<ParsedTransaction> _parseMastercard(String text) {
    text = _normalizeText(text);
    final results = <ParsedTransaction>[];

    // Regex para cuotas: fecha, descripción (cualquier carácter), cuota CC/TT, voucher, monto
    final cuotaRe = RegExp(
      r'^(\d{2}-\w{3}-\d{2})\s+(.+?)\s+(\d{2}/\d{2})\s+(\d{4,6})\s+(-?[\d.]+,\d{2})\s*$',
      multiLine: true,
    );

    // Regex para compras con voucher: fecha, descripción, voucher, monto
    final compraRe = RegExp(
      r'^(\d{2}-\w{3}-\d{2})\s+(.+?)\s+(\d{4,6})\s+(-?[\d.]+,\d{2})\s*$',
      multiLine: true,
    );

    // Regex para cargos/ajustes sin voucher: fecha, descripción (mín 3 chars), monto
    final cargoRe = RegExp(
      r'^(\d{2}-\w{3}-\d{2})\s+(.{3,}?)\s+(-?[\d.]+,\d{2})\s*$',
      multiLine: true,
    );

    // Primero procesar cuotas (tienen el patrón más específico)
    final matchedLines = <String>{};
    for (final m in cuotaRe.allMatches(text)) {
      final line = m.group(0)!;
      final desc = _cleanDescription(m.group(2)!);
      if (_skipDescPatterns.hasMatch(desc)) continue;
      matchedLines.add(line);
      final date = _parseMcDate(m.group(1)!);
      if (date == null) continue;
      final cuotaParts = m.group(3)!.split('/');
      final current = int.tryParse(cuotaParts[0]);
      final total = int.tryParse(cuotaParts[1]);
      final amount = _parseAmount(m.group(5)!);
      if (amount <= 0) continue; // Skip refunds/negative adjustments

      results.add(ParsedTransaction(
        date: date,
        description: desc,
        amount: amount,
        isInstallment: true,
        installmentCurrent: current,
        installmentTotal: total,
        suggestedCategoryId: _suggestCategory(desc).id,
        suggestedCategoryName: _suggestCategory(desc).name,
      ));
    }

    // Luego compras con voucher (evitando las ya procesadas como cuotas)
    for (final m in compraRe.allMatches(text)) {
      final line = m.group(0)!;
      if (matchedLines.contains(line)) continue;
      final desc = _cleanDescription(m.group(2)!);
      if (_skipDescPatterns.hasMatch(desc)) continue;
      matchedLines.add(line);
      final date = _parseMcDate(m.group(1)!);
      if (date == null) continue;
      final amount = _parseAmount(m.group(4)!);
      if (amount <= 0) continue; // Skip refunds/negative adjustments

      results.add(ParsedTransaction(
        date: date,
        description: desc,
        amount: amount,
        suggestedCategoryId: _suggestCategory(desc).id,
        suggestedCategoryName: _suggestCategory(desc).name,
      ));
    }

    // Por último, cargos/ajustes sin voucher (ej: MEMBRESIA, COMISIONES)
    for (final m in cargoRe.allMatches(text)) {
      final line = m.group(0)!;
      if (matchedLines.contains(line)) continue;
      final desc = _cleanDescription(m.group(2)!);
      if (_skipDescPatterns.hasMatch(desc)) continue;
      if (desc.length < 3) continue;
      matchedLines.add(line);
      final date = _parseMcDate(m.group(1)!);
      if (date == null) continue;
      final amount = _parseAmount(m.group(3)!);
      if (amount <= 0) continue; // Skip refunds/negative adjustments

      results.add(ParsedTransaction(
        date: date,
        description: desc,
        amount: amount,
        suggestedCategoryId: _suggestCategory(desc).id,
        suggestedCategoryName: _suggestCategory(desc).name,
      ));
    }

    // Ordenar por fecha
    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }

  // ─── Parser Visa ICBC ────────────────────────────────────────────────────
  //
  // Formato: "[DD Mon] DD NNNNNN * DESCRIPCION [REF_LARGA] MONTO"
  // Los primeros DD Mon son la fecha de cierre (pueden no repetirse en cada línea).
  // El segundo DD es el día de la transacción.
  // Extraemos el año/mes del header: "CIERRE 26 Mar 26"

  static List<ParsedTransaction> _parseVisa(String text) {
    text = _normalizeText(text);
    final results = <ParsedTransaction>[];

    // Extraer mes y año de cierre del header, ej: "CIERRE 26 Mar 26"
    final headerRe = RegExp(r'CIERRE\s+\d+\s+(\w+)\s+(\d{2})');
    int baseYear = DateTime.now().year;
    int baseMonth = DateTime.now().month;
    final headerMatch = headerRe.firstMatch(text);
    if (headerMatch != null) {
      final mesStr = headerMatch.group(1)!;
      final yearShort = int.tryParse(headerMatch.group(2)!) ?? 0;
      baseYear = 2000 + yearShort;
      baseMonth = _meses[mesStr] ?? baseMonth;
    }

    // Regex principal: DD NNNNNN * DESCRIPCION [REF_LARGA] MONTO
    final txRe = RegExp(
      r'^\s*(?:\d{1,2}\s+\w+\s+)?(\d{1,2})\s+(\d{6})\s+\*\s+(.+?)\s+(?:\d{8,24}\s+)?([\d.]+,\d{2})\s*$',
      multiLine: true,
    );

    // Regex alternativo más flexible: acepta variaciones (sin *, con - separador, etc.)
    final txReAlt = RegExp(
      r'^\s*(\d{1,2})\s+(\d{4,6})\s+[*\-]\s+(.+?)\s+([\d.]+,\d{2})\s*$',
      multiLine: true,
    );

    final matchedLines = <String>{};

    for (final m in txRe.allMatches(text)) {
      matchedLines.add(m.group(0)!);
      final day = int.tryParse(m.group(1)!) ?? 1;
      final desc = _cleanDescription(m.group(3)!);
      if (_skipDescPatterns.hasMatch(desc)) continue;
      final amount = _parseAmount(m.group(4)!);
      if (amount <= 0) continue;

      // Use baseMonth for all — parse() will reassign to statement month
      final clampedDay = day.clamp(1, DateTime(baseYear, baseMonth + 1, 0).day);
      results.add(ParsedTransaction(
        date: DateTime(baseYear, baseMonth, clampedDay),
        description: desc,
        amount: amount,
        suggestedCategoryId: _suggestCategory(desc).id,
        suggestedCategoryName: _suggestCategory(desc).name,
      ));
    }

    // Segundo pase con regex alternativo para capturar líneas que el principal no matcheó
    for (final m in txReAlt.allMatches(text)) {
      if (matchedLines.contains(m.group(0)!)) continue;
      final day = int.tryParse(m.group(1)!) ?? 1;
      if (day > 31) continue; // No es un día válido
      final desc = _cleanDescription(m.group(3)!);
      if (_skipDescPatterns.hasMatch(desc)) continue;
      if (desc.length < 3) continue;
      final amount = _parseAmount(m.group(4)!);
      if (amount <= 0) continue;

      final clampedDay = day.clamp(1, DateTime(baseYear, baseMonth + 1, 0).day);
      results.add(ParsedTransaction(
        date: DateTime(baseYear, baseMonth, clampedDay),
        description: desc,
        amount: amount,
        suggestedCategoryId: _suggestCategory(desc).id,
        suggestedCategoryName: _suggestCategory(desc).name,
      ));
    }

    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }

  // ─── Parser Genérico (fallback) ───────────────────────────────────────────
  //
  // Intenta detectar cualquier línea con un patrón de fecha y un monto.
  // Formatos argentinos comunes:
  //   DD/MM/YYYY descripcion $monto
  //   DD/MM descripcion monto
  //   DD-MMM-YY descripcion monto

  static List<ParsedTransaction> _parseGeneric(String text) {
    text = _normalizeText(text);
    final results = <ParsedTransaction>[];

    final genericRe = RegExp(
      r'(\d{1,2})[/\-](\d{1,2}|\w{3})[/\-]?(\d{2,4})?\s+(.+?)\s+([\d.]+,\d{2})\s*$',
      multiLine: true,
    );

    for (final m in genericRe.allMatches(text)) {
      final dayStr = m.group(1)!;
      final monthStr = m.group(2)!;
      final yearStr = m.group(3);

      final day = int.tryParse(dayStr);
      final month = int.tryParse(monthStr) ?? _meses[monthStr];
      int year = DateTime.now().year;
      if (yearStr != null) {
        final y = int.tryParse(yearStr);
        if (y != null) year = y < 100 ? 2000 + y : y;
      }

      if (day == null || month == null) continue;

      final desc = _cleanDescription(m.group(4)!);
      final amount = _parseAmount(m.group(5)!);
      if (amount <= 0 || desc.length < 3) continue;

      // Skip header/footer lines
      if (desc.toUpperCase().contains('TOTAL') ||
          desc.toUpperCase().contains('SALDO') ||
          desc.toUpperCase().contains('CIERRE') ||
          desc.toUpperCase().contains('PAGO MINIMO')) {
        continue;
      }

      results.add(ParsedTransaction(
        date: DateTime(year, month, day),
        description: desc,
        amount: amount,
        suggestedCategoryId: _suggestCategory(desc).id,
        suggestedCategoryName: _suggestCategory(desc).name,
      ));
    }

    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }

  /// Extrae información del resumen: pago mínimo y saldo actual.
  static ({double? pagoMinimo, double? saldoActual}) extractStatementAmounts(String text) {
    double? pagoMinimo;
    double? saldoActual;

    // Mastercard: "PAGO MINIMO $ 84850,00" or "PAGO MINIMO 84850,00"
    // Visa: "PAGO MINIMO    $   79.987,00"
    final pagoRe = RegExp(r'PAGO\s+MINIMO\s+\$?\s*([\d.,]+)', caseSensitive: false);
    final pagoMatch = pagoRe.firstMatch(text);
    if (pagoMatch != null) {
      pagoMinimo = _parseAmount(pagoMatch.group(1)!);
    }

    // Mastercard: "SALDO ACTUAL $ 1522588,23"
    // Visa: "SALDO ACTUAL    $   511.659,00"
    final saldoRe = RegExp(r'SALDO\s+ACTUAL\s+\$?\s*([\d.,]+)', caseSensitive: false);
    final saldoMatch = saldoRe.firstMatch(text);
    if (saldoMatch != null) {
      saldoActual = _parseAmount(saldoMatch.group(1)!);
    }

    return (pagoMinimo: pagoMinimo, saldoActual: saldoActual);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// "26.040,00" o "1.522.588,23" → double
  static double _parseAmount(String raw) {
    final cleaned = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// "19-Feb-26" → DateTime(2026, 2, 19)
  static DateTime? _parseMcDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = _meses[parts[1]];
    final yearShort = int.tryParse(parts[2]);
    if (day == null || month == null || yearShort == null) return null;
    return DateTime(2000 + yearShort, month, day);
  }

  /// Limpia y normaliza la descripción (elimina espacios extra, trim).
  static String _cleanDescription(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Devuelve la categoría sugerida basada en keywords en la descripción.
  static _CategoryHint _suggestCategory(String description) {
    final upper = description.toUpperCase();
    for (final entry in _keywordMap.entries) {
      if (upper.contains(entry.key)) return entry.value;
    }
    return const _CategoryHint('cat_otros_gasto', 'Otros gastos');
  }
}

class _CategoryHint {
  const _CategoryHint(this.id, this.name);
  final String id;
  final String name;
}
