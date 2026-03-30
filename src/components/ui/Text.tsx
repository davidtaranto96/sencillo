import { Text as RNText, TextProps, StyleSheet } from 'react-native';
import { colors, typography } from '@/src/lib/theme';

type Variant = 'h1' | 'h2' | 'h3' | 'title' | 'body' | 'caption' | 'label';
type Weight = 'regular' | 'medium' | 'semibold' | 'bold';

interface Props extends TextProps {
  variant?: Variant;
  weight?: Weight;
  color?: string;
}

export function AppText({ variant = 'body', weight, color, style, ...props }: Props) {
  return (
    <RNText
      style={[
        styles.base,
        styles[variant],
        weight ? { fontWeight: typography.weight[weight] } : undefined,
        color ? { color } : undefined,
        style,
      ]}
      {...props}
    />
  );
}

const styles = StyleSheet.create({
  base: {
    color: colors.text.primary,
  },
  h1: {
    fontSize: typography.size['3xl'],
    fontWeight: typography.weight.bold,
    lineHeight: typography.size['3xl'] * 1.2,
  },
  h2: {
    fontSize: typography.size['2xl'],
    fontWeight: typography.weight.bold,
  },
  h3: {
    fontSize: typography.size.xl,
    fontWeight: typography.weight.semibold,
  },
  title: {
    fontSize: typography.size.lg,
    fontWeight: typography.weight.semibold,
  },
  body: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.regular,
  },
  caption: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
  },
  label: {
    fontSize: typography.size.xs,
    fontWeight: typography.weight.medium,
    color: colors.text.muted,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
});
