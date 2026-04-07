import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/router/app_router.dart';
import '../core/providers/onboarding_provider.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';

class SencilloApp extends ConsumerWidget {
  const SencilloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Only rebuild when isLoaded or isComplete actually changes (not on every notify)
    final isLoaded = ref.watch(onboardingProvider.select((c) => c.isLoaded));
    final isComplete = ref.watch(onboardingProvider.select((c) => c.isComplete));

    // While SharedPreferences is loading, show animated splash
    if (!isLoaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const _AnimatedSplash(),
      );
    }

    // Onboarding not complete → show onboarding page
    if (!isComplete) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'AR'),
          Locale('es'),
          Locale('en'),
        ],
        locale: const Locale('es', 'AR'),
        home: const OnboardingPage(),
      );
    }

    // Normal app with router
    return MaterialApp.router(
      title: 'Sencillo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('es'),
        Locale('en'),
      ],
      locale: const Locale('es', 'AR'),
    );
  }
}

/// Animated splash screen shown while the app initializes
class _AnimatedSplash extends StatefulWidget {
  const _AnimatedSplash();

  @override
  State<_AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<_AnimatedSplash>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _coinCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _coinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _coinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          // Ambient glow
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6C63FF)
                          .withValues(alpha: 0.15 * _pulse.value),
                      const Color(0xFF5ECFB1)
                          .withValues(alpha: 0.05 * _pulse.value),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Floating coins
          ...List.generate(5, (i) {
            final rng = math.Random(i * 17);
            return AnimatedBuilder(
              animation: _coinCtrl,
              builder: (context, _) {
                final y = size.height * 0.3 +
                    rng.nextDouble() * size.height * 0.4 +
                    math.sin(_coinCtrl.value * math.pi * 2 + i * 1.2) * 15;
                final x =
                    size.width * 0.15 + rng.nextDouble() * size.width * 0.7;
                return Positioned(
                  left: x,
                  top: y,
                  child: Opacity(
                    opacity: 0.08 + rng.nextDouble() * 0.07,
                    child: Text(
                      ['💰', '💵', '🪙', '💎', '📊'][i],
                      style: TextStyle(fontSize: 16 + rng.nextDouble() * 10),
                    ),
                  ),
                );
              },
            );
          }),

          // Center content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App icon with glow
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF)
                              .withValues(alpha: 0.2 * _pulse.value),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Transform.scale(
                      scale: 1.35,
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.savings_rounded,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF5ECFB1)],
                  ).createShader(bounds),
                  child: Text(
                    'SENCILLO',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 5,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.2),
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
