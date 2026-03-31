import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTheme {
  // ──────────────────────────────────────────
  // Color tokens
  // ──────────────────────────────────────────
  static const _primaryDark = Color(0xFF7C6EF7);    // violeta suave
  static const _secondaryDark = Color(0xFF5ECFB1);  // verde menta
  static const _errorDark = Color(0xFFFF5C6E);       // rojo coral


  static const _surfaceDark = Color(0xFF1A1D2E);     // fondo oscuro azulado
  static const _surface2Dark = Color(0xFF242740);    // cards
  static const _surface3Dark = Color(0xFF2E3253);    // surface elevada

  static const _onSurfaceDark = Color(0xFFF0F0FF);
  static const _onSurfaceVariantDark = Color(0xFF9A9BBF);

  // Colores semánticos de la app
  static const colorIncome = Color(0xFF5ECFB1);
  static const colorExpense = Color(0xFFFF5C6E);
  static const colorTransfer = Color(0xFF7C6EF7);
  static const colorWarning = Color(0xFFFFB347);
  static const colorNeutral = Color(0xFF9A9BBF);

  // ──────────────────────────────────────────
  // Dark theme (principal)
  // ──────────────────────────────────────────
  static ThemeData dark() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _primaryDark,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF3D3580),
      onPrimaryContainer: Color(0xFFD4CCFF),
      secondary: _secondaryDark,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF1A5E50),
      onSecondaryContainer: Color(0xFFA8F0DE),
      error: _errorDark,
      onError: Colors.white,
      errorContainer: Color(0xFF6B1528),
      onErrorContainer: Color(0xFFFFB3BB),
      surface: _surfaceDark,
      onSurface: _onSurfaceDark,
      onSurfaceVariant: _onSurfaceVariantDark,
      surfaceContainerHighest: _surface3Dark,
      surfaceContainerHigh: _surface2Dark,
      surfaceContainer: _surface2Dark,
      outline: Color(0xFF3D4070),
      outlineVariant: Color(0xFF2B2E50),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surfaceDark,
      textTheme: _buildTextTheme(colorScheme),
      appBarTheme: _buildAppBarTheme(colorScheme),
      cardTheme: _buildCardTheme(colorScheme),
      navigationBarTheme: _buildNavBarTheme(colorScheme),
      floatingActionButtonTheme: _buildFABTheme(colorScheme),
      inputDecorationTheme: _buildInputTheme(colorScheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      filledButtonTheme: _buildFilledButtonTheme(colorScheme),
      chipTheme: _buildChipTheme(colorScheme),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
    );
  }

  // ──────────────────────────────────────────
  // Light theme
  // ──────────────────────────────────────────
  static ThemeData light() {
    // Por ahora usamos dark como default del plan
    // Light se puede agregar en Fase 2
    return dark();
  }

  // ──────────────────────────────────────────
  // Sub-builders
  // ──────────────────────────────────────────
  static TextTheme _buildTextTheme(ColorScheme cs) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 56,
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 44,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: cs.onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: cs.onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: cs.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 1.0,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme(ColorScheme cs) {
    return AppBarTheme(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: cs.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: cs.onSurface),
    );
  }

  static CardThemeData _buildCardTheme(ColorScheme cs) {
    return CardThemeData(
      color: cs.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant,
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    );
  }

  static NavigationBarThemeData _buildNavBarTheme(ColorScheme cs) {
    return NavigationBarThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: cs.primary.withValues(alpha: 0.15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: cs.primary, size: 24);
        }
        return IconThemeData(color: cs.onSurfaceVariant, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(
            color: cs.primary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          );
        }
        return GoogleFonts.inter(
          color: cs.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        );
      }),
    );
  }

  static FloatingActionButtonThemeData _buildFABTheme(ColorScheme cs) {
    return FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
    );
  }

  static InputDecorationTheme _buildInputTheme(ColorScheme cs) {
    return InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error),
      ),
      hintStyle: GoogleFonts.inter(color: cs.onSurfaceVariant, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: cs.onSurfaceVariant),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(ColorScheme cs) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }

  static FilledButtonThemeData _buildFilledButtonTheme(ColorScheme cs) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }

  static ChipThemeData _buildChipTheme(ColorScheme cs) {
    return ChipThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      selectedColor: cs.primary.withValues(alpha: 0.2),
      side: BorderSide(color: cs.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
