import { View, Text, StyleSheet } from 'react-native';
import { colors, radius, spacing, typography } from '@/src/lib/theme';

type BadgeVariant = 'income' | 'expense' | 'saving' | 'investment' | 'transfer' | 'default';

interface Props {
  label: string;
  variant?: BadgeVariant;
  color?: string;
}

const variantColors: Record<BadgeVariant, string> = {
  income: colors.income,
  expense: colors.expense,
  saving: colors.saving,
  investment: colors.investment,
  transfer: colors.transfer,
  default: colors.brand.primary,
};

export function Badge({ label, variant = 'default', color }: Props) {
  const bg = color ?? variantColors[variant];
  return (
    <View style={[styles.badge, { backgroundColor: bg + '22' }]}>
      <Text style={[styles.text, { color: bg }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
    borderRadius: radius.full,
    alignSelf: 'flex-start',
  },
  text: {
    fontSize: typography.size.xs,
    fontWeight: typography.weight.semibold,
  },
});
