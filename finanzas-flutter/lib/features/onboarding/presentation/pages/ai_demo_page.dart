import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/theme/app_theme.dart';

/// Sprint 2.9 — Demo IA obligatoria post-welcome.
///
/// Muestra animación de "café 3.500" tipeándose solo, y debajo aparece el
/// resultado parseado mockeado (categoría/monto/cuenta). Es 100% MOCK — no
/// llama a la API real para no consumir tokens y para que funcione sin key.
class AiDemoPage extends ConsumerStatefulWidget {
  const AiDemoPage({super.key});

  @override
  ConsumerState<AiDemoPage> createState() => _AiDemoPageState();
}

class _AiDemoPageState extends ConsumerState<AiDemoPage>
    with TickerProviderStateMixin {
  static const _fullText = 'café 3.500';
  String _typedText = '';
  bool _showResult = false;
  bool _finishing = false;
  late final AnimationController _resultCtrl;

  @override
  void initState() {
    super.initState();
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _runAnimation();
  }

  Future<void> _runAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    for (int i = 0; i < _fullText.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 80));
      setState(() => _typedText = _fullText.substring(0, i + 1));
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _showResult = true);
    _resultCtrl.forward();
  }

  @override
  void dispose() {
    _resultCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (_finishing) return;
    setState(() => _finishing = true);
    // Marca onboarding completo → app.dart redirige a login/setup_wizard.
    ref.read(onboardingProvider).complete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Stack(
          children: [
            // Glow background
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                      blurRadius: 100,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                // Skip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _continue,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            'Saltar',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondaryDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Eyebrow
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '✨ ASÍ FUNCIONA LA IA',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFD4CCFF),
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Escribí tu gasto.\nNada más.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Mock input field with typing animation
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  color: const Color(0xFF6C63FF), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _typedText.isEmpty ? '|' : '$_typedText|',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Result reveal
                        AnimatedSlide(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          offset: _showResult ? Offset.zero : const Offset(0, 0.3),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: _showResult ? 1 : 0,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.colorIncome.withValues(alpha: 0.18),
                                    AppTheme.colorIncome.withValues(alpha: 0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.colorIncome.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          color: AppTheme.colorIncome, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Detectado',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.colorIncome,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _ResultRow(emoji: '🍴', label: 'Categoría', value: 'Comida'),
                                  _ResultRow(emoji: '💵', label: 'Monto', value: '\$ 3.500'),
                                  _ResultRow(emoji: '👛', label: 'Cuenta', value: 'Efectivo'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // CTA
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      32, 12, 32, MediaQuery.of(context).padding.bottom + 24),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: _showResult ? 1 : 0.4,
                    child: GestureDetector(
                      onTap: _showResult ? _continue : null,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6C63FF),
                              const Color(0xFF6C63FF).withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Probá vos también',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  const _ResultRow({required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondaryDark,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
