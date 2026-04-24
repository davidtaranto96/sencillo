import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/onboarding_provider.dart';
import 'ai_demo_page.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _finishing = false;

  late final AnimationController _floatCtrl;
  late final AnimationController _glowCtrl;

  // Sprint 2.8: 6 slides → 1 welcome único.
  // El reporte mostró que el 80%+ de usuarios saltean los slides; el welcome
  // único + demo IA + setup mínimo lleva al primer gasto en <60s vs ~180s antes.
  static const _slides = [
    _Slide(
      icon: Icons.savings_rounded,
      title: 'Tus finanzas, sin complicaciones',
      description:
          'Cargá un gasto en lenguaje natural y la IA lo categoriza sola.\nDividí con amigos, ahorrá con metas, controlá tarjetas. Todo en un solo lugar.',
      color: Color(0xFF6C63FF),
      iconBg: Color(0xFF6C63FF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _next() {
    // Sprint 2.8/2.9: welcome único → AI demo (no salta directo a finish).
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiDemoPage()),
    );
  }

  void _finish() {
    if (_finishing) return;
    setState(() => _finishing = true);
    // Complete onboarding → app.dart switches to login page
    ref.read(onboardingProvider).complete();
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
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (context, _) {
              final scale = 1.0 + _glowCtrl.value * 0.15;
              return Positioned(
                top: size.height * 0.08,
                left: size.width * 0.5 - 100 * scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  width: 200 * scale,
                  height: 200 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: slide.color.withValues(alpha: 0.10),
                    boxShadow: [
                      BoxShadow(
                        color: slide.color.withValues(alpha: 0.20),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating particles
          ...List.generate(6, (i) {
            final rng = math.Random(i * 31);
            return AnimatedBuilder(
              animation: _floatCtrl,
              builder: (context, _) {
                final baseY = size.height * 0.15 + rng.nextDouble() * size.height * 0.55;
                final y = baseY + math.sin(_floatCtrl.value * math.pi * 2 + i * 1.3) * 12;
                final x = size.width * 0.1 + rng.nextDouble() * size.width * 0.8;
                final opacity = 0.06 + rng.nextDouble() * 0.08;
                return Positioned(
                  left: x,
                  top: y,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    width: 4 + rng.nextDouble() * 4,
                    height: 4 + rng.nextDouble() * 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: slide.color.withValues(alpha: opacity),
                    ),
                  ),
                );
              },
            );
          }),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

                // CTAs (welcome único, sin paginación)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      32, 20, 32, MediaQuery.of(context).padding.bottom + 28),
                  child: Column(
                    children: [
                      // CTA primary: arrancá ahora
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
                            child: Text(
                              'Empezá ahora',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // CTA secondary: tengo backup
                      GestureDetector(
                        onTap: _finish, // mismo flujo, después puede ir a restore desde login
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Ya tengo cuenta · Restaurar backup',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
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
          // Icon in frosted glass card
          ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: slide.iconBg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                      color: slide.iconBg.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: slide.iconBg.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    slide.icon,
                    size: 56,
                    color: slide.iconBg,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 44),

          // Title
          Text(
            slide.title,
            style: GoogleFonts.inter(
              fontSize: 26,
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
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color iconBg;

  const _Slide({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.iconBg,
  });
}
