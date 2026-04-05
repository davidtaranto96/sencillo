import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/logic/transaction_service.dart';
import '../../../../core/logic/account_service.dart';
import '../../../../core/logic/people_service.dart';
import '../../../../core/logic/ai_transaction_parser.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/models/nl_transaction.dart';
import '../../domain/models/transaction.dart';
import '../../../accounts/domain/models/account.dart' as dom_acc;
import '../../../people/domain/models/person.dart' as dom_p;
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../goals/domain/models/goal.dart';
import '../../../../core/logic/goal_service.dart';
import '../../../../core/logic/budget_service.dart';
import '../../../wishlist/presentation/providers/wishlist_provider.dart';
import '../../../../core/logic/wishlist_service.dart';
import '../../../../core/providers/shell_providers.dart';
import '../../../budget/domain/models/budget.dart' as dom_b;

// ─────────────────────────────────────────────────────────
// Mapa de íconos y colores por categoría (compartido con tiles)
// ─────────────────────────────────────────────────────────
const Map<String, IconData> kCategoryIcons = {
  'food': Icons.restaurant_rounded,
  'transport': Icons.directions_car_rounded,
  'health': Icons.local_hospital_rounded,
  'entertainment': Icons.movie_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'home': Icons.home_rounded,
  'education': Icons.school_rounded,
  'services': Icons.bolt_rounded,
  'salary': Icons.work_rounded,
  'freelance': Icons.laptop_rounded,
  'transfer': Icons.swap_horiz_rounded,
  'cat_alim': Icons.local_grocery_store_rounded,
  'cat_transp': Icons.local_gas_station_rounded,
  'cat_entret': Icons.sports_esports_rounded,
  'cat_salud': Icons.favorite_rounded,
  'cat_financial': Icons.payments_rounded,
  'cat_peer_to_peer': Icons.people_rounded,
  'other_expense': Icons.receipt_long_rounded,
  'other_income': Icons.attach_money_rounded,
};

const Map<String, String> kCategoryEmojis = {
  'food': '🍔',
  'transport': '🚗',
  'health': '🏥',
  'entertainment': '🎬',
  'shopping': '🛍️',
  'home': '🏠',
  'education': '📚',
  'services': '🔌',
  'salary': '💼',
  'freelance': '💻',
  'transfer': '🔄',
  'cat_alim': '🛒',
  'cat_transp': '⛽',
  'cat_entret': '🎮',
  'cat_salud': '❤️',
  'cat_financial': '💳',
  'cat_peer_to_peer': '👥',
  'other_expense': '💸',
  'other_income': '💰',
};

class AddTransactionBottomSheet extends ConsumerStatefulWidget {
  final bool startWithVoice;
  const AddTransactionBottomSheet({super.key, this.startWithVoice = false});

  static void show(BuildContext context, {bool startWithVoice = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionBottomSheet(startWithVoice: startWithVoice),
    );
  }

  @override
  ConsumerState<AddTransactionBottomSheet> createState() => _AddTransactionBottomSheetState();
}

class _AddTransactionBottomSheetState extends ConsumerState<AddTransactionBottomSheet> {
  // Mode
  bool _isSmart = true;

  // Manual form
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _selectedCategoryId = 'food';
  dom_acc.Account? _selectedAccount;
  DateTime _manualDate = DateTime.now();

  // AI form
  final _aiController = TextEditingController();
  bool _isAnalyzing = false;
  NLTransaction? _parsed;         // resultado del parsing
  bool _showConfirmation = false;  // mostrar tarjeta de confirmación
  List<_SuggestionItem> _liveSuggestions = [];  // sugerencias en tiempo real

