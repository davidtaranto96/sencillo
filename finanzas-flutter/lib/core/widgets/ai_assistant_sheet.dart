import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../database/database_providers.dart';
import '../logic/ai_intent_parser.dart';
import '../providers/ai_suggestions_provider.dart';
import '../services/ai_assistant_service.dart';

/// Shows the AI voice assistant bottom sheet.
Future<void> showAiAssistantSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _AiAssistantSheet(),
  );
}

class _AiAssistantSheet extends ConsumerStatefulWidget {
  const _AiAssistantSheet();

  @override
  ConsumerState<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

enum _AssistantState { idle, listening, thinking, speaking }

class _AiAssistantSheetState extends ConsumerState<_AiAssistantSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textCtrl = TextEditingController();

  _AssistantState _state = _AssistantState.idle;
  String _transcript = '';
  String _response = '';
  bool _speechAvailable = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) => setState(() => _state = _AssistantState.idle),
    );
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('es-AR');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _state = _AssistantState.idle);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _speech.stop();
    _tts.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      // Fallback: let user type
      return;
    }
    setState(() {
      _state = _AssistantState.listening;
      _transcript = '';
      _response = '';
    });
    _pulseCtrl.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult && _transcript.isNotEmpty) {
          _processQuery(_transcript);
        }
      },
      localeId: 'es_AR',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  void _stopListening() {
    _speech.stop();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    if (_transcript.isNotEmpty) {
      _processQuery(_transcript);
    } else {
      setState(() => _state = _AssistantState.idle);
    }
  }

  Future<void> _processQuery(String query) async {
    setState(() {
      _state = _AssistantState.thinking;
      _transcript = query;
    });
    _pulseCtrl.stop();
    _pulseCtrl.reset();

    // Sprint 3.13 — short-circuit local para slash commands.
    // Detecta intents conocidos (transfer/split/recurring/budget/goal/loan/undo)
    // y los confirma sin llamar a Haiku → instantáneo + sin tokens.
    final intent = AiIntentParser.parse(query);
    final localResponse = _maybeLocalResponse(intent);
    if (localResponse != null) {
      if (!mounted) return;
      setState(() {
        _response = localResponse;
        _state = _AssistantState.speaking;
      });
      await _tts.speak(localResponse);
      return;
    }

    // Get financial data
    final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
    final transactions = ref.read(transactionsStreamProvider).valueOrNull ?? [];
    final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
    final budgets = ref.read(budgetsStreamProvider).valueOrNull ?? [];
    final goals = ref.read(goalsStreamProvider).valueOrNull ?? [];

    final answer = await AiAssistantService.chat(
      userMessage: query,
      accounts: accounts,
      recentTx: transactions,
      people: people,
      budgets: budgets,
      goals: goals,
    );

    if (!mounted) return;
    setState(() {
      _response = answer;
      _state = _AssistantState.speaking;
    });

    await _tts.speak(answer);
  }

  /// Confirmación local de slash commands. Por ahora muestra al usuario QUÉ se
  /// reconoció (transparencia) sin ejecutar la acción — la ejecución completa
  /// (crear tx/persona/etc.) requiere resolver cuentas/personas por hint y se
  /// puede hacer iterativamente. Devuelve null cuando no es slash → fallback Haiku.
  String? _maybeLocalResponse(AiIntent intent) {
    return switch (intent) {
      TransferIntent t =>
        '✅ Transferencia: \$${t.amount.toStringAsFixed(0)}'
            '${t.fromAccountHint != null ? ' desde ${t.fromAccountHint}' : ''}'
            '${t.toAccountHint != null ? ' a ${t.toAccountHint}' : ''}.\n'
            'Tocá Crear para confirmar (en breve).',
      SplitIntent s =>
        '✅ Gasto compartido: ${s.concept} \$${s.amount.toStringAsFixed(0)}'
            '${s.peopleHints.isNotEmpty ? ' con ${s.peopleHints.join(", ")}' : ''}.\n'
            'Tocá Crear para confirmar (en breve).',
      RecurringIntent r =>
        '✅ Recurrente: ${r.title} \$${r.amount.toStringAsFixed(0)} (${r.frequency}).\n'
            'Tocá Crear para confirmar (en breve).',
      BudgetIntent b =>
        '✅ Presupuesto: ${b.categoryHint} \$${b.amount.toStringAsFixed(0)}.\n'
            'Tocá Crear para confirmar (en breve).',
      GoalIntent g =>
        '✅ Meta: ${g.name} \$${g.target.toStringAsFixed(0)}'
            '${g.deadline != null ? ' para ${g.deadline!.day}/${g.deadline!.month}/${g.deadline!.year}' : ''}.\n'
            'Tocá Crear para confirmar (en breve).',
      LoanIntent l =>
        '✅ Préstamo a ${l.personHint}: \$${l.amount.toStringAsFixed(0)}.\n'
            'Tocá Crear para confirmar (en breve).',
      UndoIntent _ => '↩️ Próximamente: deshacer última acción.',
      _ => null,  // ExpenseIntent / QuestionIntent → fallback a Haiku
    };
  }

  Future<void> _sendTypedMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    FocusScope.of(context).unfocus();
    await _processQuery(text);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset > 0 ? bottomInset + 12 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              Text('Asistente Sencillo',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),

          // Transcript (what user said)
          if (_transcript.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _transcript,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              ),
            ),

          // AI Response
          if (_response.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.15)),
              ),
              child: Text(
                _response,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.4),
              ),
            ),

          // Status indicator
          if (_state == _AssistantState.thinking)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF6C63FF))),
                  const SizedBox(width: 8),
                  Text('Pensando...', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),

          // Microphone button
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final scale = _state == _AssistantState.listening
                  ? 1.0 + _pulseCtrl.value * 0.15
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: GestureDetector(
              onTap: () {
                switch (_state) {
                  case _AssistantState.idle:
                    _startListening();
                    break;
                  case _AssistantState.listening:
                    _stopListening();
                    break;
                  case _AssistantState.speaking:
                    _tts.stop();
                    setState(() => _state = _AssistantState.idle);
                    break;
                  case _AssistantState.thinking:
                    break;
                }
              },
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _state == _AssistantState.listening
                        ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                        : [const Color(0xFF6C63FF), const Color(0xFF5ECFB1)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_state == _AssistantState.listening
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF6C63FF))
                          .withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(
                  _state == _AssistantState.listening
                      ? Icons.stop_rounded
                      : _state == _AssistantState.speaking
                          ? Icons.volume_up_rounded
                          : Icons.mic_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            _state == _AssistantState.listening
                ? 'Escuchando...'
                : _state == _AssistantState.speaking
                    ? 'Tocá para detener'
                    : 'Tocá para hablar',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),

          // Sprint 3.15 — Chips contextuales (sólo cuando textfield vacío).
          if (_textCtrl.text.isEmpty) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final suggestions = ref.watch(aiSuggestionsProvider);
                if (suggestions.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final s = suggestions[i];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _textCtrl.text = s.input;
                            _textCtrl.selection = TextSelection.collapsed(
                              offset: _textCtrl.text.length,
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  const Color(0xFF6C63FF).withValues(alpha: 0.30),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s.emoji, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 5),
                              Text(
                                s.label,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFD4CCFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],

          // Text input fallback
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  onChanged: (_) => setState(() {}),  // refresca chips al tipear/borrar
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'O escribí tu consulta...',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendTypedMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendTypedMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF), size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
