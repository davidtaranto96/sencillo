import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class AiInputBottomSheet extends StatefulWidget {
  const AiInputBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiInputBottomSheet(),
    );
  }

  @override
  State<AiInputBottomSheet> createState() => _AiInputBottomSheetState();
}

class _AiInputBottomSheetState extends State<AiInputBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  
  // Simulated parsing state
  bool _isAnalyzing = false;
  bool _isListeningVoice = false;
  List<String> _detectedTags = [];

  void _onTextChanged(String text) {
    // Very simple mockup of AI parsing logic
    setState(() {
      _detectedTags.clear();
      final lower = text.toLowerCase();
      
      if (lower.contains('sushi') || lower.contains('comida')) {
        _detectedTags.add('🍔 Comida & Salidas');
      }
      if (lower.contains('juan') || lower.contains('sofi')) {
        _detectedTags.add('👥 Compartido');
      }
      if (lower.contains('dividir')) {
        _detectedTags.add('➗ División en partes');
      }
      
      // Match numbers
      final numberMatch = RegExp(r'\b\d+\b').firstMatch(text);
      if (numberMatch != null) {
        _detectedTags.add('💵 \$${numberMatch.group(0)}');
      }
    });
  }

  void _processInput() async {
    if (_controller.text.isEmpty) return;
    
    setState(() => _isAnalyzing = true);
    
    // Simulate AI network delay
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transacción procesada con IA: ${_controller.text}'),
          backgroundColor: AppTheme.colorTransfer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleListening() async {
    setState(() => _isListeningVoice = !_isListeningVoice);
    if (_isListeningVoice) {
      // Simulamos que graba por 3 segundos
      await Future.delayed(const Duration(seconds: 3));
      if (mounted && _isListeningVoice) {
        setState(() {
          _isListeningVoice = false;
          _controller.text = "Pagué 45 mil de sushi con Juan y Sofi dividir";
        });
        _onTextChanged(_controller.text);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom; // Para el teclado

    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 90),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppTheme.colorTransfer),
              const SizedBox(width: 8),
              Text(
                'Entrada Inteligente',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Escribí o dictá como hablas normalmente y nosotros hacemos el resto.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _isListeningVoice
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.colorTransfer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Escuchando...',
                              style: TextStyle(color: AppTheme.colorTransfer, fontWeight: FontWeight.w500),
                            ),
                          ],
                        )
                      : TextField(
                          controller: _controller,
                          onChanged: _onTextChanged,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Ej. Pagué 45 mil de sushi con Juan...',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                        ),
                ),
                IconButton(
                  icon: Icon(
                    _isListeningVoice ? Icons.stop_circle_rounded : Icons.mic_rounded,
                    color: _isListeningVoice ? cs.error : AppTheme.colorTransfer,
                    size: _isListeningVoice ? 32 : 24,
                  ),
                  onPressed: _toggleListening,
                ),
              ],
            ),
          ),
          
          if (_detectedTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _detectedTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: AppTheme.colorTransfer,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isAnalyzing ? null : _processInput,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isAnalyzing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Procesar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
