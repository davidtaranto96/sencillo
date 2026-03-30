import React, { useEffect } from 'react';
import { View, ScrollView, StyleSheet, Pressable } from 'react-native';
import { Text, Surface, Divider } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useAccountStore } from '@/src/stores/accountStore';
import { useTransactionStore } from '@/src/stores/transactionStore';
import { useCategoryStore } from '@/src/stores/categoryStore';
import { TransactionItem } from '@/src/components/cards/TransactionItem';
import { transactionService } from '@/src/services/transactionService';
import { colors, spacing, radius, typography } from '@/src/lib/theme';
import { formatCurrency } from '@/src/lib/utils';

const ACCOUNT_TYPE_LABELS: Record<string, string> = {
  bank: 'Banco',
  digital_wallet: 'Billetera digital',
  cash: 'Efectivo',
  credit_card: 'Tarjeta de crédito',
  investment: 'Inversión',
  savings: 'Ahorro',
};

export default function AccountDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { accounts, load } = useAccountStore();
  const { categories, load: loadCat } = useCategoryStore();

  const account = accounts.find((a) => a.id === id);
  const [transactions, setTransactions] = React.useState(
    () => id ? transactionService.getByAccount(id) : []
  );

  useEffect(() => {
    load(); loadCat();
    if (id) setTransactions(transactionService.getByAccount(id));
  }, [id]);

  if (!account) {
    return (
      <View style={[styles.root, styles.center]}>
        <Text style={{ color: colors.text.muted }}>Cuenta no encontrada</Text>
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backBtn}>
          <MaterialCommunityIcons name="arrow-left" size={24} color={colors.text.secondary} />
        </Pressable>
        <Text style={styles.headerTitle}>Cuenta</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Account Card */}
        <Surface style={[styles.accountCard, { borderTopColor: account.color }]} elevation={3}>
          <View style={[styles.iconBg, { backgroundColor: account.color + '22' }]}>
            <MaterialCommunityIcons
              name={(account.icon as any) ?? 'bank'}
              size={32}
              color={account.color}
            />
          </View>
          <Text style={styles.accountName}>{account.name}</Text>
          <Text style={styles.accountType}>
            {ACCOUNT_TYPE_LABELS[account.type] ?? account.type}
          </Text>
          <Text style={[styles.balance, { color: account.balance >= 0 ? colors.income : colors.expense }]}>
            {formatCurrency(account.balance)}
          </Text>
        </Surface>

        {/* Transactions */}
        <Text style={styles.sectionTitle}>Movimientos recientes</Text>
        {transactions.length === 0 ? (
          <Surface style={styles.emptyCard} elevation={1}>
            <Text style={styles.emptyText}>Sin movimientos en esta cuenta</Text>
          </Surface>
        ) : (
          <Surface style={styles.txList} elevation={1}>
            {transactions.map((tx, idx) => {
              const cat = categories.find((c) => c.id === tx.categoryId);
              return (
                <React.Fragment key={tx.id}>
                  <TransactionItem
                    transaction={tx}
                    category={cat}
                    onPress={() => router.push(`/transaction/${tx.id}` as any)}
                  />
                  {idx < transactions.length - 1 && (
                    <Divider style={styles.divider} />
                  )}
                </React.Fragment>
              );
            })}
          </Surface>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg.primary },
  center: { justifyContent: 'center', alignItems: 'center' },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: 56,
    paddingHorizontal: spacing.base,
    paddingBottom: spacing.base,
  },
  backBtn: { width: 40, height: 40, justifyContent: 'center', alignItems: 'center' },
  headerTitle: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
  },
  content: { padding: spacing.base, gap: spacing.md },
  accountCard: {
    borderRadius: radius.xl,
    padding: spacing.xl,
    backgroundColor: colors.bg.card,
    alignItems: 'center',
    gap: spacing.sm,
    borderTopWidth: 3,
  },
  iconBg: {
    width: 64, height: 64, borderRadius: radius.full,
    justifyContent: 'center', alignItems: 'center',
  },
  accountName: {
    fontSize: typography.size.xl,
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  accountType: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
  },
  balance: {
    fontSize: typography.size['2xl'],
    fontWeight: typography.weight.bold,
    marginTop: spacing.sm,
  },
  sectionTitle: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
    marginTop: spacing.xs,
  },
  txList: {
    borderRadius: radius.lg,
    overflow: 'hidden',
    backgroundColor: colors.bg.card,
  },
  divider: {
    marginHorizontal: spacing.base,
    backgroundColor: colors.border.subtle,
  },
  emptyCard: {
    borderRadius: radius.lg,
    padding: spacing.xl,
    backgroundColor: colors.bg.card,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
  },
});
