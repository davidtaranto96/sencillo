import React, { useEffect } from 'react';
import { View, ScrollView, StyleSheet } from 'react-native';
import { Text, Surface, ProgressBar, Divider } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useCategoryStore } from '@/src/stores/categoryStore';
import { budgetService } from '@/src/services/budgetService';
import { transactionService } from '@/src/services/transactionService';
import { colors, spacing, radius, typography } from '@/src/lib/theme';
import { formatCurrency, calcProgress } from '@/src/lib/utils';

const now = new Date();

const BUCKET_ICONS: Record<string, string> = {
  emergency_fund: 'shield-check',
  investment: 'trending-up',
  living: 'home',
  fun: 'party-popper',
  goal: 'flag-checkered',
  free: 'cash',
};

export default function PresupuestoScreen() {
  const { categories, load: loadCategories } = useCategoryStore();
  const [salaryRule, setSalaryRule] = React.useState<ReturnType<typeof budgetService.getSalaryRule>>(null);
  const [categorySpending, setCategorySpending] = React.useState<{ categoryId: string; total: number }[]>([]);
  const [monthlyIncome, setMonthlyIncome] = React.useState(0);

  useEffect(() => {
    loadCategories();
    try {
      setSalaryRule(budgetService.getSalaryRule());
      setCategorySpending(transactionService.getCategorySpending(now.getFullYear(), now.getMonth() + 1));
      setMonthlyIncome(budgetService.getMonthlyIncome(now.getFullYear(), now.getMonth() + 1));
    } catch {
      // SQLite no disponible (web preview)
    }
  }, []);

  const buckets = salaryRule?.buckets ?? [];

  return (
    <ScrollView
      style={styles.root}
      contentContainerStyle={styles.content}
      showsVerticalScrollIndicator={false}
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Presupuesto</Text>
        <Text style={styles.subtitle}>
          {now.toLocaleDateString('es-AR', { month: 'long', year: 'numeric' })}
        </Text>
      </View>

      {/* Income summary */}
      <Surface style={styles.incomeCard} elevation={2}>
        <View style={styles.incomeRow}>
          <MaterialCommunityIcons name="cash-plus" size={24} color={colors.income} />
          <View style={styles.incomeInfo}>
            <Text style={styles.incomeLabel}>Ingresos del mes</Text>
            <Text style={styles.incomeAmount}>{formatCurrency(monthlyIncome)}</Text>
          </View>
        </View>
      </Surface>

      {/* Salary Distribution */}
      {buckets.length > 0 && (
        <>
          <Text style={styles.sectionTitle}>Distribución del sueldo</Text>
          <Surface style={styles.bucketsCard} elevation={2}>
            {buckets.map((bucket, idx) => {
              const allocated = Math.round((monthlyIncome * bucket.percentage) / 100);
              return (
                <React.Fragment key={bucket.id}>
                  <View style={styles.bucketRow}>
                    <View style={[styles.bucketIcon, { backgroundColor: bucket.color + '22' }]}>
                      <MaterialCommunityIcons
                        name={(BUCKET_ICONS[bucket.type] ?? 'cash') as any}
                        size={18}
                        color={bucket.color}
                      />
                    </View>
                    <View style={styles.bucketInfo}>
                      <Text style={styles.bucketName}>{bucket.name}</Text>
                      <Text style={styles.bucketAmount}>
                        {formatCurrency(allocated)}
                        <Text style={styles.bucketPercent}>  ({bucket.percentage}%)</Text>
                      </Text>
                    </View>
                    <View style={[styles.percentBadge, { backgroundColor: bucket.color + '22' }]}>
                      <Text style={[styles.percentBadgeText, { color: bucket.color }]}>
                        {bucket.percentage}%
                      </Text>
                    </View>
                  </View>
                  {idx < buckets.length - 1 && <Divider style={styles.divider} />}
                </React.Fragment>
              );
            })}
          </Surface>
        </>
      )}

      {/* Category Spending */}
      {categorySpending.length > 0 && (
        <>
          <Text style={styles.sectionTitle}>Gastos por categoría</Text>
          <Surface style={styles.bucketsCard} elevation={2}>
            {categorySpending.map((item, idx) => {
              const cat = categories.find((c) => c.id === item.categoryId);
              if (!cat) return null;
              const budgetLimit = monthlyIncome > 0
                ? Math.round((monthlyIncome * 0.5) / Math.max(categorySpending.length, 1))
                : item.total;
              const progress = calcProgress(item.total, budgetLimit);
              const isOver = progress >= 90;
              return (
                <React.Fragment key={item.categoryId}>
                  <View style={styles.catSpendRow}>
                    <View style={[styles.bucketIcon, { backgroundColor: cat.color + '22' }]}>
                      <MaterialCommunityIcons name={cat.icon as any} size={18} color={cat.color} />
                    </View>
                    <View style={styles.catSpendInfo}>
                      <View style={styles.catSpendHeader}>
                        <Text style={styles.catSpendName}>{cat.name}</Text>
                        <Text style={[styles.catSpendAmount, { color: isOver ? colors.expense : colors.text.primary }]}>
                          {formatCurrency(item.total)}
                        </Text>
                      </View>
                      <ProgressBar
                        progress={Math.min(progress / 100, 1)}
                        color={isOver ? colors.expense : cat.color}
                        style={styles.catProgressBar}
                      />
                    </View>
                  </View>
                  {idx < categorySpending.length - 1 && <Divider style={styles.divider} />}
                </React.Fragment>
              );
            })}
          </Surface>
        </>
      )}

      {categorySpending.length === 0 && (
        <Surface style={styles.emptyCard} elevation={1}>
          <MaterialCommunityIcons name="chart-donut" size={40} color={colors.text.muted} />
          <Text style={styles.emptyText}>Sin gastos registrados este mes</Text>
        </Surface>
      )}

      <View style={{ height: 80 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bg.primary,
  },
  content: {
    paddingTop: 56,
    paddingHorizontal: spacing.base,
    gap: spacing.md,
  },
  header: {
    marginBottom: spacing.xs,
  },
  title: {
    fontSize: typography.size['2xl'],
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  subtitle: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
    textTransform: 'capitalize',
  },
  sectionTitle: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
    marginTop: spacing.xs,
  },
  incomeCard: {
    borderRadius: radius.lg,
    padding: spacing.base,
    backgroundColor: colors.bg.card,
  },
  incomeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  incomeInfo: {
    flex: 1,
  },
  incomeLabel: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
  },
  incomeAmount: {
    fontSize: typography.size.xl,
    fontWeight: typography.weight.bold,
    color: colors.income,
  },
  bucketsCard: {
    borderRadius: radius.lg,
    backgroundColor: colors.bg.card,
    overflow: 'hidden',
  },
  bucketRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.base,
  },
  bucketIcon: {
    width: 40,
    height: 40,
    borderRadius: radius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  bucketInfo: {
    flex: 1,
  },
  bucketName: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.medium,
    color: colors.text.primary,
  },
  bucketAmount: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
    marginTop: 2,
  },
  bucketPercent: {
    color: colors.text.muted,
  },
  percentBadge: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 4,
    borderRadius: radius.full,
  },
  percentBadgeText: {
    fontSize: typography.size.sm,
    fontWeight: typography.weight.semibold,
  },
  divider: {
    marginHorizontal: spacing.base,
    backgroundColor: colors.border.subtle,
  },
  catSpendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.base,
  },
  catSpendInfo: {
    flex: 1,
    gap: spacing.xs,
  },
  catSpendHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  catSpendName: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.medium,
    color: colors.text.primary,
  },
  catSpendAmount: {
    fontSize: typography.size.sm,
    fontWeight: typography.weight.semibold,
  },
  catProgressBar: {
    height: 6,
    borderRadius: radius.full,
    backgroundColor: colors.bg.elevated,
  },
  emptyCard: {
    borderRadius: radius.xl,
    padding: spacing['3xl'],
    backgroundColor: colors.bg.card,
    alignItems: 'center',
    gap: spacing.sm,
  },
  emptyText: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
  },
});
