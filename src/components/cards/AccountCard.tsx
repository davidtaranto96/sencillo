import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Account } from '@/src/lib/types';
import { formatCurrency } from '@/src/lib/utils';
import { colors, radius, spacing, typography, shadows } from '@/src/lib/theme';

interface Props {
  account: Account;
  onPress?: () => void;
}

const typeLabels: Record<string, string> = {
  bank: 'Banco',
  digital_wallet: 'Billetera',
  cash: 'Efectivo',
  credit_card: 'Tarjeta crédito',
  investment: 'Inversión',
  savings: 'Ahorro',
};

export function AccountCard({ account, onPress }: Props) {
  return (
    <Pressable
      style={({ pressed }) => [styles.card, pressed && styles.pressed]}
      onPress={onPress}
    >
      <View style={[styles.colorBar, { backgroundColor: account.color }]} />
      <View style={styles.content}>
        <Text style={styles.name}>{account.name}</Text>
        <Text style={styles.type}>{typeLabels[account.type] ?? account.type}</Text>
      </View>
      <Text style={styles.balance}>{formatCurrency(account.balance)}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.bg.card,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border.default,
    overflow: 'hidden',
    ...shadows.subtle,
  },
  pressed: {
    opacity: 0.85,
    transform: [{ scale: 0.99 }],
  },
  colorBar: {
    width: 4,
    alignSelf: 'stretch',
  },
  content: {
    flex: 1,
    padding: spacing.base,
    gap: 2,
  },
  name: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
  },
  type: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
  },
  balance: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
    paddingRight: spacing.base,
  },
});
