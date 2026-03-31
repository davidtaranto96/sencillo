import React, { useEffect, useState } from 'react';
import { View, ScrollView, StyleSheet, Pressable } from 'react-native';
import {
  Text, Surface, FAB, Portal, Modal, Button, TextInput,
  ProgressBar, Divider,
} from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useGoalStore } from '@/src/stores/goalStore';
import { Goal } from '@/src/lib/types';
import { colors, spacing, radius, typography, shadows } from '@/src/lib/theme';
import { formatCurrency, calcProgress, getDaysUntil } from '@/src/lib/utils';

const GOAL_COLORS = ['#6C63FF', '#34D399', '#60A5FA', '#A78BFA', '#FBBF24', '#F472B6', '#FB923C'];
const GOAL_ICONS = ['flag-checkered', 'home', 'car', 'airplane', 'laptop', 'school', 'heart', 'star'];

function GoalCard({ goal, onPress }: { goal: Goal; onPress: () => void }) {
  const progress = calcProgress(goal.currentAmount, goal.targetAmount);
  const remaining = goal.targetAmount - goal.currentAmount;
  const daysLeft = goal.targetDate ? getDaysUntil(goal.targetDate) : null;

  return (
    <Pressable onPress={onPress} style={({ pressed }) => [pressed && { opacity: 0.9 }]}>
      <Surface style={[styles.goalCard, shadows.subtle]} elevation={2}>
        {/* Color bar */}
        <View style={[styles.goalColorBar, { backgroundColor: goal.color }]} />
        <View style={styles.goalBody}>
          {/* Icon + Name */}
          <View style={styles.goalHeader}>
            <View style={[styles.goalIconBg, { backgroundColor: goal.color + '22' }]}>
              <MaterialCommunityIcons
                name={(goal.icon as any) ?? 'flag-checkered'}
                size={22}
                color={goal.color}
              />
            </View>
            <View style={styles.goalTitleBlock}>
              <Text style={styles.goalName}>{goal.name}</Text>
              {daysLeft !== null && (
                <Text style={[styles.goalDays, { color: daysLeft < 30 ? colors.warning : colors.text.muted }]}>
                  {daysLeft > 0 ? `${daysLeft} días` : 'Vencido'}
                </Text>
              )}
            </View>
            <Text style={[styles.goalProgress, { color: goal.color }]}>{progress}%</Text>
          </View>

          {/* Progress */}
          <ProgressBar
            progress={progress / 100}
            color={goal.color}
            style={styles.goalProgressBar}
          />

          {/* Amounts */}
          <View style={styles.goalAmounts}>
            <Text style={styles.goalCurrent}>{formatCurrency(goal.currentAmount)}</Text>
            <Text style={styles.goalRemaining}>Faltan {formatCurrency(remaining)}</Text>
            <Text style={styles.goalTarget}>{formatCurrency(goal.targetAmount)}</Text>
          </View>
        </View>
      </Surface>
    </Pressable>
  );
}

