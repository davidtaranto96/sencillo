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

  // Voice
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
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

    // createGoal y createBudget no requieren monto obligatorio
    if (amount <= 0 && tx.scenario != NLScenario.createGoal && tx.scenario != NLScenario.createBudget) {
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
          'Escribí o dictá como hablás normalmente.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // Input area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _isListening ? AppTheme.colorExpense : cs.outlineVariant),
          ),
          child: Row(
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
                              style: TextStyle(
                                color: _aiController.text.isEmpty ? AppTheme.colorTransfer : Colors.white,
                                fontStyle: _aiController.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ),
                        ],
                      )
                    : TextField(
                        controller: _aiController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Ej. Pagué 45 mil de sushi con Juan...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _processAiInput(),
                      ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isListening ? AppTheme.colorExpense.withValues(alpha: 0.15) : AppTheme.colorTransfer.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: _isListening ? AppTheme.colorExpense : AppTheme.colorTransfer,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Ejemplos de uso — scroll horizontal
        if (!_showConfirmation && !_isAnalyzing) ...[
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _ExampleChip('Pagué 4500 de sushi', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Cobré el sueldo 200k', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Ahorré 50k para viaje', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Crear objetivo Notebook 800k', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Nuevo presupuesto comida 150k', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Presté 10k a Juan', _aiController, () => setState(() {})),
                const SizedBox(width: 8),
                _ExampleChip('Dividí taxi con María 3600', _aiController, () => setState(() {})),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Tarjeta de confirmación
        if (_showConfirmation && _parsed != null)
          _AiConfirmationCard(
            tx: _parsed!,
            accounts: ref.watch(accountsStreamProvider).value ?? [],
            people: ref.watch(peopleStreamProvider).value ?? [],
            onConfirm: _confirmParsed,
            onEdit: () => setState(() => _showConfirmation = false),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _processAiInput,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isAnalyzing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Analizando con IA...', style: TextStyle(fontSize: 15)),
                      ],
                    )
                  : const Text('Procesar Movimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
  final void Function(NLTransaction) onConfirm;
  final VoidCallback onEdit;

  const _AiConfirmationCard({
    required this.tx,
    required this.accounts,
    required this.people,
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
      default:
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
      default:
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

  @override
  Widget build(BuildContext context) {
    final color = _scenarioColor;

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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_scenarioIcon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IA detectó: ${_tx.scenarioLabel}',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '"${_tx.rawInput}"',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
