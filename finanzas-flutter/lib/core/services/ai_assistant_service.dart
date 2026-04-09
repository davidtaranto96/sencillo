import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/accounts/domain/models/account.dart';
import '../../features/people/domain/models/person.dart';
import '../../features/transactions/domain/models/transaction.dart';
import '../../features/budget/domain/models/budget.dart';
import '../../features/goals/domain/models/goal.dart';

const _apiKeyPref = 'anthropic_api_key';

class AiAssistantService {
  static Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  /// Build financial context summary for the AI.
  static String _buildContext({
    required List<Account> accounts,
    required List<Transaction> recentTx,
    required List<Person> people,
    required List<Budget> budgets,
    required List<Goal> goals,
  }) {
    final buf = StringBuffer();

    // Accounts
    buf.writeln('CUENTAS:');
    for (final a in accounts) {
      buf.writeln('- ${a.name}: \$${a.balance.toStringAsFixed(0)} (${a.type.name})');
    }

    // Monthly stats
    final now = DateTime.now();
    final monthTx = recentTx.where((t) =>
        t.date.month == now.month && t.date.year == now.year).toList();
    final monthIncome = monthTx
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final monthExpense = monthTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    buf.writeln('\nESTADÍSTICAS DEL MES:');
    buf.writeln('- Ingresos: \$${monthIncome.toStringAsFixed(0)}');
    buf.writeln('- Gastos: \$${monthExpense.toStringAsFixed(0)}');
    buf.writeln('- Balance: \$${(monthIncome - monthExpense).toStringAsFixed(0)}');

    // Top categories this month
    final catSpend = <String, double>{};
    for (final t in monthTx.where((t) => t.type == TransactionType.expense)) {
      catSpend[t.categoryId ?? 'otro'] = (catSpend[t.categoryId ?? 'otro'] ?? 0) + t.amount;
    }
    if (catSpend.isNotEmpty) {
      final sorted = catSpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      buf.writeln('\nTOP GASTOS POR CATEGORÍA:');
      for (final e in sorted.take(5)) {
        buf.writeln('- ${e.key}: \$${e.value.toStringAsFixed(0)}');
      }
    }

    // People debts
    final withDebts = people.where((p) => p.totalBalance != 0).toList();
    if (withDebts.isNotEmpty) {
      buf.writeln('\nDEUDAS CON PERSONAS:');
      for (final p in withDebts) {
        final dir = p.totalBalance > 0 ? 'me debe' : 'le debo';
        buf.writeln('- ${p.displayName}: $dir \$${p.totalBalance.abs().toStringAsFixed(0)}');
      }
    }

    // Budgets
    if (budgets.isNotEmpty) {
      buf.writeln('\nPRESUPUESTOS:');
      for (final b in budgets) {
        buf.writeln('- ${b.categoryName ?? b.categoryId}: \$${b.spentAmount.toStringAsFixed(0)} / \$${b.limitAmount.toStringAsFixed(0)}');
      }
    }

    // Goals
    if (goals.isNotEmpty) {
      buf.writeln('\nOBJETIVOS DE AHORRO:');
      for (final g in goals) {
        buf.writeln('- ${g.name}: \$${g.savedAmount.toStringAsFixed(0)} / \$${g.targetAmount.toStringAsFixed(0)}');
      }
    }

    // Recent transactions
    buf.writeln('\nÚLTIMOS 10 MOVIMIENTOS:');
    for (final t in recentTx.take(10)) {
      final sign = t.type == TransactionType.income ? '+' : '-';
      buf.writeln('- ${t.date.day}/${t.date.month}: $sign\$${t.amount.toStringAsFixed(0)} ${t.title} (${t.categoryId ?? ""})');
    }

    return buf.toString();
  }

  /// Send a message to Claude Haiku with financial context.
  static Future<String> chat({
    required String userMessage,
    required List<Account> accounts,
    required List<Transaction> recentTx,
    required List<Person> people,
    required List<Budget> budgets,
    required List<Goal> goals,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return 'Necesitás configurar tu API key de Anthropic en Ajustes para usar el asistente.';
    }

    final context = _buildContext(
      accounts: accounts,
      recentTx: recentTx,
      people: people,
      budgets: budgets,
      goals: goals,
    );

    final systemPrompt = '''Sos el asistente financiero de la app Sencillo. Respondés en español argentino, breve y directo.
Tenés acceso a los datos financieros del usuario (abajo). Usá esos datos para responder consultas sobre gastos, saldos, deudas, presupuestos y objetivos.
Si te piden agregar un gasto o hacer algo que no podés, decile que lo haga desde la app.
Respondé en 1-3 oraciones máximo. Sin emojis. Sin markdown.

DATOS FINANCIEROS DEL USUARIO:
$context''';

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 256,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': userMessage},
          ],
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return 'Error al consultar la IA (${response.statusCode})';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>;
      return (content.first as Map<String, dynamic>)['text'] as String;
    } catch (e) {
      return 'No pude conectarme con la IA. Revisá tu conexión.';
    }
  }
}
