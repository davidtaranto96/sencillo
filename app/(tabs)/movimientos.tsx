import React, { useEffect, useCallback, useMemo } from 'react';
import { View, FlatList, StyleSheet, SectionList, RefreshControl } from 'react-native';
import { useSmartRefresh } from '@/src/hooks/useSmartRefresh';
import { Text, Surface, Searchbar, Divider } from 'react-native-paper';
import { useFab } from '@/src/hooks/useFab';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useTransactionStore } from '@/src/stores/transactionStore';
import { useCategoryStore } from '@/src/stores/categoryStore';
import { useAccountStore } from '@/src/stores/accountStore';
import { FilterChips } from '@/src/components/ui/FilterChips';
import { TransactionItem } from '@/src/components/cards/TransactionItem';
import { Transaction } from '@/src/lib/types';
import { colors, spacing, radius, typography } from '@/src/lib/theme';
import { formatDate } from '@/src/lib/utils';

const FILTER_OPTIONS = [
  { key: 'all', label: 'Todos', icon: 'format-list-bulleted' },
  { key: 'expense', label: 'Gastos', icon: 'arrow-down-circle' },
  { key: 'income', label: 'Ingresos', icon: 'arrow-up-circle' },
  { key: 'transfer', label: 'Transferencias', icon: 'swap-horizontal' },
];

type Section = { title: string; data: Transaction[] };

function groupByDate(transactions: Transaction[]): Section[] {
  const groups = new Map<string, Transaction[]>();
  for (const tx of transactions) {
    const date = tx.date.split('T')[0];
    if (!groups.has(date)) groups.set(date, []);
    groups.get(date)!.push(tx);
  }
  return Array.from(groups.entries())
    .sort(([a], [b]) => b.localeCompare(a))
    .map(([date, data]) => ({ title: formatDate(date), data }));
}

export default function MovimientosScreen() {
  const { transactions, load, filter, setFilter, searchQuery, setSearchQuery } = useTransactionStore();
  const { categories, load: loadCategories } = useCategoryStore();
  const { accounts, load: loadAccounts } = useAccountStore();

  const { refreshing, onRefresh } = useSmartRefresh(useCallback(() => {
    load();
    loadCategories();
    loadAccounts();
  }, []));

  useEffect(() => {
    load();
    loadCategories();
    loadAccounts();
  }, []);

  useFab({
    icon: 'plus',
    onPress: () => router.push('/transaction/new'),
  });

  // useMemo para evitar re-renders por nueva referencia de array
  const filtered = useMemo(() => {
    let result = transactions;
    if (filter !== 'all') {
      result = result.filter((t) =>
        filter === 'transfer' ? t.type === 'transfer' : t.type === filter
      );
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter((t) => t.description?.toLowerCase().includes(q));
    }
    return result;
  }, [transactions, filter, searchQuery]);

  const sections = useMemo(() => groupByDate(filtered), [filtered]);

  return (
    <View style={styles.root}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Movimientos</Text>
      </View>

      {/* Search */}
      <Searchbar
        placeholder="Buscar movimiento..."
        value={searchQuery}
        onChangeText={setSearchQuery}
        style={styles.searchbar}
        inputStyle={{ color: colors.text.primary }}
        iconColor={colors.text.muted}
        placeholderTextColor={colors.text.muted}
      />

      {/* Filters */}
      <View style={styles.filtersContainer}>
        <FilterChips
          options={FILTER_OPTIONS}
          selected={filter}
          onSelect={(k) => setFilter(k as any)}
        />
      </View>

      {/* List */}
      {sections.length === 0 ? (
        <View style={styles.empty}>
          <MaterialCommunityIcons name="receipt-text-outline" size={48} color={colors.text.muted} />
          <Text style={styles.emptyTitle}>Sin movimientos</Text>
          <Text style={styles.emptySub}>
            {filter !== 'all' ? 'No hay movimientos con este filtro' : 'Agregá tu primer movimiento con el botón +'}
          </Text>
        </View>
      ) : (
        <SectionList
          sections={sections}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          stickySectionHeadersEnabled={false}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.brand.primary} />}
          renderSectionHeader={({ section }) => (
            <Text style={styles.dateHeader}>{section.title}</Text>
          )}
          renderItem={({ item, index, section }) => {
            const cat = categories.find((c) => c.id === item.categoryId);
            const acc = accounts.find((a) => a.id === item.accountId);
            const isLast = index === section.data.length - 1;
            return (
              <>
                <Surface style={[styles.txCard, isLast && styles.txCardLast]} elevation={1}>
                  <TransactionItem
                    transaction={item}
                    category={cat}
                    accountName={acc?.name}
                    onPress={() => router.push(`/transaction/${item.id}` as any)}
                  />
                </Surface>
              </>
            );
          }}
          renderSectionFooter={() => <View style={{ height: spacing.md }} />}
        />
      )}

    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bg.primary,
  },
  header: {
    paddingTop: 56,
    paddingHorizontal: spacing.base,
    paddingBottom: spacing.sm,
  },
  title: {
    fontSize: typography.size['2xl'],
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  searchbar: {
    marginHorizontal: spacing.base,
    marginBottom: spacing.sm,
    backgroundColor: colors.bg.elevated,
    borderRadius: radius.lg,
    elevation: 0,
  },
  filtersContainer: {
    marginBottom: spacing.sm,
  },
  listContent: {
    paddingHorizontal: spacing.base,
    paddingBottom: 100,
  },
  dateHeader: {
    fontSize: typography.size.sm,
    fontWeight: typography.weight.semibold,
    color: colors.text.muted,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: spacing.xs,
    marginTop: spacing.sm,
  },
  txCard: {
    borderRadius: radius.lg,
    backgroundColor: colors.bg.card,
    overflow: 'hidden',
    marginBottom: 2,
  },
  txCardLast: {
    marginBottom: 0,
  },
  empty: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    padding: spacing['2xl'],
  },
  emptyTitle: {
    fontSize: typography.size.lg,
    fontWeight: typography.weight.semibold,
    color: colors.text.secondary,
  },
  emptySub: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
    textAlign: 'center',
  },
});
