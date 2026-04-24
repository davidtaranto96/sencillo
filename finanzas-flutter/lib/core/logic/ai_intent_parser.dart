/// Sprint 3.13 — Parser de intents para el AI assistant.
///
/// Detecta si el input del usuario es un slash command (ej: `/transfer 50k de
/// MP a ICBC`) o un mensaje libre. Los slash commands se ejecutan localmente
/// sin llamar a Haiku → ahorra ~$0.001 por intent y responde instantáneo.
///
/// Uso:
/// ```dart
/// final intent = AiIntentParser.parse(userInput);
/// switch (intent) {
///   case TransferIntent t: await txService.createTransfer(...);
///   case SplitIntent s: await peopleService.createSharedExpense(...);
///   ...
///   case ExpenseIntent e: await aiService.chat(e.rawInput);  // fallback Haiku
/// }
/// ```
library;

sealed class AiIntent {
  const AiIntent();
}

/// Slash command: `/transfer <amount> de <accountA> a <accountB>`
class TransferIntent extends AiIntent {
  final double amount;
  final String? fromAccountHint;
  final String? toAccountHint;
  const TransferIntent({
    required this.amount,
    this.fromAccountHint,
    this.toAccountHint,
  });
}

/// Slash command: `/split <concept> <amount> con <persona1> y <persona2>...`
class SplitIntent extends AiIntent {
  final double amount;
  final String concept;
  final List<String> peopleHints;
  const SplitIntent({
    required this.amount,
    required this.concept,
    required this.peopleHints,
  });
}

/// Slash command: `/recurring <title> <amount> <freq>`
class RecurringIntent extends AiIntent {
  final String title;
  final double amount;
  final String frequency; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  const RecurringIntent({
    required this.title,
    required this.amount,
    required this.frequency,
  });
}

/// Slash command: `/budget <category> <amount>`
class BudgetIntent extends AiIntent {
  final String categoryHint;
  final double amount;
  const BudgetIntent({required this.categoryHint, required this.amount});
}

/// Slash command: `/goal <name> <amount> [para <fecha>]`
class GoalIntent extends AiIntent {
  final String name;
  final double target;
  final DateTime? deadline;
  const GoalIntent({required this.name, required this.target, this.deadline});
}

/// Slash command: `/loan <persona> <amount>` (préstamo dado por default)
class LoanIntent extends AiIntent {
  final double amount;
  final String personHint;
  final bool isGiven;
  const LoanIntent({
    required this.amount,
    required this.personHint,
    this.isGiven = true,
  });
}

/// Slash command: `/undo` — revierte la última acción registrada.
class UndoIntent extends AiIntent {
  const UndoIntent();
}

/// Pregunta conversacional (ej: "?cuánto gasté en comida"). Va a Haiku con
/// system prompt de Q&A.
class QuestionIntent extends AiIntent {
  final String rawQuestion;
  const QuestionIntent(this.rawQuestion);
}

/// Fallback: input libre que se pasa al parser regex existente o a Haiku para
/// crear un gasto.
class ExpenseIntent extends AiIntent {
  final String rawInput;
  const ExpenseIntent(this.rawInput);
}

/// API principal del parser.
class AiIntentParser {
  AiIntentParser._();

  static AiIntent parse(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return const ExpenseIntent('');

    // Modo pregunta — ? explícito o verbos interrogativos al inicio.
    if (input.startsWith('?')) {
      return QuestionIntent(input.substring(1).trim());
    }
    if (_isQuestion(input)) {
      return QuestionIntent(input);
    }

    if (!input.startsWith('/')) {
      return ExpenseIntent(input);
    }

    final parts = input.split(RegExp(r'\s+'));
    final cmd = parts.first.toLowerCase();
    final rest = parts.skip(1).join(' ');

    switch (cmd) {
      case '/transfer':
      case '/transferir':
        return _parseTransfer(rest) ?? ExpenseIntent(input);
      case '/split':
      case '/dividir':
        return _parseSplit(rest) ?? ExpenseIntent(input);
      case '/recurring':
      case '/recurrente':
        return _parseRecurring(rest) ?? ExpenseIntent(input);
      case '/budget':
      case '/presupuesto':
        return _parseBudget(rest) ?? ExpenseIntent(input);
      case '/goal':
      case '/meta':
        return _parseGoal(rest) ?? ExpenseIntent(input);
      case '/loan':
      case '/prestamo':
      case '/préstamo':
        return _parseLoan(rest) ?? ExpenseIntent(input);
      case '/undo':
      case '/deshacer':
        return const UndoIntent();
      default:
        return ExpenseIntent(input);
    }
  }