  // Voice
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _aiController.addListener(_onAiInputChanged);
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
          if (_aiController.text.isNotEmpty) _processAiInput();
        }
      },
    );
    if (mounted) setState(() {});
    // Auto-start voice if requested
    if (widget.startWithVoice && _speechAvailable && mounted) {
      _toggleListening();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _aiController.removeListener(_onAiInputChanged);
    _aiController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Voz
  // ─────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_aiController.text.isNotEmpty) _processAiInput();
      return;
    }

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Micrófono no disponible en este dispositivo')),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _aiController.clear();
      _parsed = null;
      _showConfirmation = false;
    });

    await _speech.listen(
      onResult: (result) {
        setState(() => _aiController.text = result.recognizedWords);
      },
      localeId: 'es_AR',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  // ─────────────────────────────────────────────
  // Sugerencias en tiempo real (local, sin API)
  // ─────────────────────────────────────────────
  void _onAiInputChanged() {
    if (_showConfirmation) return;
    final text = _aiController.text;
    final suggestions = _generateSuggestions(text);
    if (mounted) setState(() => _liveSuggestions = suggestions);
  }

  List<_SuggestionItem> _generateSuggestions(String text) {
    if (text.trim().length < 3) return [];
    final lower = text.toLowerCase();
    final suggestions = <_SuggestionItem>[];

    // ── Amount extraction ──
    double? amount;
    final amtK = RegExp(r'(\d[\d,.]*)[\s]*(?:k|mil)\b', caseSensitive: false);
    final amtM = RegExp(r'(\d[\d,.]*)[\s]*(?:millones?|M)\b', caseSensitive: false);
    final amtN = RegExp(r'\b(\d[\d.,]{2,})\b');
    if (amtM.hasMatch(text)) {
      final m = amtM.firstMatch(text)!;
      amount = (double.tryParse(m.group(1)!.replaceAll('.','').replaceAll(',','.')) ?? 0) * 1000000;
    } else if (amtK.hasMatch(text)) {
      final m = amtK.firstMatch(text)!;
      amount = (double.tryParse(m.group(1)!.replaceAll('.','').replaceAll(',','.')) ?? 0) * 1000;
    } else if (amtN.hasMatch(text)) {
      final m = amtN.firstMatch(text)!;
      amount = double.tryParse(m.group(1)!.replaceAll('.','').replaceAll(',',''));
    }
    final amtStr = amount != null ? ' · ${formatAmount(amount)}' : '';
    final amtNum = amount != null ? amount.toInt().toString() : '2500';

    // ── Real app data for context-aware completions ──
    final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
    final goals  = ref.read(activeGoalsProvider);
    final firstName = people.isNotEmpty ? people.first.name : null;
    final firstGoal = goals.isNotEmpty ? goals.first.name : null;
    final withStr = firstName != null ? 'con $firstName' : 'con alguien';
    final toStr   = firstName != null ? 'a $firstName' : 'a alguien';
    final goalStr = firstGoal != null ? 'para $firstGoal' : 'para mi objetivo';

    // ── Shared expense ──
    if (lower.contains('dividí') || lower.contains('dividi') || lower.contains('compartí') ||
        lower.contains('comparti') || (lower.contains(' con ') && amount != null)) {
      suggestions.add(_SuggestionItem(
        '👥 Gasto compartido$amtStr',
        'Dividí $amtNum $withStr',
        NLScenario.sharedExpense,
      ));
    }
    // ── Loan given ──
    if (lower.contains('presté') || lower.contains('preste') || lower.contains('le presté') || lower.contains('le di plata')) {
      suggestions.add(_SuggestionItem(
        '🤝 Préstamo dado$amtStr',
        'Le presté $amtNum $toStr',
        NLScenario.loanGiven,
      ));
    }
    // ── Loan received ──
    if (lower.contains('me devolvió') || lower.contains('me devolvio') || lower.contains('me pagó') || lower.contains('me pago')) {
      final fromStr = firstName != null ? '$firstName me devolvió' : 'Me devolvieron';
      suggestions.add(_SuggestionItem(
        '💚 Devolución recibida$amtStr',
        '$fromStr $amtNum',
        NLScenario.loanReceived,
      ));
    }
    // ── Income ──
    if (lower.contains('cobré') || lower.contains('cobre') || lower.contains('sueldo') ||
        lower.contains('ingresé') || lower.contains('ingrese') || lower.contains('gané') || lower.contains('gane')) {
      suggestions.add(_SuggestionItem(
        '💵 Ingreso$amtStr',
        'Cobré $amtNum de sueldo',
        NLScenario.income,
      ));
    }
    // ── Goal contribution ──
    if (lower.contains('ahorré') || lower.contains('ahorre') || lower.contains('guardé') ||
        lower.contains('guarde') || lower.contains('objetivo') || lower.contains('meta') || lower.contains('ahorr')) {
      suggestions.add(_SuggestionItem(
        '🎯 Aporte a meta$amtStr',
        'Guardé $amtNum $goalStr',
        NLScenario.goalContribution,
      ));
    }
    // ── Internal transfer ──
    if (lower.contains('transferí') || lower.contains('transferi') || lower.contains('pasé') ||
        lower.contains('pase') || lower.contains('moví')) {
      suggestions.add(_SuggestionItem(
        '🔄 Transferencia$amtStr',
        'Transferí $amtNum entre cuentas',
        NLScenario.internalTransfer,
      ));
    }
    // ── Navigation ──
    if (lower.startsWith('ir') || lower.contains('ir a') || lower.contains('abrir') ||
        lower.contains('mostrar') || lower.contains('llévame') || lower.contains('llevame') ||
        lower.startsWith('abr') || lower.startsWith('mostr')) {
      String navTarget = 'personas';
      if (lower.contains('report') || lower.contains('estadís')) {
        navTarget = 'reportes';
      } else if (lower.contains('presup')) {
        navTarget = 'presupuestos';
      } else if (lower.contains('cuent')) {
        navTarget = 'cuentas';
      } else if (lower.contains('objeti') || lower.contains('meta')) {
        navTarget = 'objetivos';
      } else if (lower.contains('person') || lower.contains('amigo') || lower.contains('contacto')) {
        navTarget = 'personas';
      }
      suggestions.add(_SuggestionItem(
        '🧭 Ir a $navTarget',
        'Ir a $navTarget',
        NLScenario.navigateTo,
      ));
    }
    // ── Create person ──
    if (lower.contains('agregar') || lower.contains('añadir') || lower.contains('nuevo amigo') || lower.contains('nuevo contacto')) {
      suggestions.add(_SuggestionItem(
        '👤 Nuevo contacto',
        'Agregar a Pedro',
        NLScenario.createPerson,
      ));
    }
    // ── Query balance ──
    if (lower.contains('cuánto tengo') || lower.contains('cuanto tengo') || lower.contains('saldo') ||
        lower.contains('cuánto hay') || lower.contains('cuanto hay') || lower.contains('cuán') || lower.contains('tengo')) {
      suggestions.add(_SuggestionItem(
        '📊 Consultar saldo',
        '¿Cuánto tengo disponible?',
        NLScenario.queryBalance,
      ));
    }
    // ── Query budget ──
    if (lower.contains('cómo va') || lower.contains('como va') || lower.contains('mi presupuesto') || lower.contains('presup')) {
      suggestions.add(_SuggestionItem(
        '📈 Estado presupuesto',
        '¿Cómo va mi presupuesto?',
        NLScenario.queryBudget,
      ));
    }
    // ── Query debt ──
    if (lower.contains('me debe') || lower.contains('le debo')) {
      final debtStr = firstName != null ? '¿Cuánto me debe $firstName?' : '¿Cuánto me debe alguien?';
      suggestions.add(_SuggestionItem(
        '🤔 Consultar deuda',
        debtStr,
        NLScenario.queryDebt,
      ));
    }
    // ── Duplicate last transaction ──
    if (lower.contains('ayer') || lower.contains('mismo') || lower.contains('repetir') || lower.contains('repet')) {
      suggestions.add(_SuggestionItem(
        '🔁 Repetir último',
        'Lo mismo de ayer',
        NLScenario.duplicateLastTx,
      ));
    }
    // ── Settle debt ──
    if (lower.contains('saldar') || lower.contains('liquidar') || lower.contains('salda')) {
      final settleStr = firstName != null ? 'Saldar todo con $firstName' : 'Saldar toda la deuda';
      suggestions.add(_SuggestionItem(
        '💸 Saldar deuda',
        settleStr,
        NLScenario.settleDebt,
      ));
    }
    // ── Spend history → reports ──
    if (lower.contains('gasté esta') || lower.contains('gaste esta') ||
        lower.contains('gasté este') || lower.contains('gaste este') ||
        lower.contains('gasté en el') || lower.contains('cuánto gasté') || lower.contains('cuanto gaste')) {
      suggestions.add(_SuggestionItem(
        '📊 Ver historial',
        'Ir a reportes',
        NLScenario.navigateTo,
      ));
    }
    // ── Create goal ──
    if (lower.contains('crear') && lower.contains('objetivo') && amount != null) {
      suggestions.add(_SuggestionItem(
        '⭐ Crear objetivo$amtStr',
        'Crear objetivo viaje $amtNum',
        NLScenario.createGoal,
      ));
    }
    // ── Create budget ──
    if (lower.contains('crear') && lower.contains('presupuesto') && amount != null) {
      suggestions.add(_SuggestionItem(
        '📋 Crear presupuesto$amtStr',
        'Crear presupuesto comida $amtNum',
        NLScenario.createBudget,
      ));
    }
    // ── Default: gasto si hay monto ──
    if (suggestions.isEmpty && amount != null) {
      suggestions.add(_SuggestionItem('💸 Gasto$amtStr', 'Gasté $amtNum en supermercado', NLScenario.expense));
    }
    // ── Default: gasto por keyword ──
    if (suggestions.isEmpty && (lower.contains('gast') || lower.contains('pagué') || lower.contains('pag') || lower.contains('compr'))) {
      suggestions.add(_SuggestionItem('💸 Gasto', 'Gasté 2500 en supermercado', NLScenario.expense));
    }

    return suggestions.take(3).toList();
  }

  // ─────────────────────────────────────────────
  // Procesamiento IA
  // ─────────────────────────────────────────────
  Future<void> _processAiInput() async {
    final text = _aiController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _showConfirmation = false;
      _parsed = null;
    });

    final accounts = ref.read(accountsStreamProvider).value ?? [];
    final people = ref.read(peopleStreamProvider).value ?? [];
    final goals = ref.read(activeGoalsProvider);
    final budgets = ref.read(budgetsStreamProvider).valueOrNull ?? [];
    final wishlist = ref.read(activeWishlistProvider).valueOrNull ?? [];

    try {
      final result = await ref.read(aiTransactionParserProvider).parse(
        input: text,
        accounts: accounts,
        people: people,
        goals: goals,
        budgets: budgets,
        wishlist: wishlist,
      );

      if (mounted) {
        setState(() {
          _parsed = result;
          _isAnalyzing = false;
          _showConfirmation = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // Confirmar y ejecutar escenario
  // ─────────────────────────────────────────────
  Future<void> _confirmParsed(NLTransaction tx) async {
    final amount = tx.amount ?? 0;

    // Scenarios that don't need an amount
    const noAmountNeeded = {
      NLScenario.createGoal, NLScenario.createBudget,
      NLScenario.navigateTo, NLScenario.createPerson,
      NLScenario.queryBalance, NLScenario.queryBudget, NLScenario.queryDebt,
      NLScenario.duplicateLastTx, NLScenario.settleDebt,
    };
    if (amount <= 0 && !noAmountNeeded.contains(tx.scenario)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se detectó un monto válido')),
      );
      return;
    }

    final accounts = ref.read(accountsStreamProvider).value ?? [];
    final defaultAccount = accounts.isNotEmpty
        ? accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first)
        : null;
    final accountId = tx.accountId ?? defaultAccount?.id;

    try {
      switch (tx.scenario) {
        case NLScenario.createGoal:
          final name = tx.title ?? 'Nuevo objetivo';
          await ref.read(goalServiceProvider).addGoal(
            name: name,
            targetAmount: amount > 0 ? amount : 0,
            colorValue: AppTheme.colorTransfer.toARGB32(),
            iconName: 'flag',
            deadline: null,
          );
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Objetivo "$name" creado${amount > 0 ? ' por ${formatAmount(amount)}' : ''}'),
                backgroundColor: AppTheme.colorTransfer.withValues(alpha: 0.8),
              ),
            );
          }
          return;

        case NLScenario.createBudget:
          final name = tx.title ?? 'Nuevo presupuesto';
          final catId = tx.budgetCategoryId;
          if (catId != null) {
            await ref.read(budgetServiceProvider).addBudgetForCategory(
              categoryId: catId,
              categoryName: name,
              limitAmount: amount > 0 ? amount : 0,
              isFixed: false,
              colorValue: AppTheme.colorWarning.toARGB32(),
              iconKey: 'receipt_long',
            );
          } else {
            await ref.read(budgetServiceProvider).addBudget(
              categoryName: name,
              limitAmount: amount > 0 ? amount : 0,
              isFixed: false,
              colorValue: AppTheme.colorWarning.toARGB32(),
              iconKey: 'receipt_long',
            );
          }
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Presupuesto "$name" creado${amount > 0 ? ' por ${formatAmount(amount)}' : ''}'),
                backgroundColor: AppTheme.colorWarning.withValues(alpha: 0.8),
              ),
            );
          }
          return;

        case NLScenario.expense:
        case NLScenario.goalContribution:
        case NLScenario.wishlistPurchase:
          if (accountId == null) throw Exception('Sin cuenta');
          await ref.read(transactionServiceProvider).addTransaction(
            title: tx.title ?? 'Gasto',
            amount: amount,
            type: 'expense',
            categoryId: tx.categoryId ?? 'other_expense',
            accountId: accountId,
            note: tx.note ?? tx.rawInput,
          );
          if (tx.scenario == NLScenario.goalContribution && tx.goalId != null) {
            // Actualizar el objetivo con el monto ahorrado
            final goals = ref.read(activeGoalsProvider);
            final goal = goals.where((g) => g.id == tx.goalId).firstOrNull;
            if (goal != null) {
              final newSaved = goal.savedAmount + amount;
              await ref.read(goalServiceProvider).updateGoal(
                tx.goalId!, currentAmount: newSaved,
              );
            }
          }
          if (tx.scenario == NLScenario.wishlistPurchase && tx.wishlistItemId != null) {
            await ref.read(wishlistServiceProvider).markAsPurchased(tx.wishlistItemId!, method: 'account');
          }
          break;

        case NLScenario.income:
          if (accountId == null) throw Exception('Sin cuenta');
          await ref.read(transactionServiceProvider).addTransaction(
            title: tx.title ?? 'Ingreso',
            amount: amount,
            type: 'income',
            categoryId: tx.categoryId ?? 'other_income',
            accountId: accountId,
            note: tx.note ?? tx.rawInput,
          );
          break;

        case NLScenario.cardPayment:
          final cardId = tx.cardId;
          final sourceId = tx.accountId;
          if (cardId == null || sourceId == null) {
            // No tenemos suficiente info, guardar como expense
            if (accountId != null) {
              await ref.read(transactionServiceProvider).addTransaction(
                title: tx.title ?? 'Pago tarjeta',
                amount: amount,
                type: 'expense',
                categoryId: 'cat_financial',
                accountId: accountId,
                note: tx.note ?? tx.rawInput,
              );
            }
          } else {
            await ref.read(accountServiceProvider).payCardStatement(
              sourceAccountId: sourceId,
              cardAccountId: cardId,
              amount: amount,
            );
          }
          break;

        case NLScenario.loanGiven:
          final pid = tx.personId;
          if (pid != null && accountId != null) {
            await ref.read(peopleServiceProvider).recordDirectDebt(
              personId: pid,
              amount: amount,
              iLent: true,
              description: tx.title ?? 'Préstamo',
              accountId: accountId,
            );
          } else if (accountId != null) {
            await ref.read(transactionServiceProvider).addTransaction(
              title: tx.title ?? 'Préstamo dado',
              amount: amount,
              type: 'expense',
              categoryId: 'cat_peer_to_peer',
              accountId: accountId,
              note: tx.note ?? tx.rawInput,
            );
          }
          break;

        case NLScenario.loanReceived:
          final pid = tx.personId;
          if (pid != null && accountId != null) {
            await ref.read(peopleServiceProvider).liquidateDebt(
              personId: pid,
              amount: amount,
              accountId: accountId,
            );
          } else if (accountId != null) {
            await ref.read(transactionServiceProvider).addTransaction(
              title: tx.title ?? 'Deuda recuperada',
              amount: amount,
              type: 'income',
              categoryId: 'cat_peer_to_peer',
              accountId: accountId,
              note: tx.note ?? tx.rawInput,
            );
          }
          break;

        case NLScenario.loanRepayment:
          // Yo le pagué a alguien lo que le debía (mi deuda con ellos baja)
          final pid = tx.personId;
          if (pid != null && accountId != null) {
            await ref.read(peopleServiceProvider).recordDirectDebt(
              personId: pid,
              amount: amount,
              iLent: false, // ellos me prestaron, yo devuelvo → saldo negativo → liquidar
              description: tx.title ?? 'Devolución de préstamo',
              accountId: accountId,
            );
          } else if (accountId != null) {
            await ref.read(transactionServiceProvider).addTransaction(
              title: tx.title ?? 'Devolución de préstamo',
              amount: amount,
              type: 'expense',
              categoryId: 'cat_peer_to_peer',
              accountId: accountId,
              note: tx.note ?? tx.rawInput,
            );
          }
          break;

        case NLScenario.sharedExpense:
          final pid = tx.personId;
          final ownAmt = tx.splitOwnAmount ?? amount / 2;
          final otherAmt = tx.splitOtherAmount ?? amount / 2;
          if (pid != null && accountId != null) {
            await ref.read(peopleServiceProvider).recordSharedExpense(
              personId: pid,
              totalAmount: amount,
              iPaid: true,
              ownAmount: ownAmt,
              otherAmount: otherAmt,
              description: tx.title ?? 'Gasto compartido',
              accountId: accountId,
            );
          } else if (accountId != null) {
            await ref.read(transactionServiceProvider).addTransaction(
              title: tx.title ?? 'Gasto compartido',
              amount: ownAmt,
              type: 'expense',
              categoryId: 'cat_peer_to_peer',
              accountId: accountId,
              note: tx.note ?? tx.rawInput,
            );
          }
          break;

        case NLScenario.internalTransfer:
          // Transferencia entre mis propias cuentas
          final srcId = tx.accountId;
          final tgtId = tx.targetAccountId;
          if (srcId != null && tgtId != null) {
            await ref.read(transactionServiceProvider).addTransaction(
              title: tx.title ?? 'Transferencia saliente',
              amount: amount,
              type: 'expense',
              categoryId: 'transfer',
              accountId: srcId,
              note: tx.rawInput,
            );
            await ref.read(transactionServiceProvider).addTransaction(
              title: tx.title ?? 'Transferencia entrante',
              amount: amount,
              type: 'income',
              categoryId: 'transfer',
              accountId: tgtId,
              note: tx.rawInput,
            );
          } else if (srcId != null) {
            await ref.read(transactionServiceProvider).addTransaction(
              title: tx.title ?? 'Transferencia',
              amount: amount,
              type: 'expense',
              categoryId: 'transfer',
              accountId: srcId,
              note: tx.rawInput,
            );
          }
          break;

        case NLScenario.navigateTo:
          final target = tx.navigationTarget;
          if (target != null && mounted) {
            Navigator.of(context).pop();
            ref.read(navigateToTabProvider.notifier).state = target;
          }
          return;

        case NLScenario.createPerson:
          final name = tx.personName;
          if (name != null && name.isNotEmpty) {
            await ref.read(peopleServiceProvider).addPerson(name: name);
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Contacto "$name" agregado'),
                  backgroundColor: AppTheme.colorTransfer.withValues(alpha: 0.8),
                ),
              );
            }
          }
          return;

        case NLScenario.queryBalance:
          if (mounted) {
            Navigator.of(context).pop();
            ref.read(navigateToTabProvider.notifier).state = 'accounts';
          }
          return;

        case NLScenario.queryBudget:
          if (mounted) {
            Navigator.of(context).pop();
            ref.read(navigateToTabProvider.notifier).state = 'budget';
          }
          return;

        case NLScenario.queryDebt:
          if (mounted) {
            Navigator.of(context).pop();
            ref.read(navigateToTabProvider.notifier).state = 'people';
          }
          return;

        case NLScenario.duplicateLastTx:
          final txs = ref.read(transactionsStreamProvider).value ?? [];
          final lastTx = txs.isNotEmpty ? txs.first : null;
          if (lastTx != null) {
            await ref.read(transactionServiceProvider).duplicateTransaction(lastTx.id);
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${lastTx.title}" registrado de nuevo'),
                  backgroundColor: AppTheme.colorTransfer.withValues(alpha: 0.85),
                ),
              );
            }
          }
          return;

        case NLScenario.settleDebt:
          final personId = tx.personId;
          if (personId != null) {
            final peopleList = ref.read(peopleStreamProvider).value ?? [];
            final person = peopleList.where((p) => p.id == personId).firstOrNull;
            if (person != null && person.totalBalance != 0) {
              await ref.read(peopleServiceProvider).liquidateDebt(
                personId: personId,
                amount: person.totalBalance.abs(),
              );
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deuda con ${person.name} saldada'),
                    backgroundColor: AppTheme.colorIncome.withValues(alpha: 0.85),
                  ),
                );
              }
            }
          } else {
            if (mounted) {
              Navigator.of(context).pop();
              ref.read(navigateToTabProvider.notifier).state = 'people';
            }
          }
          return;

        case NLScenario.unclear:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo interpretar el movimiento. Usá el modo manual.')),
          );
          setState(() => _isSmart = false);
          return;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tx.scenarioLabel} registrado: ${tx.title}'),
            backgroundColor: Colors.green.withValues(alpha: 0.8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // Manual save
  // ─────────────────────────────────────────────
  void _saveManualTransaction() async {
    if (_amountController.text.isEmpty || _selectedAccount == null) return;
    final amount = parseFormattedAmount(_amountController.text);
    final typeStr = _type == TransactionType.income ? 'income' : _type == TransactionType.transfer ? 'transfer' : 'expense';
    await ref.read(transactionServiceProvider).addTransaction(
      title: _titleController.text.isEmpty ? 'Movimiento' : _titleController.text,
      amount: amount,
      type: typeStr,
      categoryId: _selectedCategoryId,
      accountId: _selectedAccount!.id,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      date: _manualDate,
    );
    if (mounted) Navigator.pop(context);
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    if (_selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
    }

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Movimiento', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                _SmartToggle(
                  isSmart: _isSmart,
                  onChanged: (val) => setState(() {
                    _isSmart = val;
                    _showConfirmation = false;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isSmart) _buildSmartUI(cs) else _buildManualUI(cs, accounts),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Smart UI (IA + Voz)
  // ─────────────────────────────────────────────
  Widget _buildSmartUI(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Escribí o dictá tu movimiento en lenguaje natural.',
          style: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // ── Input area — glassmorphism upgrade ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: _isListening ? 0.08 : 0.05),
                Colors.white.withValues(alpha: _isListening ? 0.04 : 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isListening
                  ? AppTheme.colorExpense.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.10),
              width: _isListening ? 1.5 : 1.0,
            ),
            boxShadow: _isListening
                ? [BoxShadow(color: AppTheme.colorExpense.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: 2)]
                : [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _isListening
                    ? Row(
                        children: [
                          _PulsingDot(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _aiController.text.isEmpty ? 'Escuchando...' : _aiController.text,
                              style: GoogleFonts.inter(
                                color: _aiController.text.isEmpty
                                    ? AppTheme.colorExpense.withValues(alpha: 0.7)
                                    : Colors.white,
                                fontStyle: _aiController.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      )
                    : TextField(
                        controller: _aiController,
                        autofocus: true,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Ej. Pagué 45 mil de sushi con Juan...',
                          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _processAiInput(),
                      ),
              ),
              const SizedBox(width: 10),
              // Mic button with ripple animation
              _MicButton(
                isListening: _isListening,
                onTap: _toggleListening,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Live suggestions (aparecen mientras escribe) ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, axisAlignment: -1, child: child),
          ),
          child: (!_showConfirmation && !_isAnalyzing && _liveSuggestions.isNotEmpty)
              ? Padding(
                  key: const ValueKey('live_suggestions'),
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interpretando como:',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _liveSuggestions
                            .map((s) => _LiveSuggestionChip(
                                  item: s,
                                  controller: _aiController,
                                  onTap: () => setState(() {}),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('no_suggestions')),
        ),

        // ── Ejemplos de uso (cuando input vacío) ──
        if (!_showConfirmation && !_isAnalyzing && _aiController.text.isEmpty) ...[
          Text(
            'Ejemplos:',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _ExampleChip('Pagué 4500 de sushi', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Cobré el sueldo 200k', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Dividí taxi con María 3600', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Presté 10k a Juan', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Ir a reportes', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Cuánto tengo?', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Agregar a Pedro', _aiController, () => setState(() {})),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Tarjeta de confirmación ──
        if (_showConfirmation && _parsed != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _AiConfirmationCard(
              key: ValueKey(_parsed!.rawInput),
              tx: _parsed!,
              accounts: ref.watch(accountsStreamProvider).value ?? [],
              people: ref.watch(peopleStreamProvider).value ?? [],
              budgets: ref.watch(budgetsStreamProvider).valueOrNull ?? [],
              onConfirm: _confirmParsed,
              onEdit: () => setState(() {
                _showConfirmation = false;
                _liveSuggestions = _generateSuggestions(_aiController.text);
              }),
            ),
          )
        else
          // ── Process button / shimmer ──
          _isAnalyzing
              ? _AnalyzingButton()
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _processAiInput,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.colorTransfer,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Analizar con IA ✦',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Manual UI
  // ─────────────────────────────────────────────
  Widget _buildManualUI(ColorScheme cs, List<dom_acc.Account> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsSeparatorFormatter()],
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white),
          decoration: const InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: Colors.white10),
            prefixText: r'$ ',
            prefixStyle: TextStyle(color: Colors.white24, fontSize: 30),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 8),
        _TypeSelector(current: _type, onChanged: (val) => setState(() => _type = val)),
        const SizedBox(height: 8),

        // Title
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: '¿En qué se gastó?',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.edit_outlined, color: Colors.white24, size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 26),
            border: InputBorder.none,
          ),
        ),

        // Note (optional)
        TextField(
          controller: _noteController,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Nota (opcional)',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.sticky_note_2_outlined, color: Colors.white24, size: 16),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 26),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 12),

        // Date + Account row
        Row(
          children: [
            // Date picker
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _manualDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.colorTransfer,
                        surface: Color(0xFF1E1E2C),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (date != null) setState(() => _manualDate = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _isToday(_manualDate) ? 'Hoy' : DateFormat('d MMM', 'es').format(_manualDate),
                      style: GoogleFonts.inter(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Account selector
            if (accounts.isNotEmpty)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: DropdownButton<dom_acc.Account>(
                    value: _selectedAccount,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E2C),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    underline: const SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 18),
                    items: accounts.map((a) => DropdownMenuItem(
                      value: a,
                      child: Row(
                        children: [
                          Icon(
                            a.isCreditCard ? Icons.credit_card_rounded : Icons.account_balance_wallet_outlined,
                            size: 14,
                            color: AppTheme.colorTransfer,
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedAccount = val),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Category
        Text('Categoría', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: kCategoryEmojis.entries.map((entry) {
              final isSelected = _selectedCategoryId == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => setState(() => _selectedCategoryId = entry.key),
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.colorTransfer.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppTheme.colorTransfer : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(entry.value, style: const TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _categoryLabel(entry.key),
                        style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _saveManualTransaction,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.colorTransfer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _categoryLabel(String key) {
    const labels = {
      'food': 'Comida',
      'transport': 'Transp.',
      'health': 'Salud',
      'entertainment': 'Ocio',
      'shopping': 'Compras',
      'home': 'Hogar',
      'education': 'Educ.',
      'services': 'Serv.',
      'salary': 'Sueldo',
      'freelance': 'Freelance',
      'transfer': 'Transf.',
      'cat_alim': 'Aliment.',
      'cat_transp': 'Nafta',
      'cat_entret': 'Juegos',
      'cat_salud': 'Salud',
      'cat_financial': 'Finanzas',
      'cat_peer_to_peer': 'Personas',
      'other_expense': 'Otro',
      'other_income': 'Ingreso',
    };
    return labels[key] ?? key;
  }
}

// ─────────────────────────────────────────────────────────
// Tarjeta de confirmación de IA
// ─────────────────────────────────────────────────────────
class _AiConfirmationCard extends ConsumerStatefulWidget {
  final NLTransaction tx;
  final List<dom_acc.Account> accounts;
  final List<dom_p.Person> people;
  final List<dom_b.Budget> budgets;
  final void Function(NLTransaction) onConfirm;
  final VoidCallback onEdit;

  const _AiConfirmationCard({
    super.key,
    required this.tx,
    required this.accounts,
    required this.people,
    required this.budgets,
    required this.onConfirm,
    required this.onEdit,
  });

  @override
  ConsumerState<_AiConfirmationCard> createState() => _AiConfirmationCardState();
}

class _AiConfirmationCardState extends ConsumerState<_AiConfirmationCard> {
  late NLTransaction _tx;
  late TextEditingController _amountCtrl;
  late TextEditingController _titleCtrl;
  dom_acc.Account? _selectedAccount;
  dom_acc.Account? _selectedTargetAccount;
  dom_acc.Account? _selectedCard;
  dom_p.Person? _selectedPerson;
  Goal? _selectedGoal;

  // Scenarios that involve a person
  static const _personScenarios = {
    NLScenario.loanGiven,
    NLScenario.loanReceived,
    NLScenario.loanRepayment,
    NLScenario.sharedExpense,
  };

  @override
  void initState() {
    super.initState();
    _tx = widget.tx;
    _amountCtrl = TextEditingController(text: _tx.amount != null ? formatInitialAmount(_tx.amount!) : '');
    _titleCtrl = TextEditingController(text: _tx.title ?? '');

    // Pre-select account from parsed result, or default
    if (widget.accounts.isNotEmpty) {
      final txAccId = _tx.accountId;
      _selectedAccount = txAccId != null
          ? widget.accounts.firstWhere((a) => a.id == txAccId, orElse: () => widget.accounts.first)
          : widget.accounts.firstWhere((a) => a.isDefault, orElse: () => widget.accounts.first);
    }

    // Pre-select target account for internalTransfer
    if (_tx.scenario == NLScenario.internalTransfer && _tx.targetAccountId != null && widget.accounts.isNotEmpty) {
      _selectedTargetAccount = widget.accounts.firstWhere(
        (a) => a.id == _tx.targetAccountId,
        orElse: () => widget.accounts.first,
      );
    }

    // Pre-select card for cardPayment
    if (_tx.scenario == NLScenario.cardPayment && _tx.cardId != null && widget.accounts.isNotEmpty) {
      _selectedCard = widget.accounts.where((a) => a.id == _tx.cardId).firstOrNull;
      // For card payment, source account should be non-credit
      if (_selectedAccount?.isCreditCard == true) {
        _selectedAccount = widget.accounts.where((a) => !a.isCreditCard).firstOrNull;
      }
    }

    // Pre-select person from parsed result
    if (_tx.personId != null && widget.people.isNotEmpty) {
      try {
        _selectedPerson = widget.people.firstWhere((p) => p.id == _tx.personId);
      } catch (_) {}
    }

    // Pre-select goal for goalContribution
    if (_tx.scenario == NLScenario.goalContribution && _tx.goalId != null) {
      final goals = ref.read(activeGoalsProvider);
      _selectedGoal = goals.where((g) => g.id == _tx.goalId).firstOrNull;
    }
  }

  NLTransaction get _finalTx => _tx.copyWith(
        accountId: _selectedAccount?.id,
        targetAccountId: _selectedTargetAccount?.id,
        cardId: _selectedCard?.id,
        personId: _selectedPerson?.id,
        goalId: _selectedGoal?.id,
      );

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Color get _scenarioColor {
    switch (_tx.scenario) {
      case NLScenario.income:
      case NLScenario.loanReceived:
        return AppTheme.colorIncome;
      case NLScenario.cardPayment:
      case NLScenario.createBudget:
      case NLScenario.queryBudget:
        return AppTheme.colorWarning;
      case NLScenario.loanGiven:
      case NLScenario.expense:
      case NLScenario.loanRepayment:
        return AppTheme.colorExpense;
      case NLScenario.goalContribution:
      case NLScenario.wishlistPurchase:
      case NLScenario.internalTransfer:
      case NLScenario.createGoal:
        return AppTheme.colorTransfer;
      case NLScenario.sharedExpense:
        return Colors.orange;
      case NLScenario.navigateTo:
        return const Color(0xFF6C63FF);
      case NLScenario.createPerson:
        return const Color(0xFF4ECDC4);
      case NLScenario.queryBalance:
      case NLScenario.queryDebt:
        return AppTheme.colorTransfer;
      case NLScenario.duplicateLastTx:
        return AppTheme.colorTransfer;
      case NLScenario.settleDebt:
        return AppTheme.colorIncome;
      case NLScenario.unclear:
        return Colors.white54;
    }
  }

  IconData get _scenarioIcon {
    switch (_tx.scenario) {
      case NLScenario.income:
        return Icons.arrow_downward_rounded;
      case NLScenario.expense:
        return Icons.arrow_upward_rounded;
      case NLScenario.cardPayment:
        return Icons.credit_card_rounded;
      case NLScenario.loanGiven:
        return Icons.person_add_alt_1_rounded;
      case NLScenario.loanReceived:
        return Icons.person_remove_rounded;
      case NLScenario.loanRepayment:
        return Icons.reply_rounded;
      case NLScenario.sharedExpense:
        return Icons.group_rounded;
      case NLScenario.internalTransfer:
        return Icons.swap_horiz_rounded;
      case NLScenario.goalContribution:
        return Icons.flag_rounded;
      case NLScenario.wishlistPurchase:
        return Icons.shopping_cart_checkout_rounded;
      case NLScenario.createGoal:
        return Icons.emoji_events_rounded;
      case NLScenario.createBudget:
        return Icons.donut_large_rounded;
      case NLScenario.navigateTo:
        return Icons.explore_rounded;
      case NLScenario.createPerson:
        return Icons.person_add_rounded;
      case NLScenario.queryBalance:
        return Icons.account_balance_wallet_rounded;
      case NLScenario.queryBudget:
        return Icons.pie_chart_rounded;
      case NLScenario.queryDebt:
        return Icons.handshake_rounded;
      case NLScenario.duplicateLastTx:
        return Icons.repeat_rounded;
      case NLScenario.settleDebt:
        return Icons.check_circle_outline_rounded;
      case NLScenario.unclear:
        return Icons.help_outline_rounded;
    }
  }

  String? _accountName(String? id) {
    if (id == null) return null;
    return widget.accounts.firstWhere((a) => a.id == id, orElse: () => widget.accounts.first).name;
  }

  /// Returns a human-readable category name. For predefined categories
  /// uses the label map; for UUID-based (custom budget) categories, uses
  /// the title from the parsed transaction which already has the budget name.
  String _categoryDisplayName(String categoryId) {
    const labels = {
      'food': 'Comida', 'transport': 'Transporte', 'health': 'Salud',
      'entertainment': 'Ocio', 'shopping': 'Compras', 'home': 'Hogar',
      'education': 'Educación', 'services': 'Servicios', 'salary': 'Sueldo',
      'freelance': 'Freelance', 'transfer': 'Transferencia',
      'cat_financial': 'Financiero', 'cat_peer_to_peer': 'Personas',
      'other_expense': 'Otros', 'other_income': 'Ingreso',
    };
    if (labels.containsKey(categoryId)) return labels[categoryId]!;
    // For UUID-based categories (custom budgets), use the parsed title
    return _tx.title ?? categoryId.split('-').first;
  }

  Widget _buildInfoCard(BuildContext context, Color color) {
    final accounts = widget.accounts;
    final people = widget.people;
    final budgets = widget.budgets;

    String title;
    String body;
    String actionLabel;

    switch (_tx.scenario) {
      case NLScenario.navigateTo:
        final tabNames = {
          'home': 'Inicio', 'transactions': 'Movimientos', 'budget': 'Presupuesto',
          'goals': 'Objetivos', 'people': 'Personas', 'reports': 'Reportes',
          'accounts': 'Cuentas', 'monthly_overview': 'Resumen mensual',
          'wishlist': 'Lista de compras', 'savings': 'Ahorros',
        };
        final dest = tabNames[_tx.navigationTarget] ?? _tx.navigationTarget ?? 'esa sección';
        title = 'Navegar a $dest';
        body = 'Te llevo directo a $dest.';
        actionLabel = 'Ir ahora →';
        break;
      case NLScenario.createPerson:
        final name = _tx.personName ?? '';
        title = 'Nuevo contacto: $name';
        body = 'Se agregará "$name" a tu lista de personas.';
        actionLabel = 'Agregar contacto';
        break;
      case NLScenario.queryBalance:
        final total = accounts.fold(0.0, (sum, a) => sum + a.balance);
        final lines = accounts.take(4).map((a) => '${a.name}: ${formatAmount(a.balance)}').join('\n');
        title = 'Saldo total: ${formatAmount(total)}';
        body = lines.isNotEmpty ? lines : 'No tenés cuentas configuradas.';
        actionLabel = 'Ir a Cuentas';
        break;
      case NLScenario.queryBudget:
        dom_b.Budget? budget;
        if (_tx.categoryId != null) {
          budget = budgets.where((b) => b.categoryId == _tx.categoryId).firstOrNull;
        }
        budget ??= budgets.firstOrNull;
        if (budget != null) {
          final pct = budget.limitAmount > 0 ? (budget.spentAmount / budget.limitAmount * 100).clamp(0, 100).toInt() : 0;
          title = 'Presupuesto: ${budget.categoryName}';
          body = 'Gastado: ${formatAmount(budget.spentAmount)} de ${formatAmount(budget.limitAmount)} ($pct%)';
        } else {
          title = 'Sin presupuestos';
          body = 'No tenés presupuestos activos. Creá uno desde Presupuesto.';
        }
        actionLabel = 'Ver presupuestos';
        break;
      case NLScenario.queryDebt:
        dom_p.Person? person;
        if (_tx.personId != null) {
          person = people.where((p) => p.id == _tx.personId).firstOrNull;
        } else if (_tx.personName != null) {
          final name = _tx.personName!.toLowerCase();
          person = people.where((p) => p.name.toLowerCase().contains(name)).firstOrNull;
        }
        if (person != null) {
          final balance = person.totalBalance;
          title = balance > 0
              ? '${person.name} te debe ${formatAmount(balance)}'
              : balance < 0
                  ? 'Le debés ${formatAmount(balance.abs())} a ${person.name}'
                  : '${person.name} — Sin deuda';
          body = balance == 0 ? 'Están al día.' : '';
        } else {
          title = 'Persona no encontrada';
          body = _tx.personName != null
              ? '"${_tx.personName}" no está en tu lista de contactos.'
              : 'No se detectó a quién consultar.';
        }
        actionLabel = 'Ver personas';
        break;
      case NLScenario.duplicateLastTx:
        final txs = ref.read(transactionsStreamProvider).value ?? [];
        final last = txs.isNotEmpty ? txs.first : null;
        if (last != null) {
          title = '🔁 Repetir movimiento';
          body = '"${last.title}"\n${formatAmount(last.amount)} · Se registrará con la fecha de hoy.';
          actionLabel = 'Registrar de nuevo';
        } else {
          title = 'Sin movimientos previos';
          body = 'No hay movimientos anteriores para repetir.';
          actionLabel = 'Cerrar';
        }
        break;
      case NLScenario.settleDebt:
        dom_p.Person? debtPerson;
        if (_tx.personId != null) {
          debtPerson = people.where((p) => p.id == _tx.personId).firstOrNull;
        } else if (_tx.personName != null) {
          final name = _tx.personName!.toLowerCase();
          debtPerson = people.where((p) => p.name.toLowerCase().contains(name)).firstOrNull;
        }
        if (debtPerson != null) {
          final balance = debtPerson.totalBalance;
          if (balance > 0) {
            title = '💸 Saldar con ${debtPerson.name}';
            body = '${debtPerson.name} te debe ${formatAmount(balance)}.\nSe registrará el cobro completo.';
            actionLabel = 'Cobrar ahora';
          } else if (balance < 0) {
            title = '💸 Saldar con ${debtPerson.name}';
            body = 'Le debés ${formatAmount(balance.abs())} a ${debtPerson.name}.\nSe registrará el pago completo.';
            actionLabel = 'Pagar ahora';
          } else {
            title = 'Sin deuda pendiente';
            body = 'Están al día con ${debtPerson.name}.';
            actionLabel = 'Cerrar';
          }
        } else {
          title = '¿Con quién?';
          body = _tx.personName != null
              ? '"${_tx.personName}" no está en tu lista de contactos.'
              : 'No se detectó a quién saldarle la deuda.';
          actionLabel = 'Ver personas';
        }
        break;
      default:
        title = _tx.scenarioLabel;
        body = '';
        actionLabel = 'OK';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_scenarioIcon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                body,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => widget.onConfirm(_finalTx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(actionLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _scenarioColor;

    // ── Info-only card for navigate/query scenarios ──
    if (_tx.scenario == NLScenario.navigateTo ||
        _tx.scenario == NLScenario.queryBalance ||
        _tx.scenario == NLScenario.queryBudget ||
        _tx.scenario == NLScenario.queryDebt ||
        _tx.scenario == NLScenario.createPerson ||
        _tx.scenario == NLScenario.duplicateLastTx ||
        _tx.scenario == NLScenario.settleDebt) {
      return _buildInfoCard(context, color);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_scenarioIcon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tx.scenarioLabel,
                      style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '"${_tx.rawInput}"',
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monto editable
          Row(
            children: [
              const Text(r'$ ', style: TextStyle(color: Colors.white54, fontSize: 18)),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  onChanged: (v) => _tx = _tx.copyWith(amount: parseFormattedAmount(v)),
                ),
              ),
            ],
          ),

          // Título editable
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Descripción...',
              hintStyle: TextStyle(color: Colors.white24),
            ),
            onChanged: (v) => _tx = _tx.copyWith(title: v),
          ),

          const SizedBox(height: 8),

          // Detalles detectados (categoría y tarjeta)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (_tx.categoryId != null)
                _InfoChip('${kCategoryEmojis[_tx.categoryId] ?? '📌'} ${_categoryDisplayName(_tx.categoryId!)}', color),
              if (_accountName(_tx.cardId) != null)
                _InfoChip('💳 ${_accountName(_tx.cardId)}', Colors.white38),
            ],
          ),

          const SizedBox(height: 12),

          // Selector de tarjeta + cuenta origen para cardPayment
          if (_tx.scenario == NLScenario.cardPayment && widget.accounts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.colorWarning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.colorWarning.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💳 Tarjeta a pagar:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  _AccountDropdown(
                    accounts: widget.accounts.where((a) => a.isCreditCard).toList(),
                    value: _selectedCard ?? widget.accounts.where((a) => a.id == _tx.cardId).cast<dom_acc.Account?>().firstOrNull,
                    onChanged: (a) => setState(() => _selectedCard = a),
                  ),
                  const SizedBox(height: 8),
                  const Text('🏦 Pagás desde:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  _AccountDropdown(
                    accounts: widget.accounts.where((a) => !a.isCreditCard).toList(),
                    value: _selectedAccount,
                    onChanged: (a) => setState(() => _selectedAccount = a),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Selector de cuenta (no para cardPayment, createGoal, createBudget)
          if (_tx.scenario != NLScenario.cardPayment &&
              _tx.scenario != NLScenario.createGoal &&
              _tx.scenario != NLScenario.createBudget &&
              widget.accounts.isNotEmpty) ...[
            Text(
              _tx.scenario == NLScenario.internalTransfer ? 'Cuenta origen:' : 'Cuenta:',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 4),
            _AccountDropdown(
              accounts: widget.accounts,
              value: _selectedAccount,
              onChanged: (a) => setState(() => _selectedAccount = a),
            ),
            const SizedBox(height: 8),
          ],

          // Selector de cuenta destino (solo internalTransfer)
          if (_tx.scenario == NLScenario.internalTransfer && widget.accounts.isNotEmpty) ...[
            const Text('Cuenta destino:', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            _AccountDropdown(
              accounts: widget.accounts.where((a) => a.id != _selectedAccount?.id).toList(),
              value: _selectedTargetAccount?.id == _selectedAccount?.id ? null : _selectedTargetAccount,
              onChanged: (a) => setState(() => _selectedTargetAccount = a),
            ),
            const SizedBox(height: 8),
          ],

          // Selector de persona (loanGiven, loanReceived, loanRepayment, sharedExpense)
          if (_personScenarios.contains(_tx.scenario) && widget.people.isNotEmpty) ...[
            const Text('Persona:', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButton<dom_p.Person>(
                value: _selectedPerson,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E2C),
                underline: const SizedBox(),
                hint: const Text('Seleccioná una persona', style: TextStyle(color: Colors.white38, fontSize: 13)),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: widget.people.map((p) => DropdownMenuItem(
                  value: p,
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: Colors.white38),
                      const SizedBox(width: 6),
                      Text(p.displayName),
                    ],
                  ),
                )).toList(),
                onChanged: (p) => setState(() => _selectedPerson = p),
              ),
            ),
            // Balance info si hay persona seleccionada
            if (_selectedPerson != null) ...[
              const SizedBox(height: 6),
              _PersonBalanceChip(_selectedPerson!, _tx, color),
            ],
            const SizedBox(height: 8),
          ],

          // Selector de objetivo para goalContribution
          if (_tx.scenario == NLScenario.goalContribution) ...[
            const Text('Objetivo:', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final goals = ref.watch(activeGoalsProvider);
                if (goals.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('No tenés objetivos activos',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  );
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<Goal>(
                    value: _selectedGoal,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E2C),
                    underline: const SizedBox(),
                    hint: const Text('Seleccioná un objetivo',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: goals.map((g) => DropdownMenuItem(
                      value: g,
                      child: Row(
                        children: [
                          Icon(g.icon, size: 14, color: g.color),
                          const SizedBox(width: 6),
                          Expanded(child: Text(g.name, overflow: TextOverflow.ellipsis)),
                          Text(
                            '${(g.progress * 100).toInt()}%',
                            style: TextStyle(color: g.color, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )).toList(),
                    onChanged: (g) => setState(() {
                      _selectedGoal = g;
                      if (g != null) {
                        _tx = _tx.copyWith(goalId: g.id);
                        _titleCtrl.text = 'Ahorro: ${g.name}';
                        _tx = _tx.copyWith(title: _titleCtrl.text);
                      }
                    }),
                  ),
                );
              },
            ),
            if (_selectedGoal != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedGoal!.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '${((_selectedGoal!.progress) * 100).toInt()}% completado',
                      style: TextStyle(color: _selectedGoal!.color, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const Text(' — ', style: TextStyle(color: Colors.white24, fontSize: 11)),
                    Text(
                      'Faltan ${formatAmount(_selectedGoal!.remaining, compact: true)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],

          // Info para createGoal / createBudget
          if (_tx.scenario == NLScenario.createGoal || _tx.scenario == NLScenario.createBudget) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _tx.scenario == NLScenario.createGoal ? Icons.info_outline_rounded : Icons.info_outline_rounded,
                    size: 16,
                    color: color.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tx.scenario == NLScenario.createGoal
                          ? 'Se creará un nuevo objetivo de ahorro. Después podés editarlo para agregar ícono, color y fecha.'
                          : 'Se creará un nuevo presupuesto mensual. Después podés editarlo desde la sección Presupuesto.',
                      style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 8),

          // ── Alerta de presupuesto ──
          _BudgetAlertBanner(tx: _tx, amountText: _amountCtrl.text, budgets: widget.budgets),

          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => widget.onConfirm(_finalTx.copyWith(
                    amount: _amountCtrl.text.isNotEmpty ? parseFormattedAmount(_amountCtrl.text) : _tx.amount,
                    title: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : _tx.title,
                  )),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _tx.scenario == NLScenario.createGoal ? 'Crear Objetivo →'
                      : _tx.scenario == NLScenario.createBudget ? 'Crear Presupuesto →'
                      : 'Confirmar →',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────

class _AccountDropdown extends StatelessWidget {
  final List<dom_acc.Account> accounts;
  final dom_acc.Account? value;
  final ValueChanged<dom_acc.Account?> onChanged;

  const _AccountDropdown({required this.accounts, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final effective = (value != null && accounts.any((a) => a.id == value!.id)) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<dom_acc.Account>(
        value: effective,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E1E2C),
        underline: const SizedBox(),
        hint: const Text('Seleccioná cuenta', style: TextStyle(color: Colors.white38, fontSize: 13)),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        items: accounts.map((a) => DropdownMenuItem(
          value: a,
          child: Row(
            children: [
              Icon(
                a.isCreditCard ? Icons.credit_card_rounded : Icons.account_balance_wallet_outlined,
                size: 14,
                color: Colors.white38,
              ),
              const SizedBox(width: 6),
              Text(a.name),
            ],
          ),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _PersonBalanceChip extends StatelessWidget {
  final dom_p.Person person;
  final NLTransaction tx;
  final Color color;

  const _PersonBalanceChip(this.person, this.tx, this.color);

  @override
  Widget build(BuildContext context) {
    final balance = person.totalBalance;
    final amount = tx.amount ?? 0;
    double projected = balance;

    switch (tx.scenario) {
      case NLScenario.loanGiven:
        projected = balance + amount;
        break;
      case NLScenario.loanReceived:
      case NLScenario.loanRepayment:
        projected = balance - amount;
        break;
      case NLScenario.sharedExpense:
        projected = balance + (tx.splitOtherAmount ?? amount / 2);
        break;
      default:
        break;
    }

    final balanceColor = balance > 0 ? Colors.green : balance < 0 ? Colors.redAccent : Colors.white38;
    final projectedColor = projected > 0 ? Colors.green : projected < 0 ? Colors.redAccent : Colors.white38;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${person.displayName}: ', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(
            '\$${balance.abs().toStringAsFixed(0)} ${balance >= 0 ? 'te debe' : 'le debés'}',
            style: TextStyle(color: balanceColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          if (projected != balance) ...[
            const Text(' → ', style: TextStyle(color: Colors.white24, fontSize: 11)),
            Text(
              '\$${projected.abs().toStringAsFixed(0)} ${projected >= 0 ? 'te debe' : 'le debés'}',
              style: TextStyle(color: projectedColor, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Budget alert banner — shown in confirmation card
// ─────────────────────────────────────────────────────────
class _BudgetAlertBanner extends StatelessWidget {
  final NLTransaction tx;
  final String amountText;
  final List<dom_b.Budget> budgets;

  const _BudgetAlertBanner({
    required this.tx,
    required this.amountText,
    required this.budgets,
  });

  @override
  Widget build(BuildContext context) {
    // Only relevant for spending scenarios with a known category
    if (tx.scenario != NLScenario.expense &&
        tx.scenario != NLScenario.sharedExpense &&
        tx.scenario != NLScenario.wishlistPurchase) {
      return const SizedBox.shrink();
    }
    final catId = tx.categoryId;
    if (catId == null) return const SizedBox.shrink();

    final budget = budgets.where((b) => b.categoryId == catId).firstOrNull;
    if (budget == null || budget.limitAmount <= 0) return const SizedBox.shrink();

    final amount = parseFormattedAmount(amountText);
    if (amount <= 0) return const SizedBox.shrink();

    final projected = budget.spentAmount + amount;
    final pct = (projected / budget.limitAmount * 100).clamp(0, 999).toInt();
    final willExceed = projected > budget.limitAmount;
    final isNear = pct >= 80;

    if (!isNear && !willExceed) return const SizedBox.shrink();

    final color = willExceed ? AppTheme.colorExpense : AppTheme.colorWarning;
    final emoji = willExceed ? '⚠️' : '⚡';
    final remaining = (budget.limitAmount - budget.spentAmount).clamp(0.0, double.infinity);
    final msg = willExceed
        ? 'Superás el presupuesto de ${budget.categoryName} ($pct%). Quedaban ${formatAmount(remaining)}.'
        : 'Llegás al $pct% del presupuesto de ${budget.categoryName}.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  final String text;
  final TextEditingController controller;
  final VoidCallback onTap;
  const _ExampleChip(this.text, this.controller, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        controller.text = text;
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(color: AppTheme.colorExpense, shape: BoxShape.circle),
      ),
    );
  }
}

class _SmartToggle extends StatelessWidget {
  final bool isSmart;
  final ValueChanged<bool> onChanged;
  const _SmartToggle({required this.isSmart, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSmart ? Icons.auto_awesome_rounded : Icons.edit_note_rounded,
            size: 14,
            color: isSmart ? AppTheme.colorTransfer : Colors.white54,
          ),
          const SizedBox(width: 4),
          Text(
            isSmart ? 'IA' : 'Manual',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: isSmart,
              activeTrackColor: AppTheme.colorTransfer.withValues(alpha: 0.3),
              activeThumbColor: AppTheme.colorTransfer,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final TransactionType current;
  final ValueChanged<TransactionType> onChanged;
  const _TypeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TypeButton(isSelected: current == TransactionType.expense, label: 'Gasto', onTap: () => onChanged(TransactionType.expense)),
          _TypeButton(isSelected: current == TransactionType.income, label: 'Ingreso', onTap: () => onChanged(TransactionType.income)),
          _TypeButton(isSelected: current == TransactionType.transfer, label: 'Transfer', onTap: () => onChanged(TransactionType.transfer)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Live suggestion data + chip
// ─────────────────────────────────────────────────────────
class _SuggestionItem {
  final String label;       // texto corto del chip: "💸 Gasto · $2.500"
  final String completion;  // frase completa a insertar en el campo
  final NLScenario scenario;
  const _SuggestionItem(this.label, this.completion, this.scenario);
}

class _LiveSuggestionChip extends StatelessWidget {
  final _SuggestionItem item;
  final TextEditingController controller;
  final VoidCallback? onTap;
  const _LiveSuggestionChip({required this.item, required this.controller, this.onTap});

  Color _colorFor(NLScenario s) {
    switch (s) {
      case NLScenario.income:
      case NLScenario.loanReceived:
        return AppTheme.colorIncome;
      case NLScenario.expense:
      case NLScenario.loanGiven:
      case NLScenario.loanRepayment:
        return AppTheme.colorExpense;
      case NLScenario.sharedExpense:
        return Colors.orange;
      case NLScenario.navigateTo:
        return const Color(0xFF6C63FF);
      case NLScenario.createPerson:
        return const Color(0xFF4ECDC4);
      case NLScenario.queryBalance:
      case NLScenario.queryBudget:
      case NLScenario.queryDebt:
      case NLScenario.goalContribution:
      case NLScenario.createGoal:
      case NLScenario.internalTransfer:
      case NLScenario.duplicateLastTx:
        return AppTheme.colorTransfer;
      case NLScenario.settleDebt:
        return AppTheme.colorIncome;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(item.scenario);
    return GestureDetector(
      onTap: () {
        controller.text = item.completion;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          item.label,
          style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Mic button with ripple animation while listening
// ─────────────────────────────────────────────────────────
class _MicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  const _MicButton({required this.isListening, required this.onTap});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late AnimationController _ripple;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    if (widget.isListening) _ripple.repeat();
  }

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !old.isListening) {
      _ripple.repeat();
    } else if (!widget.isListening && old.isListening) {
      _ripple.stop();
      _ripple.reset();
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isListening)
              AnimatedBuilder(
                animation: _ripple,
                builder: (_, __) => Container(
                  width: 50 + (_ripple.value * 14),
                  height: 50 + (_ripple.value * 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.colorExpense.withValues(alpha: (1 - _ripple.value) * 0.25),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.isListening
                    ? AppTheme.colorExpense.withValues(alpha: 0.2)
                    : AppTheme.colorTransfer.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isListening
                      ? AppTheme.colorExpense.withValues(alpha: 0.4)
                      : AppTheme.colorTransfer.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: widget.isListening ? AppTheme.colorExpense : AppTheme.colorTransfer,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Analyzing shimmer button
// ─────────────────────────────────────────────────────────
class _AnalyzingButton extends StatefulWidget {
  @override
  State<_AnalyzingButton> createState() => _AnalyzingButtonState();
}

class _AnalyzingButtonState extends State<_AnalyzingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;
  int _textIndex = 0;
  static const _texts = ['Analizando...', 'Entendiendo el gasto...', 'Identificando categoría...', 'Procesando con IA ✦'];

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    // Rotate text every 1.5s
    Future.delayed(const Duration(milliseconds: 1500), _rotateText);
  }

  void _rotateText() {
    if (!mounted) return;
    setState(() => _textIndex = (_textIndex + 1) % _texts.length);
    Future.delayed(const Duration(milliseconds: 1500), _rotateText);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment((-1.0 + _shimmer.value * 3).clamp(-1.0, 1.0), 0),
              end: Alignment((-1.0 + _shimmer.value * 3 + 1).clamp(-1.0, 1.0), 0),
              colors: [
                AppTheme.colorTransfer.withValues(alpha: 0.6),
                AppTheme.colorTransfer,
                AppTheme.colorTransfer.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _texts[_textIndex],
                key: ValueKey(_textIndex),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TypeButton extends StatelessWidget {
  final bool isSelected;
  final String label;
  final VoidCallback onTap;
  const _TypeButton({required this.isSelected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.colorTransfer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
