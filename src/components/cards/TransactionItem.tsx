import React from 'react';
import { View, StyleSheet, Pressable } from 'react-native';
import { Text } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Transaction, Category } from '@/src/lib/types';
import { colors, spacing, radius } from '@/src/lib/theme';
import { formatCurrency } from '@/src/lib/utils';

interface Props {
  transaction: Transaction;
  category?: Category;
  accountName?: string;
  onPress?: () => void;
}

const TYPE_CONFIG: Record<string, { color: string; prefix: string; icon: string }> = {
  income:        { color: colors.income,     prefix: '+', icon: 'arrow-up-circle' },
  expense:       { color: colors.expense,    prefix: '-', icon: 'arrow-down-circle' },
  transfer:      { color: colors.transfer,   prefix: '→', icon: 'swap-horizontal' },
  saving:        { color: colors.saving,     prefix: '-', icon: 'piggy-bank' },
  investment:    { color: colors.investment, prefix: '-', icon: 'trending-up' },
  loan_given:    { color: colors.warning,    prefix: '-', icon: 'hand-coin' },
  loan_received: { color: colors.saving,     prefix: '+', icon: 'hand-coin-outline' },
};

export function TransactionItem({ transaction, category, accountName, onPress }: Props) {
  const typeConf = TYPE_CONFIG[transaction.type] ?? TYPE_CONFIG.expense;
  const catColor = category?.color ?? typeConf.color;
  const catIcon = (category?.icon as any) ?? typeConf.icon;
  const label = transaction.description || category?.name || transaction.type;

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.container, pressed && styles.pressed]}
      android_ripple={{ color: colors.brand.muted }}
    >
      {/* Category icon */}
      <View style={[styles.iconContainer, { backgroundColor: catColor + '22' }]}>
        <MaterialCommunityIcons name={catIcon as any} size={20} color={catColor} />
      </View>

      {/* Label + account */}
      <View style={styles.info}>
        <Text style={styles.label} numberOfLines={1}>{label}</Text>
        {accountName && (
          <Text style={styles.subLabel} numberOfLines={1}>{accountName}</Text>
        )}
      </View>

      {/* Amount */}
      <View style={styles.amountContainer}>
        <Text style={[styles.amount, { color: typeConf.color }]}>
          {typeConf.prefix}{formatCurrency(transaction.amount)}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.base,
    backgroundColor: 'transparent',
  },
  pressed: {
    backgroundColor: colors.brand.muted,
  },
  iconContainer: {
    width: 40,
    height: 40,
    borderRadius: radius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  info: {
    flex: 1,
    gap: 2,
  },
  label: {
    fontSize: 14,
    fontWeight: '500',
    color: colors.text.primary,
  },
  subLabel: {
    fontSize: 12,
    color: colors.text.muted,
  },
  amountContainer: {
    alignItems: 'flex-end',
  },
  amount: {
    fontSize: 15,
    fontWeight: '600',
  },
});
