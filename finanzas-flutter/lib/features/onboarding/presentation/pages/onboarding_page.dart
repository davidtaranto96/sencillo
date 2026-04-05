import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/database/database_seeder.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _Slide(
      emoji: '👋',
      title: 'Bienvenido a Finanzas',
      description:
          'Tomá el control de tu dinero. Seguí gastos, creá presupuestos y alcanzá tus metas financieras.',
      color: Color(0xFF6C63FF),
    ),
    _Slide(
      emoji: '🏠',
      title: 'Tu resumen diario',
      description:
          'En la pantalla de Inicio vés tu saldo total, alertas de presupuesto y los últimos movimientos de un vistazo.',
      color: Color(0xFF4ECDC4),
    ),
    _Slide(
      emoji: '💸',
      title: 'Registrá movimientos',
      description:
          'Cargá ingresos y gastos con categoría, cuenta y fecha. También podés dividir gastos compartidos con amigos.',
      color: Color(0xFFFF6B6B),
    ),
    _Slide(
      emoji: '🎯',
      title: 'Presupuestos y Metas',
      description:
          'Poné límites de gasto por categoría y creá objetivos de ahorro para lo que más querés lograr.',
      color: Color(0xFFFFD93D),
    ),
    _Slide(
      emoji: '👥',
      title: 'Gastos con personas',
      description:
          'Registrá deudas con amigos o familia y la app lleva la cuenta de quién debe cuánto automáticamente.',
      color: Color(0xFFFF8C69),
    ),
    _Slide(
      emoji: '✨',
      title: '¡Todo listo!',
      description:
          'Personalizá las pestañas del menú desde Configuración para tener siempre a mano lo que más usás.',
      color: Color(0xFF6C63FF),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubicEmphasized,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    _showDemoDataChoice();
  }

  void _showDemoDataChoice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(
              '¿Querés cargar datos de ejemplo?',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Podés ver cómo se ve la app con cuentas, movimientos y presupuestos de prueba. Los podés borrar después desde Configuración.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white54, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final db = ref.read(databaseProvider);
                  final seeder = DatabaseSeeder(db);
                  await seeder.clearAndSeedMockData();
                  ref.read(onboardingProvider).complete();
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Cargar datos de ejemplo', style: TextStyle(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(onboardingProvider).complete();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Empezar de cero',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  slide.color.withValues(alpha: 0.18),
                  const Color(0xFF0F0F1A),
                ],
              ),
            ),
          ),

          // Blurred glow orb
          Positioned(
            top: size.height * 0.08,
            left: size.width * 0.5 - 100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slide.color.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: slide.color.withValues(alpha: 0.25),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isLast)
                        GestureDetector(
                          onTap: _finish,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Text(
                              'Omitir',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      return _SlidePage(slide: _slides[index]);
                    },
                  ),
                ),

                // Indicators + CTA
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      32, 24, 32, MediaQuery.of(context).padding.bottom + 32),
                  child: Column(
                    children: [
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _currentPage ? 24 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? slide.color
                                  : Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // CTA button
                      GestureDetector(
                        onTap: _next,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                slide.color,
                                slide.color.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: slide.color.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                isLast ? '¡Empezar!' : 'Siguiente',
                                key: ValueKey(isLast),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji in frosted glass circle
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: slide.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                      color: slide.color.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Center(
                  child: Text(slide.emoji,
                      style: const TextStyle(fontSize: 60)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 44),

          // Title
          Text(
            slide.title,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            slide.description,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final String emoji;
  final String title;
  final String description;
  final Color color;

  const _Slide({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });
}
