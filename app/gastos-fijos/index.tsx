import React, { useEffect, useState } from 'react';
import { View, ScrollView, StyleSheet, Pressable } from 'react-native';
import { Text, Surface, FAB, Portal, Modal, Button, TextInput, Chip, Divider } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import * as SQLite from 'expo-sqlite';
import { generateId, formatCurrency, getDaysUntil } from '@/src/lib/utils';
import { RecurringExpense } from '@/src/lib/types';
import { colors, spacing, radius, typography } from '@/src/lib/theme';
import { useCategoryStore } from '@/src/stores/categoryStore';
import { useAccountStore } from '@/src/stores/accountStore';

function getDb() { return SQLite.openDatabaseSync('finanzas.db'); }

function loadExpenses(): RecurringExpense[] {
  return getDb().getAllSync<any>(
    "SELECT * FROM recurring_expenses WHERE is_active = 1 ORDER BY next_due_at ASC", []
  ).map((r: any) => ({
    id: r.id, name: r.name, amount: r.amount, frequency: r.frequency,
    dueDay: r.due_day, accountId: r.account_id, categoryId: r.category_id,
    isActive: Boolean(r.is_active), autoCreate: Boolean(r.auto_create),
    reminder: Boolean(r.reminder), lastPaidAt: r.last_paid_at, nextDueAt: r.next_due_at,
  }));
}

const FREQ_LABELS: Record<string, string> = {
  monthly: 'Mensual', weekly: 'Semanal', annual: 'Anual',
};

