import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/router/app_router.dart';
import '../core/providers/onboarding_provider.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';

class FinanzasApp extends ConsumerWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Finanzas',
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
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final ctrl = ref.watch(onboardingProvider);
            // While SharedPreferences is loading, show a dark splash
            if (!ctrl.isLoaded) {
              return const Scaffold(
                backgroundColor: Color(0xFF0F0F1A),
              );
            }
            // Onboarding not complete → show onboarding page
            if (!ctrl.isComplete) {
              return const OnboardingPage();
            }
            // Normal app
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