  // ── Helpers ──

  static bool _isQuestion(String s) {
    final lower = s.toLowerCase();
    const verbs = [
      'cuánto', 'cuanto',
      'cuándo', 'cuando',
      'dónde', 'donde',
      'en qué', 'en que',
      'qué tal', 'que tal',
      'cómo va', 'como va',
      'me alcanza',
      'puedo gastar',
    ];
    return verbs.any(lower.startsWith);
  }

  /// Parsea montos con K/M/k/m: "50k" → 50000, "1.5M" → 1500000, "3500" → 3500.
  static double? _parseAmount(String s) {
    final clean = s.replaceAll(RegExp(r'[\$,]'), '').trim();
    final match = RegExp(r'^(\d+(?:[.,]\d+)?)\s*([kKmM])?$').firstMatch(clean);
    if (match == null) return null;
    final num = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (num == null) return null;
    final mult = switch (match.group(2)?.toLowerCase()) {
      'k' => 1000.0,
      'm' => 1000000.0,
      _ => 1.0,
    };
    return num * mult;
  }

  /// `/transfer 50k de MP a ICBC`
  static TransferIntent? _parseTransfer(String rest) {
    // Orden flexible: primero amount, después "de X a Y"
    final amountMatch = RegExp(r'(\d+(?:[.,]\d+)?\s*[kKmM]?)').firstMatch(rest);
    if (amountMatch == null) return null;
    final amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;

    String? from, to;
    final fromMatch = RegExp(r'\bde\s+([\w\sñáéíóúÑÁÉÍÓÚ]+?)(?:\s+a\s+|$)',
            caseSensitive: false)
        .firstMatch(rest);
    if (fromMatch != null) from = fromMatch.group(1)?.trim();

    final toMatch = RegExp(r'\ba\s+([\w\sñáéíóúÑÁÉÍÓÚ]+?)$', caseSensitive: false)
        .firstMatch(rest);
    if (toMatch != null) to = toMatch.group(1)?.trim();

    return TransferIntent(amount: amount, fromAccountHint: from, toAccountHint: to);
  }

