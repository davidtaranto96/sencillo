import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../database/database_providers.dart';
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
      listenMode: stt.ListenMode.dictation,
      cancelOnError: true,
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

          // Text input fallback
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
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