export default function GastosFijosScreen() {
  const { categories, load: loadCategories } = useCategoryStore();
  const { accounts, load: loadAccounts } = useAccountStore();
  const [expenses, setExpenses] = useState<RecurringExpense[]>([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [newName, setNewName] = useState('');
  const [newAmount, setNewAmount] = useState('');
  const [newDueDay, setNewDueDay] = useState('1');
  const [newFreq, setNewFreq] = useState<'monthly' | 'weekly' | 'annual'>('monthly');

  useEffect(() => {
    setExpenses(loadExpenses());
    loadCategories();
    loadAccounts();
  }, []);

  function refresh() { setExpenses(loadExpenses()); }

  function handleCreate() {
    const amount = parseFloat(newAmount);
    const dueDay = parseInt(newDueDay);
    if (!newName.trim() || isNaN(amount) || isNaN(dueDay)) return;
    const db = getDb();
    const id = generateId();
    const defaultCat = categories.find(c => c.type === 'expense') ?? categories[0];
    const defaultAcc = accounts[0];
    if (!defaultCat || !defaultAcc) return;
    // Calculate next due date
    const now = new Date();
    let nextDue = new Date(now.getFullYear(), now.getMonth(), dueDay);
    if (nextDue <= now) nextDue = new Date(now.getFullYear(), now.getMonth() + 1, dueDay);
    db.runSync(
      'INSERT INTO recurring_expenses (id, name, amount, frequency, due_day, account_id, category_id, is_active, auto_create, reminder, next_due_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, newName.trim(), amount, newFreq, dueDay, defaultAcc.id, defaultCat.id, 1, 0, 1, nextDue.toISOString().split('T')[0]]
    );
    setNewName(''); setNewAmount('');
    setModalVisible(false);
    refresh();
  }

  function markPaid(id: string) {
    const db = getDb();
    const now = new Date();
    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());
    db.runSync('UPDATE recurring_expenses SET last_paid_at = ?, next_due_at = ? WHERE id = ?',
      [now.toISOString(), nextMonth.toISOString().split('T')[0], id]);
    refresh();
  }

  const totalMonthly = expenses
    .filter(e => e.frequency === 'monthly')
    .reduce((s, e) => s + e.amount, 0);

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backBtn}>
          <MaterialCommunityIcons name="arrow-left" size={24} color={colors.text.secondary} />
        </Pressable>
        <Text style={styles.title}>Gastos fijos</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Monthly total */}
        {expenses.length > 0 && (
          <Surface style={styles.totalCard} elevation={2}>
            <Text style={styles.totalLabel}>Compromiso mensual</Text>
            <Text style={styles.totalAmount}>{formatCurrency(totalMonthly)}</Text>
          </Surface>
        )}

        {expenses.length === 0 ? (
          <Surface style={styles.emptyCard} elevation={1}>
            <MaterialCommunityIcons name="calendar-clock" size={48} color={colors.text.muted} />
            <Text style={styles.emptyTitle}>Sin gastos fijos</Text>
            <Text style={styles.emptyText}>Agregá alquiler, servicios, suscripciones...</Text>
          </Surface>
        ) : (
          <Surface style={styles.listCard} elevation={1}>
            {expenses.map((exp, idx) => {
              const daysLeft = getDaysUntil(exp.nextDueAt);
              const isUrgent = daysLeft <= 3;
              const cat = categories.find(c => c.id === exp.categoryId);
              return (
                <React.Fragment key={exp.id}>
                  <View style={styles.expRow}>
                    <View style={[styles.expIcon, { backgroundColor: (cat?.color ?? colors.warning) + '22' }]}>
                      <MaterialCommunityIcons
                        name={(cat?.icon as any) ?? 'calendar-clock'}
                        size={20} color={cat?.color ?? colors.warning}
                      />
                    </View>
                    <View style={styles.expInfo}>
                      <Text style={styles.expName}>{exp.name}</Text>
                      <View style={styles.expMeta}>
                        <Chip style={styles.freqChip} textStyle={styles.freqChipText}>
                          {FREQ_LABELS[exp.frequency]}
                        </Chip>
                        <Text style={[styles.dueText, { color: isUrgent ? colors.expense : colors.text.muted }]}>
                          {daysLeft <= 0 ? 'Vencido' : daysLeft === 0 ? 'Hoy' : `${daysLeft}d`}
                        </Text>
                      </View>
                    </View>
                    <View style={styles.expRight}>
                      <Text style={styles.expAmount}>{formatCurrency(exp.amount)}</Text>
                      <Button
                        mode="text" compact onPress={() => markPaid(exp.id)}
                        textColor={colors.income} style={styles.paidBtn}
                      >
                        Pagado
                      </Button>
                    </View>
                  </View>
                  {idx < expenses.length - 1 && <Divider style={styles.divider} />}
                </React.Fragment>
              );
            })}
          </Surface>
        )}
        <View style={{ height: 100 }} />
      </ScrollView>

      <Portal>
        <Modal visible={modalVisible} onDismiss={() => setModalVisible(false)} contentContainerStyle={styles.modal}>
          <Text style={styles.modalTitle}>Nuevo gasto fijo</Text>
          <TextInput mode="outlined" label="Nombre" value={newName} onChangeText={setNewName} placeholder="Ej: Alquiler" style={styles.modalInput} autoFocus />
          <TextInput mode="outlined" label="Monto" value={newAmount} onChangeText={setNewAmount} keyboardType="numeric" left={<TextInput.Affix text="$" />} style={styles.modalInput} />
          <TextInput mode="outlined" label="Día de vencimiento" value={newDueDay} onChangeText={setNewDueDay} keyboardType="numeric" style={styles.modalInput} />
          <Text style={styles.freqLabel}>Frecuencia</Text>
          <View style={styles.freqRow}>
            {(['monthly', 'weekly', 'annual'] as const).map(f => (
              <Pressable key={f} onPress={() => setNewFreq(f)}
                style={[styles.freqBtn, newFreq === f && { backgroundColor: colors.brand.muted, borderColor: colors.brand.primary }]}>
                <Text style={[styles.freqBtnText, newFreq === f && { color: colors.brand.primary }]}>{FREQ_LABELS[f]}</Text>
              </Pressable>
            ))}
          </View>
          <View style={styles.modalActions}>
            <Button mode="text" onPress={() => setModalVisible(false)} textColor={colors.text.muted}>Cancelar</Button>
            <Button mode="contained" onPress={handleCreate} style={{ backgroundColor: colors.brand.primary }}>Agregar</Button>
          </View>
        </Modal>
      </Portal>

      <FAB icon="plus" style={styles.fab} color="#FFFFFF" onPress={() => setModalVisible(true)} />
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg.primary },
  header: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    paddingTop: 56, paddingHorizontal: spacing.base, paddingBottom: spacing.base,
  },
  backBtn: { width: 40, height: 40, justifyContent: 'center', alignItems: 'center' },
  title: { fontSize: typography.size.md, fontWeight: typography.weight.bold, color: colors.text.primary },
  content: { padding: spacing.base, gap: spacing.md },
  totalCard: {
    borderRadius: radius.lg, padding: spacing.base, backgroundColor: colors.bg.card, gap: 4,
  },
  totalLabel: { fontSize: typography.size.xs, color: colors.text.muted, textTransform: 'uppercase' },
  totalAmount: { fontSize: typography.size.xl, fontWeight: typography.weight.bold, color: colors.expense },
  emptyCard: {
    borderRadius: radius.xl, padding: spacing['3xl'], backgroundColor: colors.bg.card, alignItems: 'center', gap: spacing.sm,
  },
  emptyTitle: { fontSize: typography.size.lg, fontWeight: typography.weight.semibold, color: colors.text.secondary },
  emptyText: { fontSize: typography.size.sm, color: colors.text.muted, textAlign: 'center' },
  listCard: { borderRadius: radius.xl, overflow: 'hidden', backgroundColor: colors.bg.card },
  expRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.base },
  expIcon: { width: 40, height: 40, borderRadius: radius.md, justifyContent: 'center', alignItems: 'center' },
  expInfo: { flex: 1, gap: 4 },
  expName: { fontSize: typography.size.base, fontWeight: typography.weight.medium, color: colors.text.primary },
  expMeta: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  freqChip: { height: 22, backgroundColor: colors.bg.elevated },
  freqChipText: { fontSize: 10, color: colors.text.muted },
  dueText: { fontSize: typography.size.xs, fontWeight: typography.weight.semibold },
  expRight: { alignItems: 'flex-end' },
  expAmount: { fontSize: typography.size.md, fontWeight: typography.weight.semibold, color: colors.text.primary },
  paidBtn: { marginTop: 2 },
  divider: { marginHorizontal: spacing.base, backgroundColor: colors.border.subtle },
  fab: { position: 'absolute', right: spacing.base, bottom: spacing['2xl'], backgroundColor: colors.brand.primary },
  modal: { margin: spacing.base, padding: spacing.xl, borderRadius: radius.xl, backgroundColor: colors.bg.card, gap: spacing.md },
  modalTitle: { fontSize: typography.size.lg, fontWeight: typography.weight.bold, color: colors.text.primary },
  modalInput: { backgroundColor: colors.bg.input },
  freqLabel: { fontSize: typography.size.sm, color: colors.text.secondary },
  freqRow: { flexDirection: 'row', gap: spacing.sm },
  freqBtn: {
    flex: 1, paddingVertical: spacing.sm, borderRadius: radius.md,
    backgroundColor: colors.bg.elevated, borderWidth: 1, borderColor: colors.border.default, alignItems: 'center',
  },
  freqBtnText: { fontSize: typography.size.xs, color: colors.text.secondary, fontWeight: typography.weight.medium },
  modalActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm },
});
