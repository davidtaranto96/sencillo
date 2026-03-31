export const colors = {
  // Fondos
  bg: {
    primary: '#0F0F14',
    secondary: '#17171F',
    card: '#1E1E2A',
    elevated: '#252532',
    input: '#1A1A24',
  },

  // Marca
  brand: {
    primary: '#6C63FF',
    light: '#8B85FF',
    dark: '#4F48CC',
    muted: '#6C63FF22',
  },

  // Semánticos
  income: '#34D399',     // verde
  expense: '#F87171',    // rojo
  saving: '#60A5FA',     // azul
  investment: '#A78BFA', // violeta
  transfer: '#FBBF24',   // amarillo
  warning: '#FB923C',    // naranja

  // Texto
  text: {
    primary: '#F1F1F5',
    secondary: '#9898AA',
    muted: '#5A5A70',
    inverse: '#0F0F14',
  },

  // Bordes
  border: {
    default: '#2A2A38',
    subtle: '#1E1E2A',
    focus: '#6C63FF',
  },

  // Estado
  success: '#34D399',
  error: '#F87171',
  info: '#60A5FA',

  // Paleta de cuentas/categorías
  palette: [
    '#6C63FF', '#34D399', '#F87171', '#FBBF24',
    '#60A5FA', '#A78BFA', '#FB923C', '#F472B6',
    '#2DD4BF', '#4ADE80',
  ],
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  base: 16,
  lg: 20,
  xl: 24,
  '2xl': 32,
  '3xl': 40,
  '4xl': 48,
} as const;

export const radius = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  full: 999,
} as const;

export const typography = {
  // Tamaños
  size: {
    xs: 11,
    sm: 13,
    base: 15,
    md: 17,
    lg: 20,
    xl: 24,
    '2xl': 28,
    '3xl': 34,
  },
  // Pesos
  weight: {
    regular: '400' as const,
    medium: '500' as const,
    semibold: '600' as const,
    bold: '700' as const,
  },
  // Line heights
  leading: {
    tight: 1.2,
    normal: 1.5,
    relaxed: 1.7,
  },
} as const;

export const shadows = {
  card: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 12,
    elevation: 8,
  },
  subtle: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 6,
    elevation: 4,
  },
} as const;

const theme = { colors, spacing, radius, typography, shadows };
export default theme;
