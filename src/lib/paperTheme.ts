import { MD3DarkTheme } from 'react-native-paper';
import type { MD3Theme } from 'react-native-paper';
import { colors } from './theme';

export const paperTheme: MD3Theme = {
  ...MD3DarkTheme,
  colors: {
    ...MD3DarkTheme.colors,
    // Brand
    primary: colors.brand.primary,
    primaryContainer: colors.brand.dark,
    onPrimary: '#FFFFFF',
    onPrimaryContainer: colors.brand.light,
    secondary: colors.saving,
    secondaryContainer: '#1A2A4A',
    onSecondary: '#FFFFFF',
    onSecondaryContainer: colors.saving,
    tertiary: colors.investment,
    tertiaryContainer: '#2A1A4A',
    onTertiary: '#FFFFFF',
    onTertiaryContainer: colors.investment,
    // Backgrounds
    background: colors.bg.primary,
    onBackground: colors.text.primary,
    surface: colors.bg.card,
    onSurface: colors.text.primary,
    surfaceVariant: colors.bg.elevated,
    onSurfaceVariant: colors.text.secondary,
    surfaceDisabled: colors.bg.secondary,
    onSurfaceDisabled: colors.text.muted,
    elevation: {
      level0: 'transparent',
      level1: colors.bg.secondary,
      level2: colors.bg.card,
      level3: colors.bg.elevated,
      level4: colors.bg.elevated,
      level5: colors.bg.elevated,
    },
    // Outline
    outline: colors.border.default,
    outlineVariant: colors.border.subtle,
    // Status
    error: colors.error,
    onError: '#FFFFFF',
    errorContainer: '#3B1219',
    onErrorContainer: colors.error,
    // Misc
    inverseSurface: colors.text.primary,
    inverseOnSurface: colors.bg.primary,
    inversePrimary: colors.brand.dark,
    shadow: '#000000',
    scrim: '#000000',
  },
};
