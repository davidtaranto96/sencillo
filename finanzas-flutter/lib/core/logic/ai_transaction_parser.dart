import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/nl_transaction.dart';
import '../../features/accounts/domain/models/account.dart' as dom_acc;
import '../../features/people/domain/models/person.dart' as dom_p;
import '../../features/goals/domain/models/goal.dart';
import '../../features/budget/domain/models/budget.dart' as dom_b;
import '../../features/wishlist/domain/models/wishlist_item.dart';

const _apiKeyPref = 'anthropic_api_key';

/// Strips common Spanish diacritics for fuzzy matching.
String _stripAccents(String input) {
  return input
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp('[ÁÀÄÂ]'), 'A')
      .replaceAll(RegExp('[ÉÈËÊ]'), 'E')
      .replaceAll(RegExp('[ÍÌÏÎ]'), 'I')
      .replaceAll(RegExp('[ÓÒÖÔ]'), 'O')
      .replaceAll(RegExp('[ÚÙÜÛ]'), 'U')
      .replaceAll('Ñ', 'N');
}

class AiTransactionParser {
  // ─────────────────────────────────────────────
  // API Key management
  // ─────────────────────────────────────────────
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key);
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiKeyPref);
  }

  // ─────────────────────────────────────────────
  // Main parse method
  // ─────────────────────────────────────────────
  Future<NLTransaction> parse({
    required String input,
    required List<dom_acc.Account> accounts,
    required List<dom_p.Person> people,
    required List<Goal> goals,
    required List<dom_b.Budget> budgets,
    required List<WishlistItem> wishlist,
  }) async {
    final apiKey = await getApiKey();

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        return await _parseWithAI(
          input: input,
          apiKey: apiKey,
          accounts: accounts,
          people: people,
          goals: goals,
          budgets: budgets,
          wishlist: wishlist,
        );
      } catch (_) {
        // fallback to regex on API error
      }
    }

    return _parseWithRegex(
      input: input,
      accounts: accounts,
      people: people,
      goals: goals,
      budgets: budgets,
      wishlist: wishlist,
    );
  }

  // ─────────────────────────────────────────────
  // Claude Haiku API call
  // ─────────────────────────────────────────────
  Future<NLTransaction> _parseWithAI({
    required String input,
    required String apiKey,
    required List<dom_acc.Account> accounts,
    required List<dom_p.Person> people,
    required List<Goal> goals,
    required List<dom_b.Budget> budgets,
    required List<WishlistItem> wishlist,
  }) async {
    final accountsJson = accounts.map((a) => {
      'id': a.id,
      'name': a.name,
      'type': a.type.name,
      'isCard': a.isCreditCard,
      'isCash': a.type.name == 'cash',
    }).toList();
    final peopleJson = people.map((p) => {
      'id': p.id,
      'name': p.name,
      'balance': p.totalBalance,
      'owesMe': p.owesMe,
    }).toList();
    final goalsJson = goals.where((g) => !g.isCompleted).map((g) => {'id': g.id, 'name': g.name, 'remaining': g.remaining}).toList();
    final budgetsJson = budgets.map((b) => {'categoryId': b.categoryId, 'categoryName': b.categoryName, 'limit': b.limitAmount, 'spent': b.spentAmount}).toList();
    final wishlistJson = wishlist.where((w) => !w.isPurchased).map((w) => {'id': w.id, 'name': w.title, 'cost': w.estimatedCost}).toList();

    final prompt = '''Sos un parser financiero para una app argentina de finanzas personales.
Analizá el input del usuario y detectá el escenario financiero. Devolvé un JSON estructurado.

CUENTAS DISPONIBLES: ${jsonEncode(accountsJson)}
PERSONAS REGISTRADAS: ${jsonEncode(peopleJson)}
OBJETIVOS ACTIVOS: ${jsonEncode(goalsJson)}
PRESUPUESTOS ACTIVOS: ${jsonEncode(budgetsJson)}
LISTA DE DESEOS PENDIENTE: ${jsonEncode(wishlistJson)}

ESCENARIOS POSIBLES:
- "expense": gasto (comida, transporte, servicios, etc.). Puede ser en efectivo, débito o tarjeta.
- "income": ingreso de dinero (sueldo, venta, pago recibido). Incluye "lo tengo en efectivo".
- "card_payment": pago del resumen/deuda de una tarjeta de crédito.
- "loan_given": presté plata a alguien (yo di el dinero, ellos me deben).
- "loan_received": alguien me devolvió plata que me debían, o me pagó algo que les presté.
- "loan_repayment": yo le pagué a alguien una deuda que yo tenía con ellos.
- "shared_expense": gasto compartido entre el usuario y otra persona con división de montos.
- "goal_contribution": guardé/ahorré plata para un objetivo específico.
- "wishlist_purchase": compré algo que estaba en la lista de deseos.
- "internal_transfer": transferí plata entre dos cuentas propias del usuario.
- "create_goal": crear un nuevo objetivo de ahorro (ej: "crear objetivo viaje a Mendoza 500k").
- "create_budget": crear un nuevo presupuesto (ej: "crear presupuesto comida 100k").
- "unclear": no se puede determinar con certeza.

CATEGORÍAS VÁLIDAS (usar exactamente estos IDs):
Gastos: food, transport, health, entertainment, shopping, home, education, services, cat_financial, cat_peer_to_peer, other_expense
Ingresos: salary, freelance, other_income

INPUT DEL USUARIO: "$input"

Respondé ÚNICAMENTE con JSON válido (sin markdown, sin texto extra):
{
  "scenario": "<scenario>",
  "amount": <número o null>,
  "title": "<descripción corta en español, max 40 chars>",
  "categoryId": "<category_id>",
  "personId": "<id de persona o null>",
  "personName": "<nombre si no matchea id o null>",
  "accountId": "<id de cuenta origen o null>",
  "targetAccountId": "<id de cuenta destino para internal_transfer o null>",
  "cardId": "<id de tarjeta para card_payment o null>",
  "goalId": "<id de objetivo o null>",
  "wishlistItemId": "<id de item de wishlist o null>",
  "budgetCategoryId": "<categoryId de presupuesto para create_budget o null>",
  "isSplit": <true/false>,
  "splitOwnAmount": <mi parte en shared_expense o null>,
  "splitOtherAmount": <parte ajena en shared_expense o null>,
  "note": "<nota útil o null>"
}

REGLAS IMPORTANTES:
- Montos: "45k" = 45000, "45 mil" = 45000, "1.5 millones" = 1500000, "1,5M" = 1500000
- Si dice "efectivo" o "cash" → buscar cuenta tipo cash en la lista
- Si dice "MP" o "Mercado Pago" → buscar esa cuenta
- Si dice "Visa", "Mastercard", "ICBC" → buscar tarjeta de crédito correspondiente
- Si menciona un nombre de persona → buscarla en la lista y usar su ID
- Para "loan_received": accountId es donde entra el dinero, personId es quien devuelve
- Para "loan_repayment": accountId es de donde sale el dinero, personId es a quien le pago
- Para "internal_transfer": accountId es origen, targetAccountId es destino
- Si el gasto fue "con visa/mastercard" → es expense con accountId = esa tarjeta
- Si dice "lo dividí con [nombre]" → shared_expense con split 50/50 si no especifica
- Para "create_goal": title es el nombre del objetivo, amount es la meta
- Para "create_budget": title es el nombre de la categoría, amount es el límite, budgetCategoryId es la categoría si matchea una existente
- Si dice "crear/nuevo objetivo" → create_goal
- Si dice "crear/nuevo presupuesto" → create_budget
- Si dice "ahorré X para [nombre de objetivo]" → goal_contribution con goalId del objetivo que matchea
- Inferí la cuenta más lógica según el contexto aunque no se mencione explícitamente''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 512,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final text = data['content'][0]['text'] as String;
    final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;

    return _mapJsonToNL(parsed, input);
  }

  // ─────────────────────────────────────────────
  // Regex fallback parser (mejorado)
  // ─────────────────────────────────────────────
  NLTransaction _parseWithRegex({
    required String input,
    required List<dom_acc.Account> accounts,
    required List<dom_p.Person> people,
    required List<Goal> goals,
    required List<dom_b.Budget> budgets,
    required List<WishlistItem> wishlist,
  }) {
    final lower = input.toLowerCase();

    // Detectar monto (45k, 45 mil, 45000, 1.200.000, 1,5M)
    double? amount;
    final amtRegexM = RegExp(r'(\d[\d,.]*)[\s]*(?:millones?|M)\b', caseSensitive: false);
    final amtRegexK = RegExp(r'(\d[\d,.]*)[\s]*(?:k|mil)\b', caseSensitive: false);
    final amtRegexN = RegExp(r'\b(\d[\d.,]*)\b');

    if (amtRegexM.hasMatch(input)) {
      final m = amtRegexM.firstMatch(input)!;
      final raw = m.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      amount = (double.tryParse(raw) ?? 0) * 1000000;
    } else if (amtRegexK.hasMatch(input)) {
      final m = amtRegexK.firstMatch(input)!;
      final raw = m.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      amount = (double.tryParse(raw) ?? 0) * 1000;
    } else if (amtRegexN.hasMatch(input)) {
      final m = amtRegexN.firstMatch(input)!;
      final raw = m.group(1)!.replaceAll('.', '').replaceAll(',', '');
      amount = double.tryParse(raw);
    }

    // ── Crear objetivo ──
    final createGoalRegex = RegExp(
      r'(?:cre(?:ar|á)|nuevo|nueva|agreg(?:ar|á))\s+(?:un\s+)?objetivo\s+(?:de\s+)?(?:ahorro\s+)?(?:para\s+)?(.+?)(?:\s+(?:de|por)\s+(\d[\d.,]*\s*(?:k|mil|millones?|M)?))?$',
      caseSensitive: false,
    );
    if (lower.contains('objetivo') &&
        (lower.contains('crear') || lower.contains('creá') ||
         lower.contains('nuevo') || lower.contains('nueva') ||
         lower.contains('agregar') || lower.contains('agregá'))) {
      final match = createGoalRegex.firstMatch(input);
      String goalName = 'Nuevo objetivo';
      if (match != null) {
        goalName = match.group(1)?.trim() ?? goalName;
        // Capitalize first letter
        if (goalName.isNotEmpty) {
          goalName = goalName[0].toUpperCase() + goalName.substring(1);
        }
      } else {
        // Try to extract name after "objetivo"
        final afterObj = RegExp(r'objetivo\s+(?:de\s+)?(?:ahorro\s+)?(?:para\s+)?(.+)', caseSensitive: false);
        final m2 = afterObj.firstMatch(input);
        if (m2 != null) {
          goalName = m2.group(1)!.trim();
          // Remove trailing amount
          goalName = goalName.replaceAll(RegExp(r'\s+(?:de|por)\s+\d[\d.,]*\s*(?:k|mil|millones?|M)?$', caseSensitive: false), '').trim();
          if (goalName.isNotEmpty) {
            goalName = goalName[0].toUpperCase() + goalName.substring(1);
          }
        }
      }

      return NLTransaction(
        scenario: NLScenario.createGoal,
        amount: amount,
        title: goalName,
        rawInput: input,
      );
    }

    // ── Crear presupuesto ──
    if (lower.contains('presupuesto') &&
        (lower.contains('crear') || lower.contains('creá') ||
         lower.contains('nuevo') || lower.contains('nueva') ||
         lower.contains('agregar') || lower.contains('agregá'))) {
      String budgetName = 'Nuevo presupuesto';
      String? matchedCategoryId;

      // Try to extract name after "presupuesto"
      final afterBudget = RegExp(r'presupuesto\s+(?:de\s+)?(?:para\s+)?(.+)', caseSensitive: false);
      final m = afterBudget.firstMatch(input);
      if (m != null) {
        budgetName = m.group(1)!.trim();
        // Remove trailing amount
        budgetName = budgetName.replaceAll(RegExp(r'\s+(?:de|por)\s+\d[\d.,]*\s*(?:k|mil|millones?|M)?$', caseSensitive: false), '').trim();
        if (budgetName.isNotEmpty) {
          budgetName = budgetName[0].toUpperCase() + budgetName.substring(1);
        }
      }

      // Match to a predefined category
      matchedCategoryId = _matchBudgetCategory(budgetName.toLowerCase());

      return NLTransaction(
        scenario: NLScenario.createBudget,
        amount: amount,
        title: budgetName,
        budgetCategoryId: matchedCategoryId,
        rawInput: input,
      );
    }

    // Detectar persona
    dom_p.Person? person;
    for (final p in people) {
      if (lower.contains(p.name.toLowerCase())) {
        person = p;
        break;
      }
      if (p.alias != null && lower.contains(p.alias!.toLowerCase())) {
        person = p;
        break;
      }
    }

    // Detectar cuenta por nombre
    dom_acc.Account? findAccount(String hint) {
      for (final a in accounts) {
        if (hint.contains(a.name.toLowerCase())) return a;
      }
      return null;
    }

    // Cuenta de efectivo
    final cashAccount = accounts.cast<dom_acc.Account?>().firstWhere(
      (a) => a!.type.name == 'cash', orElse: () => null,
    );

    // Cuenta por defecto
    final defaultAccount = accounts.isNotEmpty
        ? accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first)
        : null;

    // Detectar cuenta mencionada
    dom_acc.Account? account;
    if (lower.contains('efectivo') || lower.contains('cash')) {
      account = cashAccount;
    } else if (lower.contains('mercado pago') || lower.contains(' mp ') || lower.endsWith(' mp')) {
      account = findAccount('mercado pago') ?? findAccount('mp');
    } else {
      account = findAccount(lower) ?? defaultAccount;
    }

    // Detectar tarjeta
    dom_acc.Account? card;
    for (final a in accounts.where((a) => a.isCreditCard)) {
      if (lower.contains(a.name.toLowerCase())) {
        card = a;
        break;
      }
    }
    // Si menciona marca genérica de tarjeta
    if (card == null) {
      if (lower.contains('visa')) card = accounts.cast<dom_acc.Account?>().firstWhere((a) => a!.isCreditCard && a.name.toLowerCase().contains('visa'), orElse: () => null);
      if (lower.contains('master')) card = accounts.cast<dom_acc.Account?>().firstWhere((a) => a!.isCreditCard && a.name.toLowerCase().contains('master'), orElse: () => null);
    }

    // ── Detectar escenario ──
    NLScenario scenario = NLScenario.expense;
    String? categoryId = 'other_expense';
    String title = 'Gasto';
    String? targetAccountId;
    bool isSplit = false;
    double? splitOwn, splitOther;

    // Transferencia interna
    if ((lower.contains('transferí') || lower.contains('pasé') || lower.contains('moví')) &&
        !lower.contains(' a juan') && person == null) {
      scenario = NLScenario.internalTransfer;
      title = 'Transferencia entre cuentas';
      for (final a in accounts) {
        if (lower.contains(a.name.toLowerCase()) && a.id != account?.id) {
          targetAccountId = a.id;
          break;
        }
      }
    }
    // Pago de deuda propia (yo le pago a alguien)
    else if (person != null && (lower.contains('le pagué') || lower.contains('le pague') || lower.contains('le devolví') || lower.contains('le devolvï'))) {
      scenario = NLScenario.loanRepayment;
      categoryId = 'cat_peer_to_peer';
      title = 'Devolución a ${person.name}';
    }
    // Préstamo dado
    else if (lower.contains('presté') || lower.contains('le presté') || lower.contains('le di plata') || lower.contains('preste')) {
      scenario = NLScenario.loanGiven;
      categoryId = 'cat_peer_to_peer';
      title = 'Préstamo a ${person?.name ?? 'persona'}';
      account = account ?? defaultAccount;
    }
    // Devolución recibida
    else if (lower.contains('me devolvió') || lower.contains('me pagó') || lower.contains('me devolvio') || lower.contains('me pago')) {
      scenario = NLScenario.loanReceived;
      categoryId = 'cat_peer_to_peer';
      title = 'Devolución de ${person?.name ?? 'persona'}';
    }
    // Pago de resumen tarjeta
    else if ((lower.contains('pagué') || lower.contains('pague')) && (lower.contains('tarjeta') || lower.contains('resumen') || card != null)) {
      scenario = NLScenario.cardPayment;
      categoryId = 'cat_financial';
      title = 'Pago tarjeta ${card?.name ?? ''}';
      final sourceForCard = account?.isCreditCard == false ? account : defaultAccount;
      account = sourceForCard;
    }
    // Ingreso
    else if (lower.contains('sueldo') || lower.contains('cobré') ||
             lower.contains('depositaron') || lower.contains('me pagaron') || lower.contains('gané') ||
             lower.contains('facturé') || lower.contains('vendí') || lower.contains('ingreso')) {
      scenario = NLScenario.income;
      categoryId = lower.contains('sueldo') ? 'salary' : 'other_income';
      title = lower.contains('sueldo') ? 'Cobro de sueldo' : 'Ingreso';
      if (lower.contains('efectivo') || lower.contains('cash')) {
        account = cashAccount ?? defaultAccount;
      }
    }
    // Ahorro / objetivo — mejorado con matching inteligente
    else if (lower.contains('guardé') || lower.contains('ahorré') || lower.contains('ahorro para') || lower.contains('ahorrar')) {
      scenario = NLScenario.goalContribution;
      categoryId = 'other_expense';
      title = 'Ahorro';
      String? matchedGoalId;

      // Buscar por nombre completo primero, luego parcial
      matchedGoalId = _matchGoal(lower, goals);

      if (matchedGoalId != null) {
        final matched = goals.firstWhere((g) => g.id == matchedGoalId);
        title = 'Ahorro: ${matched.name}';
      }

      return NLTransaction(
        scenario: scenario,
        amount: amount,
        title: title,
        categoryId: categoryId,
        accountId: account?.id ?? defaultAccount?.id,
        goalId: matchedGoalId,
        rawInput: input,
      );
    }
    // Gasto compartido
    else if (lower.contains('dividí') || lower.contains('dividi') || lower.contains('compartimos') ||
             lower.contains('a medias') || lower.contains('la mitad')) {
      scenario = NLScenario.sharedExpense;
      isSplit = true;
      if (amount != null) {
        splitOwn = amount / 2;
        splitOther = amount / 2;
      }
      title = 'Gasto compartido${person != null ? ' con ${person.name}' : ''}';
    }
    // Compra wishlist
    else {
      for (final w in wishlist.where((w) => !w.isPurchased)) {
        final words = w.title.toLowerCase().split(' ');
        if (words.any((word) => word.length > 3 && lower.contains(word))) {
          scenario = NLScenario.wishlistPurchase;
          title = 'Compra: ${w.title}';
          amount ??= w.estimatedCost;
          categoryId = 'shopping';
          return NLTransaction(
            scenario: scenario,
            amount: amount,
            title: title,
            categoryId: categoryId,
            accountId: card?.id ?? account?.id,
            wishlistItemId: w.id,
            rawInput: input,
          );
        }
      }

      // ── Primero: matchear contra presupuestos activos del usuario ──
      final lowerNorm = _stripAccents(lower);
      for (final b in budgets) {
        final budgetName = b.categoryName.toLowerCase();
        final budgetNorm = _stripAccents(budgetName);
        // Match nombre completo (con y sin acentos)
        if (lower.contains(budgetName) || lowerNorm.contains(budgetNorm)) {
          categoryId = b.categoryId;
          title = b.categoryName;
          break;
        }
        // Match por palabras significativas
        final words = budgetNorm.split(RegExp(r'\s+'));
        for (final w in words) {
          if (w.length >= 3 && lowerNorm.contains(w)) {
            categoryId = b.categoryId;
            title = b.categoryName;
            break;
          }
        }
        if (categoryId != 'other_expense') break;
      }

      // ── Si no matcheó presupuesto, usar keywords hardcodeados ──
      if (categoryId == 'other_expense') {
      final foodKeywords = {
        'sushi': 'Sushi', 'pizza': 'Pizza', 'mcdonal': 'McDonald\'s', 'burger': 'Hamburguesa',
        'hambur': 'Hamburguesa', 'helado': 'Helado', 'café': 'Café', 'cafe': 'Café',
        'super': 'Supermercado', 'almor': 'Almuerzo', 'cena': 'Cena', 'desayuno': 'Desayuno',
        'restau': 'Restaurant', 'comida': 'Comida', 'rappi': 'Delivery', 'delivery': 'Delivery',
        'pedidos ya': 'Delivery', 'panadería': 'Panadería', 'panaderia': 'Panadería',
        'verdulería': 'Verdulería', 'carnicería': 'Carnicería', 'kiosko': 'Kiosco',
        'kiosco': 'Kiosco', 'empanada': 'Empanadas', 'asado': 'Asado', 'birra': 'Cerveza',
        'cerveza': 'Cerveza', 'vino': 'Vino', 'bar': 'Bar',
      };
      final transportKeywords = {
        'nafta': 'Nafta', 'combustible': 'Combustible', 'uber': 'Uber', 'taxi': 'Taxi',
        'colectivo': 'Colectivo', 'subte': 'Subte', 'tren': 'Tren', 'estacionamiento': 'Estacionamiento',
        'peaje': 'Peaje', 'sube': 'Carga SUBE',
      };
      final healthKeywords = {
        'farmacia': 'Farmacia', 'médico': 'Médico', 'medico': 'Médico', 'doctor': 'Doctor',
        'hospital': 'Hospital', 'obra social': 'Obra Social', 'salud': 'Salud',
        'dentista': 'Dentista', 'psicólogo': 'Psicólogo', 'psicologo': 'Psicólogo',
        'psicóloga': 'Psicóloga', 'psicologa': 'Psicóloga',
        'terapi': 'Terapia', 'kinesió': 'Kinesiología', 'kinesio': 'Kinesiología',
        'nutrici': 'Nutricionista', 'oftalm': 'Oftalmólogo', 'dermat': 'Dermatólogo',
      };
      final entKeywords = {
        'cine': 'Cine', 'netflix': 'Netflix', 'spotify': 'Spotify', 'disney': 'Disney+',
        'juego': 'Juegos', 'teatro': 'Teatro', 'recital': 'Recital', 'concierto': 'Concierto',
        'lolla': 'Lollapalooza', 'play': 'PlayStation', 'steam': 'Steam',
      };
      final shopKeywords = {
        'ropa': 'Ropa', 'zapatilla': 'Zapatillas', 'tienda': 'Tienda', 'zara': 'Zara',
        'h&m': 'H&M', 'nike': 'Nike', 'compré': 'Compra',
      };
      final homeKeywords = {
        'alquiler': 'Alquiler', 'expensas': 'Expensas', 'luz': 'Luz', 'gas': 'Gas',
        'agua': 'Agua', 'internet hogar': 'Internet',
      };
      final serviceKeywords = {
        'gym': 'Gimnasio', 'gimnasio': 'Gimnasio', 'celu': 'Celular', 'internet': 'Internet',
        'suscripción': 'Suscripción', 'suscripcion': 'Suscripción', 'plan': 'Plan',
      };
      final eduKeywords = {
        'libro': 'Libro', 'curso': 'Curso', 'udemy': 'Udemy', 'colegio': 'Colegio',
        'universidad': 'Universidad',
      };

      String? matchKeyword(Map<String, String> keywords) {
        for (final entry in keywords.entries) {
          if (lower.contains(entry.key)) return entry.value;
        }
        return null;
      }

      final foodMatch = matchKeyword(foodKeywords);
      final transportMatch = matchKeyword(transportKeywords);
      final healthMatch = matchKeyword(healthKeywords);
      final entMatch = matchKeyword(entKeywords);
      final shopMatch = matchKeyword(shopKeywords);
      final homeMatch = matchKeyword(homeKeywords);
      final serviceMatch = matchKeyword(serviceKeywords);
      final eduMatch = matchKeyword(eduKeywords);

      if (foodMatch != null) {
        categoryId = 'food'; title = foodMatch;
      } else if (transportMatch != null) {
        categoryId = 'transport'; title = transportMatch;
      } else if (healthMatch != null) {
        categoryId = 'health'; title = healthMatch;
      } else if (entMatch != null) {
        categoryId = 'entertainment'; title = entMatch;
      } else if (shopMatch != null) {
        categoryId = 'shopping'; title = shopMatch;
      } else if (homeMatch != null) {
        categoryId = 'home'; title = homeMatch;
      } else if (serviceMatch != null) {
        categoryId = 'services'; title = serviceMatch;
      } else if (eduMatch != null) {
        categoryId = 'education'; title = eduMatch;
      }
      } // fin del if (categoryId == 'other_expense')

      // Si se usó tarjeta, la cuenta es la tarjeta
      if (card != null) {
        account = card;
      }
    }

    return NLTransaction(
      scenario: scenario,
      amount: amount,
      title: title,
      categoryId: categoryId,
      personId: person?.id,
      personName: person?.name,
      accountId: account?.id,
      targetAccountId: targetAccountId,
      cardId: scenario == NLScenario.cardPayment ? card?.id : null,
      isSplit: isSplit,
      splitOwnAmount: splitOwn,
      splitOtherAmount: splitOther,
      rawInput: input,
    );
  }

  // ─────────────────────────────────────────────
  // Matching inteligente de objetivo
  // ─────────────────────────────────────────────
  String? _matchGoal(String lower, List<Goal> goals) {
    if (goals.isEmpty) return null;

    final lowerNorm = _stripAccents(lower);

    // 1. Match exacto por nombre completo (con y sin acentos)
    for (final g in goals) {
      final name = g.name.toLowerCase();
      if (lower.contains(name) || lowerNorm.contains(_stripAccents(name))) {
        return g.id;
      }
    }

    // 2. Match por cada palabra significativa del nombre (>= 3 chars)
    int bestScore = 0;
    String? bestId;
    for (final g in goals) {
      final words = _stripAccents(g.name.toLowerCase()).split(RegExp(r'\s+'));
      int score = 0;
      for (final w in words) {
        if (w.length >= 3 && lowerNorm.contains(w)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestId = g.id;
      }
    }
    if (bestScore > 0) return bestId;

    // 3. Match parcial — primera palabra significativa
    for (final g in goals) {
      final firstName = _stripAccents(g.name.toLowerCase().split(' ').first);
      if (firstName.length >= 3 && lowerNorm.contains(firstName)) return g.id;
    }

    return null;
  }

  // ─────────────────────────────────────────────
  // Matching de categoría de presupuesto
  // ─────────────────────────────────────────────
  static String? _matchBudgetCategory(String name) {
    const categoryMap = <String, List<String>>{
      'food': ['comida', 'aliment', 'super', 'mercado', 'almuerz', 'cena', 'restaurant'],
      'transport': ['transporte', 'nafta', 'combustible', 'viaje', 'auto', 'uber'],
      'health': ['salud', 'médic', 'medic', 'farmacia', 'psicólog', 'psicologo', 'doctor', 'terapi'],
      'entertainment': ['entretenimiento', 'diversi', 'ocio', 'netflix', 'spotify', 'cine'],
      'shopping': ['compras', 'ropa', 'shopping', 'tienda'],
      'home': ['hogar', 'casa', 'alquiler', 'expensas', 'luz', 'gas', 'agua', 'vivienda'],
      'education': ['educación', 'educacion', 'estudio', 'curso', 'universidad', 'colegio'],
      'services': ['servicios', 'internet', 'celular', 'gym', 'gimnasio', 'suscripci'],
    };

    for (final entry in categoryMap.entries) {
      for (final keyword in entry.value) {
        if (name.contains(keyword)) return entry.key;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // Map API JSON → NLTransaction
  // ─────────────────────────────────────────────
  NLTransaction _mapJsonToNL(Map<String, dynamic> json, String rawInput) {
    NLScenario scenario;
    switch (json['scenario'] as String? ?? 'unclear') {
      case 'expense':       scenario = NLScenario.expense; break;
      case 'income':        scenario = NLScenario.income; break;
      case 'card_payment':  scenario = NLScenario.cardPayment; break;
      case 'loan_given':    scenario = NLScenario.loanGiven; break;
      case 'loan_received': scenario = NLScenario.loanReceived; break;
      case 'loan_repayment': scenario = NLScenario.loanRepayment; break;
      case 'shared_expense': scenario = NLScenario.sharedExpense; break;
      case 'goal_contribution': scenario = NLScenario.goalContribution; break;
      case 'wishlist_purchase': scenario = NLScenario.wishlistPurchase; break;
      case 'internal_transfer': scenario = NLScenario.internalTransfer; break;
      case 'create_goal':   scenario = NLScenario.createGoal; break;
      case 'create_budget': scenario = NLScenario.createBudget; break;
      default: scenario = NLScenario.unclear;
    }

    return NLTransaction(
      scenario: scenario,
      amount: (json['amount'] as num?)?.toDouble(),
      title: json['title'] as String? ?? 'Movimiento',
      categoryId: json['categoryId'] as String?,
      personId: json['personId'] as String?,
      personName: json['personName'] as String?,
      accountId: json['accountId'] as String?,
      targetAccountId: json['targetAccountId'] as String?,
      cardId: json['cardId'] as String?,
      goalId: json['goalId'] as String?,
      wishlistItemId: json['wishlistItemId'] as String?,
      budgetCategoryId: json['budgetCategoryId'] as String?,
      isSplit: json['isSplit'] as bool? ?? false,
      splitOwnAmount: (json['splitOwnAmount'] as num?)?.toDouble(),
      splitOtherAmount: (json['splitOtherAmount'] as num?)?.toDouble(),
      note: json['note'] as String?,
      rawInput: rawInput,
    );
  }
}

final aiTransactionParserProvider = Provider<AiTransactionParser>((ref) {
  return AiTransactionParser();
});
