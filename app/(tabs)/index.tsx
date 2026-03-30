import React, { useEffect, useCallback } from 'react';
import { View, ScrollView, StyleSheet, Pressable, RefreshControl } from 'react-native';
import { Text, Surface, FAB, Portal, Divider } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useAccountStore } from '@/src/stores/accountStore';
import { useTransactionStore } from '@/src/stores/transactionStore';
import { useCategoryStore } from '@/src/stores/categoryStore';
import { useGoalStore } from '@/src/stores/goalStore';
import { TransactionItem } from '@/src/components/cards/TransactionItem';
import { colors, spacing, radius, typography, shadows } from '@/src/lib/theme';
import { formatCurrency, formatMonthYear, calcProgress } from '@/src/lib/utils';
import { ProgressBar } from 'react-native-paper';

const now = new Date();

function SectionTitle({ title, onMore }: { title: string; onMore?: () => void }) {
  return (
    <View style={styles.sectionTitle}>
      <Text style={styles.sectionTitleText}>{title}</Text>
      {onMore && (
        <Pressable onPress={onMore}>
          <Text style={styles.sectionMore}>Ver todo</Text>
        </Pressable>
      )}
    </View>
  );
}

export default function HomeScreen() {
  const { accounts, totalBalance, load: loadAccounts } = useAccountStore();
  const { transactions, load: loadTransactions } = useTransactionStore();
  const { categories, load: loadCategories } = useCategoryStore();
  const { goals, load: loadGoals } = useGoalStore();

  const [fabOpen, setFabOpen] = React.useState(false);
  const [refreshing, setRefreshing] = React.useState(false);

  const loadAll = useCallback(() => {
    loadAccounts();
    loadTransactions();
    loadCategories();
    loadGoals();
  }, []);

  useEffect(() => {
    loadAll();
  }, []);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    loadAll();
    setRefreshing(false);
  }, []);

  // Month stats
  const monthTotals = useTransactionStore((s) => s.getMonthlyTotals(now.getFullYear(), now.getMonth() + 1));
  const monthlyBudget = accounts.reduce((sum, a) => sum + a.balance, 0);
  const spendProgress = monthTotals.income > 0
    ? calcProgress(monthTotals.expense, monthTotals.income)
    : 0;

  // Main goal (first active goal by priority)
  const mainGoal = goals[0] ?? null;
  const goalProgress = mainGoal ? calcProgress(mainGoal.currentAmount, mainGoal.targetAmount) : 0;

  // Recent transactions (last 5)
  const recentTransactions = transactions.slice(0, 5);

  const greeting = () => {
    const h = now.getHours();
    if (h < 12) return 'Buenos días';
    if (h < 18) return 'Buenas tardes';
    return 'Buenas noches';
  };

  return (
    <View style={styles.root}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.brand.primary} />}
      >
        {/* Header */}
        <View style={styles.header}>
          <View>
            <Text style={styles.greeting}>{greeting()} 👋</Text>
            <Text style={styles.month}>{formatMonthYear(now)}</Text>
          </View>
          <Pressable onPress={() => router.push('/personas/index')} style={styles.avatarBtn}>
            <View style={styles.avatar}>
              <MaterialCommunityIcons name="account" size={22} color={colors.brand.primary} />
            </View>
          </Pressable>
        </View>

        {/* Balance Card */}
        <Surface style={[styles.balanceCard, shadows.card]} elevation={3}>
          <Text style={styles.balanceLabel}>Patrimonio total</Text>
          <Text style={styles.balanceAmount}>{formatCurrency(totalBalance)}</Text>
          <View style={styles.balanceRow}>
            <View style={styles.balanceStat}>
              <MaterialCommunityIcons name="arrow-up-circle" size={16} color={colors.income} />
              <Text style={[styles.balanceStatText, { color: colors.income }]}>
                {formatCurrency(monthTotals.income)}
              </Text>
              <Text style={styles.balanceStatLabel}>ingresos</Text>
            </View>
            <View style={styles.balanceDivider} />
            <View style={styles.balanceStat}>
              <MaterialCommunityIcons name="arrow-down-circle" size={16} color={colors.expense} />
              <Text style={[styles.balanceStatText, { color: colors.expense }]}>
                {formatCurrency(monthTotals.expense)}
              </Text>
              <Text style={styles.balanceStatLabel}>gastos</Text>
            </View>
            <View style={styles.balanceDivider} />
            <View style={styles.balanceStat}>
              <MaterialCommunityIcons name="piggy-bank" size={16} color={colors.saving} />
              <Text style={[styles.balanceStatText, { color: colors.saving }]}>
                {formatCurrency(monthTotals.saving)}
              </Text>
              <Text style={styles.balanceStatLabel}>ahorrado</Text>
            </View>
          </View>
        </Surface>

        {/* Accounts */}
        {accounts.length > 0 && (
          <>
            <SectionTitle
              title="Cuentas"
              onMore={() => router.push('/account/[id]' as any)}
            />
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.accountsRow}
            >
              {accounts.map((acc) => (
                <Pressable
                  key={acc.id}
                  onPress={() => router.push(`/account/${acc.id}` as any)}
                  style={({ pressed }) => [styles.accountCard, pressed && { opacity: 0.85 }]}
                >
                  <Surface style={styles.accountSurface} elevation={2}>
                    <View style={[styles.accountColorBar, { backgroundColor: acc.color }]} />
                    <View style={styles.accountInfo}>
                      <MaterialCommunityIcons
                        name={(acc.icon as any) ?? 'bank'}
                        size={18}
                        color={acc.color}
                      />
                      <Text style={styles.accountName} numberOfLines={1}>{acc.name}</Text>
                      <Text style={styles.accountBalance}>{formatCurrency(acc.balance)}</Text>
                    </View>
                  </Surface>
                </Pressable>
              ))}
            </ScrollView>
          </>
        )}

        {/* Month Spending Progress */}
        {monthTotals.income > 0 && (
          <Surface style={styles.progressCard} elevation={2}>
            <View style={styles.progressHeader}>
              <Text style={styles.progressTitle}>Gasto del mes</Text>
              <Text style={styles.progressPercent}>{spendProgress}%</Text>
            </View>
            <ProgressBar
              progress={spendProgress / 100}
              color={spendProgress > 80 ? colors.expense : colors.brand.primary}
              style={styles.progressBar}
            />
            <Text style={styles.progressSub}>
              {formatCurrency(monthTotals.expense)} de {formatCurrency(monthTotals.income)}
            </Text>
          </Surface>
        )}

        {/* Main Goal */}
        {mainGoal && (
          <Pressable onPress={() => router.push(`/goal/${mainGoal.id}` as any)}>
            <Surface style={styles.progressCard} elevation={2}>
              <View style={styles.progressHeader}>
                <View style={styles.goalTitleRow}>
                  <MaterialCommunityIcons
                    name={(mainGoal.icon as any) ?? 'flag-checkered'}
                    size={16}
                    color={mainGoal.color}
                  />
                  <Text style={styles.progressTitle}>{mainGoal.name}</Text>
                </View>
                <Text style={[styles.progressPercent, { color: mainGoal.color }]}>
                  {goalProgress}%
                </Text>
              </View>
              <ProgressBar
                progress={goalProgress / 100}
                color={mainGoal.color}
                style={styles.progressBar}
              />
              <Text style={styles.progressSub}>
                {formatCurrency(mainGoal.currentAmount)} de {formatCurrency(mainGoal.targetAmount)}
              </Text>
            </Surface>
          </Pressable>
        )}

        {/* Recent Transactions */}
        {recentTransactions.length > 0 && (
          <>
            <SectionTitle
              title="Últimos movimientos"
              onMore={() => router.push('/(tabs)/movimientos' as any)}
            />
            <Surface style={styles.transactionList} elevation={2}>
              {recentTransactions.map((tx, idx) => {
                const cat = categories.find((c) => c.id === tx.categoryId);
                const acc = accounts.find((a) => a.id === tx.accountId);
                return (
                  <React.Fragment key={tx.id}>
                    <TransactionItem
                      transaction={tx}
                      category={cat}
                      accountName={acc?.name}
                      onPress={() => router.push(`/transaction/${tx.id}` as any)}
                    />
                    {idx < recentTransactions.length - 1 && (
                      <Divider style={styles.divider} />
                    )}
                  </React.Fragment>
                );
              })}
            </Surface>
          </>
        )}

        {recentTransactions.length === 0 && (
          <Surface style={styles.emptyState} elevation={1}>
            <MaterialCommunityIcons name="cash-register" size={40} color={colors.text.muted} />
            <Text style={styles.emptyTitle}>Sin movimientos</Text>
            <Text style={styles.emptySub}>
              Registrá tu primer gasto con el botón +
            </Text>
          </Surface>
        )}

        <View style={{ height: 100 }} />
      </ScrollView>

      {/* FAB */}
      <Portal>
        <FAB.Group
          open={fabOpen}
          visible
          icon={fabOpen ? 'close' : 'plus'}
          color="#FFFFFF"
          fabStyle={styles.fab}
          actions={[
            {
              icon: 'swap-horizontal',
              label: 'Transferencia',
              onPress: () => router.push({ pathname: '/transaction/new', params: { type: 'transfer' } }),
              style: { backgroundColor: colors.bg.elevated },
            },
            {
              icon: 'piggy-bank',
              label: 'Ahorro',
              onPress: () => router.push({ pathname: '/transaction/new', params: { type: 'saving' } }),
              style: { backgroundColor: colors.bg.elevated },
            },
            {
              icon: 'arrow-up-circle',
              label: 'Ingreso',
              onPress: () => router.push({ pathname: '/transaction/new', params: { type: 'income' } }),
              style: { backgroundColor: colors.bg.elevated },
            },
            {
              icon: 'arrow-down-circle',
              label: 'Gasto',
              onPress: () => router.push({ pathname: '/transaction/new', params: { type: 'expense' } }),
              style: { backgroundColor: colors.bg.elevated },
            },
          ]}
          onStateChange={({ open }) => setFabOpen(open)}
          style={styles.fabGroup}
        />
      </Portal>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bg.primary,
  },
  scroll: {
    flex: 1,
  },
  content: {
    paddingTop: 56,
    paddingHorizontal: spacing.base,
    gap: spacing.md,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.xs,
  },
  greeting: {
    fontSize: typography.size.lg,
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  month: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
    textTransform: 'capitalize',
    marginTop: 2,
  },
  avatarBtn: {},
  avatar: {
    width: 40,
    height: 40,
    borderRadius: radius.full,
    backgroundColor: colors.brand.muted,
    justifyContent: 'center',
    alignItems: 'center',
  },
  balanceCard: {
    borderRadius: radius.xl,
    padding: spacing.xl,
    backgroundColor: colors.bg.card,
    gap: spacing.sm,
  },
  balanceLabel: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  balanceAmount: {
    fontSize: typography.size['2xl'],
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  balanceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: spacing.sm,
  },
  balanceStat: {
    flex: 1,
    alignItems: 'center',
    gap: 2,
  },
  balanceStatText: {
    fontSize: typography.size.sm,
    fontWeight: typography.weight.semibold,
  },
  balanceStatLabel: {
    fontSize: typography.size.xs,
    color: colors.text.muted,
  },
  balanceDivider: {
    width: 1,
    height: 32,
    backgroundColor: colors.border.default,
  },
  sectionTitle: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: spacing.sm,
  },
  sectionTitleText: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
  },
  sectionMore: {
    fontSize: typography.size.sm,
    color: colors.brand.primary,
  },
  accountsRow: {
    gap: spacing.md,
    paddingRight: spacing.base,
  },
  accountCard: {
    width: 140,
  },
  accountSurface: {
    borderRadius: radius.lg,
    overflow: 'hidden',
    backgroundColor: colors.bg.card,
  },
  accountColorBar: {
    height: 4,
    width: '100%',
  },
  accountInfo: {
    padding: spacing.md,
    gap: spacing.xs,
  },
  accountName: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
  },
  accountBalance: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
    marginTop: 2,
  },
  progressCard: {
    borderRadius: radius.lg,
    padding: spacing.base,
    backgroundColor: colors.bg.card,
    gap: spacing.sm,
  },
  progressHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  progressTitle: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.medium,
    color: colors.text.primary,
  },
  progressPercent: {
    fontSize: typography.size.sm,
    fontWeight: typography.weight.semibold,
    color: colors.brand.primary,
  },
  goalTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  progressBar: {
    height: 8,
    borderRadius: radius.full,
    backgroundColor: colors.bg.elevated,
  },
  progressSub: {
    fontSize: typography.size.xs,
    color: colors.text.muted,
  },
  transactionList: {
    borderRadius: radius.lg,
    overflow: 'hidden',
    backgroundColor: colors.bg.card,
  },
  divider: {
    backgroundColor: colors.border.subtle,
    marginHorizontal: spacing.base,
  },
  emptyState: {
    borderRadius: radius.xl,
    padding: spacing['3xl'],
    backgroundColor: colors.bg.card,
    alignItems: 'center',
    gap: spacing.sm,
  },
  emptyTitle: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.semibold,
    color: colors.text.secondary,
  },
  emptySub: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
    textAlign: 'center',
  },
  fab: {
    backgroundColor: colors.brand.primary,
  },
  fabGroup: {
    paddingBottom: 80,
  },
});