  /// `/split cena 12000 con juan y sofi`
  static SplitIntent? _parseSplit(String rest) {
    final amountMatch = RegExp(r'(\d+(?:[.,]\d+)?\s*[kKmM]?)').firstMatch(rest);
    if (amountMatch == null) return null;
    final amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;

    // Concepto = palabras antes del monto
    final concept = rest.substring(0, amountMatch.start).trim();

    // Personas = palabras después de "con"
    List<String> people = [];
    final conMatch = RegExp(r'\bcon\s+(.+?)$', caseSensitive: false).firstMatch(rest);
    if (conMatch != null) {
      people = conMatch.group(1)!
          .split(RegExp(r'\s*(?:,|\sy\s)\s*'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }

    return SplitIntent(
      amount: amount,
      concept: concept.isEmpty ? 'Gasto compartido' : concept,
      peopleHints: people,
    );
  }

  /// `/recurring netflix 8500 mensual`
  static RecurringIntent? _parseRecurring(String rest) {
    final amountMatch = RegExp(r'(\d+(?:[.,]\d+)?\s*[kKmM]?)').firstMatch(rest);
    if (amountMatch == null) return null;
    final amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;

    final title = rest.substring(0, amountMatch.start).trim();
    final tail = rest.substring(amountMatch.end).toLowerCase();
    final freq = _detectFrequency(tail);

    return RecurringIntent(
      title: title.isEmpty ? 'Gasto recurrente' : title,
      amount: amount,
      frequency: freq,
    );
  }

  static String _detectFrequency(String tail) {
    if (tail.contains('diari')) return 'daily';
    if (tail.contains('quincen')) return 'biweekly';
    if (tail.contains('seman')) return 'weekly';
    if (tail.contains('anual') || tail.contains('año') || tail.contains('ano')) return 'yearly';
    return 'monthly'; // default más común
  }

  /// `/budget salidas 40k`
  static BudgetIntent? _parseBudget(String rest) {
    final amountMatch = RegExp(r'(\d+(?:[.,]\d+)?\s*[kKmM]?)').firstMatch(rest);
    if (amountMatch == null) return null;
    final amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;
    final category = rest.substring(0, amountMatch.start).trim();
    if (category.isEmpty) return null;
    return BudgetIntent(categoryHint: category, amount: amount);
  }

  /// `/goal japón 5M para dic`
  static GoalIntent? _parseGoal(String rest) {
    final amountMatch = RegExp(r'(\d+(?:[.,]\d+)?\s*[kKmM]?)').firstMatch(rest);
    if (amountMatch == null) return null;
    final amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;

    final name = rest.substring(0, amountMatch.start).trim();
    if (name.isEmpty) return null;

    DateTime? deadline;
    final paraMatch = RegExp(r'\bpara\s+(.+?)$', caseSensitive: false).firstMatch(rest);
    if (paraMatch != null) {
      deadline = _parseRoughDate(paraMatch.group(1)!);
    }

    return GoalIntent(name: name, target: amount, deadline: deadline);
  }

  /// `/loan adrian 200k` (préstamo dado por default)
  static LoanIntent? _parseLoan(String rest) {
    final amountMatch = RegExp(r'(\d+(?:[.,]\d+)?\s*[kKmM]?)').firstMatch(rest);
    if (amountMatch == null) return null;
    final amount = _parseAmount(amountMatch.group(1)!);
    if (amount == null) return null;
    final person = rest.substring(0, amountMatch.start).trim();
    if (person.isEmpty) return null;
    return LoanIntent(amount: amount, personHint: person);
  }

  /// Parser MUY rough de fechas tipo "dic", "diciembre", "30/12", "fin de año".
  static DateTime? _parseRoughDate(String s) {
    final lower = s.toLowerCase().trim();
    final now = DateTime.now();

    // Mes por nombre (3-letter or full)
    const months = {
      'ene': 1, 'enero': 1,
      'feb': 2, 'febrero': 2,
      'mar': 3, 'marzo': 3,
      'abr': 4, 'abril': 4,
      'may': 5, 'mayo': 5,
      'jun': 6, 'junio': 6,
      'jul': 7, 'julio': 7,
      'ago': 8, 'agosto': 8,
      'sep': 9, 'septiembre': 9, 'set': 9,
      'oct': 10, 'octubre': 10,
      'nov': 11, 'noviembre': 11,
      'dic': 12, 'diciembre': 12,
    };
    for (final entry in months.entries) {
      if (lower.contains(entry.key)) {
        // Si el mes ya pasó este año → próximo año.
        var year = now.year;
        if (entry.value < now.month) year++;
        return DateTime(year, entry.value, 1);
      }
    }

    // dd/mm o dd/mm/yyyy
    final dateMatch = RegExp(r'(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?').firstMatch(lower);
    if (dateMatch != null) {
      final d = int.parse(dateMatch.group(1)!);
      final m = int.parse(dateMatch.group(2)!);
      var y = int.tryParse(dateMatch.group(3) ?? '') ?? now.year;
      if (y < 100) y += 2000;
      return DateTime(y, m, d);
    }

    if (lower.contains('fin de año') || lower.contains('fin de ano')) {
      return DateTime(now.year, 12, 31);
    }
    return null;
  }
}