export default function ObjetivosScreen() {
  const { goals, load, create } = useGoalStore();
  const [modalVisible, setModalVisible] = useState(false);
  const [newName, setNewName] = useState('');
  const [newTarget, setNewTarget] = useState('');
  const [newColor, setNewColor] = useState(GOAL_COLORS[0]);
  const [newIcon, setNewIcon] = useState(GOAL_ICONS[0]);

  useEffect(() => {
    load();
  }, []);

  function handleCreate() {
    const target = parseFloat(newTarget);
    if (!newName.trim() || isNaN(target) || target <= 0) return;
    create({
      name: newName.trim(),
      targetAmount: target,
      color: newColor,
      icon: newIcon,
      priority: goals.length + 1,
      status: 'active',
    });
    setNewName('');
    setNewTarget('');
    setModalVisible(false);
  }

  return (
    <View style={styles.root}>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Objetivos</Text>
          {goals.length > 0 && (
            <Text style={styles.subtitle}>{goals.length} activos</Text>
          )}
        </View>

        {goals.length === 0 ? (
          <Surface style={styles.emptyCard} elevation={1}>
            <MaterialCommunityIcons name="flag-outline" size={48} color={colors.text.muted} />
            <Text style={styles.emptyTitle}>Sin objetivos</Text>
            <Text style={styles.emptyText}>
              Creá tu primer objetivo con el botón +
            </Text>
          </Surface>
        ) : (
          goals.map((goal) => (
            <GoalCard
              key={goal.id}
              goal={goal}
              onPress={() => router.push(`/goal/${goal.id}` as any)}
            />
          ))
        )}

        <View style={{ height: 100 }} />
      </ScrollView>

      {/* New Goal Modal */}
      <Portal>
        <Modal
          visible={modalVisible}
          onDismiss={() => setModalVisible(false)}
          contentContainerStyle={styles.modal}
        >
          <Text style={styles.modalTitle}>Nuevo objetivo</Text>

          <TextInput
            mode="outlined"
            label="Nombre del objetivo"
            value={newName}
            onChangeText={setNewName}
            placeholder="Ej: Viaje a Europa"
            style={styles.modalInput}
          />
          <TextInput
            mode="outlined"
            label="Monto objetivo"
            value={newTarget}
            onChangeText={setNewTarget}
            keyboardType="numeric"
            left={<TextInput.Affix text="$" />}
            style={styles.modalInput}
          />

          {/* Color picker */}
          <Text style={styles.pickerLabel}>Color</Text>
          <View style={styles.colorPicker}>
            {GOAL_COLORS.map((c) => (
              <Pressable
                key={c}
                onPress={() => setNewColor(c)}
                style={[styles.colorDot, { backgroundColor: c }, newColor === c && styles.colorDotSelected]}
              />
            ))}
          </View>

          {/* Icon picker */}
          <Text style={styles.pickerLabel}>Ícono</Text>
          <View style={styles.iconPicker}>
            {GOAL_ICONS.map((icon) => (
              <Pressable
                key={icon}
                onPress={() => setNewIcon(icon)}
                style={[styles.iconBtn, newIcon === icon && { backgroundColor: newColor + '33', borderColor: newColor }]}
              >
                <MaterialCommunityIcons name={icon as any} size={20} color={newIcon === icon ? newColor : colors.text.muted} />
              </Pressable>
            ))}
          </View>

          <View style={styles.modalActions}>
            <Button mode="text" onPress={() => setModalVisible(false)} textColor={colors.text.muted}>
              Cancelar
            </Button>
            <Button mode="contained" onPress={handleCreate} style={{ backgroundColor: newColor }}>
              Crear objetivo
            </Button>
          </View>
        </Modal>
      </Portal>

      <FAB
        icon="plus"
        style={styles.fab}
        color="#FFFFFF"
        onPress={() => setModalVisible(true)}
      />
    </View>
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
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: spacing.sm,
  },
  title: {
    fontSize: typography.size['2xl'],
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  subtitle: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
  },
  goalCard: {
    borderRadius: radius.xl,
    backgroundColor: colors.bg.card,
    overflow: 'hidden',
  },
  goalColorBar: {
    height: 4,
    width: '100%',
  },
  goalBody: {
    padding: spacing.base,
    gap: spacing.md,
  },
  goalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  goalIconBg: {
    width: 44,
    height: 44,
    borderRadius: radius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  goalTitleBlock: {
    flex: 1,
  },
  goalName: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
  },
  goalDays: {
    fontSize: typography.size.xs,
    marginTop: 2,
  },
  goalProgress: {
    fontSize: typography.size.lg,
    fontWeight: typography.weight.bold,
  },
  goalProgressBar: {
    height: 8,
    borderRadius: radius.full,
    backgroundColor: colors.bg.elevated,
  },
  goalAmounts: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  goalCurrent: {
    fontSize: typography.size.sm,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
  },
  goalRemaining: {
    fontSize: typography.size.xs,
    color: colors.text.muted,
  },
  goalTarget: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
  },
  emptyCard: {
    borderRadius: radius.xl,
    padding: spacing['4xl'],
    backgroundColor: colors.bg.card,
    alignItems: 'center',
    gap: spacing.sm,
  },
  emptyTitle: {
    fontSize: typography.size.lg,
    fontWeight: typography.weight.semibold,
    color: colors.text.secondary,
  },
  emptyText: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
    textAlign: 'center',
  },
  fab: {
    position: 'absolute',
    right: spacing.base,
    bottom: spacing['2xl'],
    backgroundColor: colors.brand.primary,
  },
  modal: {
    margin: spacing.base,
    padding: spacing.xl,
    borderRadius: radius.xl,
    backgroundColor: colors.bg.card,
    gap: spacing.md,
  },
  modalTitle: {
    fontSize: typography.size.lg,
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
    marginBottom: spacing.xs,
  },
  modalInput: {
    backgroundColor: colors.bg.input,
  },
  pickerLabel: {
    fontSize: typography.size.sm,
    fontWeight: typography.weight.medium,
    color: colors.text.secondary,
  },
  colorPicker: {
    flexDirection: 'row',
    gap: spacing.sm,
    flexWrap: 'wrap',
  },
  colorDot: {
    width: 32,
    height: 32,
    borderRadius: radius.full,
  },
  colorDotSelected: {
    borderWidth: 3,
    borderColor: '#FFFFFF',
  },
  iconPicker: {
    flexDirection: 'row',
    gap: spacing.sm,
    flexWrap: 'wrap',
  },
  iconBtn: {
    width: 44,
    height: 44,
    borderRadius: radius.md,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: colors.bg.elevated,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.sm,
    marginTop: spacing.xs,
  },
});
