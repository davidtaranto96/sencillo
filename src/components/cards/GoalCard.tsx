import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Goal } from '@/src/lib/types';
import { formatCurrency, calcProgress } from '@/src/lib/utils';
import { ProgressBar } from '@/src/components/ui/ProgressBar';
import { colors, radius, spacing, typography } from '@/src/lib/theme';

interface Props {
  goal: Goal;
  onPress?: () => void;
}

export function GoalCard({ goal, onPress }: Props) {
  const progress = calcProgress(goal.currentAmount, goal.targetAmount);
  const remaining = goal.targetAmount - goal.currentAmount;

  return (
    <Pressable
      style={({ pressed }) => [styles.card, pressed && styles.pressed]}
      onPress={onPress}
    >
      <View style={styles.header}>
        <View style={[styles.iconBg, { backgroundColor: goal.color + '22' }]}>
          <Text style={styles.icon}>{goal.icon ?? '◎'}</Text>
        </View>
        <View style={styles.info}>
          <Text style={styles.name}>{goal.name}</Text>
          <Text style={styles.sub}>
            {formatCurrency(goal.currentAmount)} de {formatCurrency(goal.targetAmount)}
          </Text>
        </View>
        <Text style={[styles.percent, { color: goal.color }]}>{progress}%</Text>
      </View>
      <View style={styles.progressRow}>
        <ProgressBar progress={progress} color={goal.color} height={5} />
      </View>
      <Text style={styles.remaining}>Faltan {formatCurrency(remaining)}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.bg.card,
    borderRadius: radius.lg,
    padding: spacing.base,
    borderWidth: 1,
    borderColor: colors.border.default,
    gap: spacing.sm,
  },
  pressed: {
    opacity: 0.85,
    transform: [{ scale: 0.99 }],
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  iconBg: {
    width: 40,
    height: 40,
    borderRadius: radius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  icon: {
    fontSize: 20,
  },
  info: {
    flex: 1,
    gap: 2,
  },
  name: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
  },
  sub: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
  },
  percent: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.bold,
  },
  progressRow: {
    marginHorizontal: 0,
  },
  remaining: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
  },
});
