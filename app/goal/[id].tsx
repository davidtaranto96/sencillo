import React, { useEffect, useState } from 'react';
import { View, ScrollView, StyleSheet, Pressable } from 'react-native';
import { Text, Surface, Button, ProgressBar, TextInput, Modal, Portal } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useGoalStore } from '@/src/stores/goalStore';
import { colors, spacing, radius, typography } from '@/src/lib/theme';
import { formatCurrency, calcProgress, getDaysUntil } from '@/src/lib/utils';

export default function GoalDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { goals, load, addContribution } = useGoalStore();
  const [contributeVisible, setContributeVisible] = useState(false);
  const [contribAmount, setContribAmount] = useState('');

  useEffect(() => { load(); }, []);

  const goal = goals.find((g) => g.id === id);
  if (!goal) {
    return (
      <View style={[styles.root, styles.center]}>
        <Text style={{ color: colors.text.muted }}>Objetivo no encontrado</Text>
        <Button onPress={() => router.back()}>Volver</Button>
      </View>
    );
  }

  const progress = calcProgress(goal.currentAmount, goal.targetAmount);
  const remaining = goal.targetAmount - goal.currentAmount;
  const daysLeft = goal.targetDate ? getDaysUntil(goal.targetDate) : null;
  const monthlyNeeded = daysLeft && daysLeft > 0
    ? remaining / Math.max(daysLeft / 30, 1)
    : null;

  function handleContribute() {
    const amount = parseFloat(contribAmount);
    if (isNaN(amount) || amount <= 0) return;
    addContribution(goal!.id, amount);
    setContribAmount('');
    setContributeVisible(false);
  }

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backBtn}>
          <MaterialCommunityIcons name="arrow-left" size={24} color={colors.text.secondary} />
        </Pressable>
        <Text style={styles.headerTitle}>Objetivo</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Goal Hero */}
        <Surface style={[styles.heroCard, { borderTopColor: goal.color }]} elevation={3}>
          <View style={[styles.iconBg, { backgroundColor: goal.color + '22' }]}>
            <MaterialCommunityIcons
              name={(goal.icon as any) ?? 'flag-checkered'}
              size={36}
              color={goal.color}
            />
          </View>
          <Text style={styles.goalName}>{goal.name}</Text>
          {goal.description && (
            <Text style={styles.goalDesc}>{goal.description}</Text>
          )}
          <Text style={[styles.progressPercent, { color: goal.color }]}>{progress}%</Text>
          <ProgressBar
            progress={progress / 100}
            color={goal.color}
            style={styles.progressBar}
          />
          <View style={styles.amountRow}>
            <Text style={styles.currentAmount}>{formatCurrency(goal.currentAmount)}</Text>
            <Text style={styles.targetAmount}>de {formatCurrency(goal.targetAmount)}</Text>
          </View>
        </Surface>

        {/* Stats */}
        <View style={styles.statsRow}>
          <Surface style={styles.statCard} elevation={2}>
            <Text style={styles.statValue}>{formatCurrency(remaining)}</Text>
            <Text style={styles.statLabel}>Falta</Text>
          </Surface>
          {daysLeft !== null && (
            <Surface style={styles.statCard} elevation={2}>
              <Text style={[styles.statValue, { color: daysLeft < 30 ? colors.warning : colors.text.primary }]}>
                {daysLeft}d
              </Text>
              <Text style={styles.statLabel}>Días</Text>
            </Surface>
          )}
          {monthlyNeeded !== null && (
            <Surface style={styles.statCard} elevation={2}>
              <Text style={styles.statValue}>{formatCurrency(monthlyNeeded)}</Text>
              <Text style={styles.statLabel}>Por mes</Text>
            </Surface>
          )}
        </View>

        {/* Contribute */}
        {goal.status === 'active' && (
          <Button
            mode="contained"
            icon="plus"
            onPress={() => setContributeVisible(true)}
            style={[styles.contributeBtn, { backgroundColor: goal.color }]}
            contentStyle={styles.contributeBtnContent}
          >
            Agregar contribución
          </Button>
        )}

        {goal.status === 'completed' && (
          <Surface style={styles.completedCard} elevation={1}>
            <MaterialCommunityIcons name="check-circle" size={32} color={colors.income} />
            <Text style={styles.completedText}>¡Objetivo alcanzado! 🎉</Text>
          </Surface>
        )}
      </ScrollView>

      {/* Contribute Modal */}
      <Portal>
        <Modal
          visible={contributeVisible}
          onDismiss={() => setContributeVisible(false)}
          contentContainerStyle={styles.modal}
        >
          <Text style={styles.modalTitle}>Contribuir a "{goal.name}"</Text>
          <TextInput
            mode="outlined"
            label="Monto"
            value={contribAmount}
            onChangeText={setContribAmount}
            keyboardType="numeric"
            left={<TextInput.Affix text="$" />}
            autoFocus
            style={styles.modalInput}
          />
          <View style={styles.modalActions}>
            <Button mode="text" onPress={() => setContributeVisible(false)} textColor={colors.text.muted}>
              Cancelar
            </Button>
            <Button
              mode="contained"
              onPress={handleContribute}
              style={{ backgroundColor: goal.color }}
            >
              Agregar
            </Button>
          </View>
        </Modal>
      </Portal>
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
  heroCard: {
    borderRadius: radius.xl,
    padding: spacing.xl,
    backgroundColor: colors.bg.card,
    alignItems: 'center',
    gap: spacing.sm,
    borderTopWidth: 3,
  },
  iconBg: {
    width: 72, height: 72, borderRadius: radius.full,
    justifyContent: 'center', alignItems: 'center',
  },
  goalName: {
    fontSize: typography.size.xl,
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
    textAlign: 'center',
  },
  goalDesc: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
    textAlign: 'center',
  },
  progressPercent: {
    fontSize: typography.size['2xl'],
    fontWeight: typography.weight.bold,
  },
  progressBar: {
    width: '100%',
    height: 12,
    borderRadius: radius.full,
    backgroundColor: colors.bg.elevated,
  },
  amountRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    alignItems: 'baseline',
  },
  currentAmount: {
    fontSize: typography.size.lg,
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  targetAmount: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
  },
  statsRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  statCard: {
    flex: 1,
    borderRadius: radius.lg,
    padding: spacing.base,
    backgroundColor: colors.bg.card,
    alignItems: 'center',
    gap: 4,
  },
  statValue: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  statLabel: {
    fontSize: typography.size.xs,
    color: colors.text.muted,
  },
  contributeBtn: {
    borderRadius: radius.lg,
    marginTop: spacing.sm,
  },
  contributeBtnContent: {
    paddingVertical: spacing.sm,
  },
  completedCard: {
    borderRadius: radius.lg,
    padding: spacing.xl,
    backgroundColor: colors.bg.card,
    alignItems: 'center',
    gap: spacing.sm,
  },
  completedText: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.semibold,
    color: colors.income,
  },
  modal: {
    margin: spacing.base,
    padding: spacing.xl,
    borderRadius: radius.xl,
    backgroundColor: colors.bg.card,
    gap: spacing.md,
  },
  modalTitle: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  modalInput: { backgroundColor: colors.bg.input },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.sm,
  },
});
