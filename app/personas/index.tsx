import React, { useEffect, useState } from 'react';
import { View, ScrollView, StyleSheet, Pressable } from 'react-native';
import { Text, Surface, FAB, Portal, Modal, Button, TextInput, Divider } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import * as SQLite from 'expo-sqlite';
import { generateId, getInitials, formatCurrency } from '@/src/lib/utils';
import { Person, DebtRecord } from '@/src/lib/types';
import { colors, spacing, radius, typography } from '@/src/lib/theme';

const PERSON_COLORS = ['#6C63FF', '#34D399', '#60A5FA', '#A78BFA', '#FBBF24', '#F472B6', '#FB923C'];

function getDb() { return SQLite.openDatabaseSync('finanzas.db'); }

function loadPersons(): Person[] {
  return getDb().getAllSync<any>('SELECT * FROM persons ORDER BY name ASC', []).map((r: any) => ({
    id: r.id, name: r.name, avatar: r.avatar, phone: r.phone, color: r.color,
  }));
}

function loadDebts(): DebtRecord[] {
  return getDb().getAllSync<any>('SELECT * FROM debt_records WHERE is_paid = 0 ORDER BY created_at DESC', []).map((r: any) => ({
    id: r.id, personId: r.person_id, amount: r.amount, direction: r.direction,
    description: r.description, dueDate: r.due_date, isPaid: Boolean(r.is_paid), createdAt: r.created_at,
  }));
}

export default function PersonasScreen() {
  const [persons, setPersons] = useState<Person[]>([]);
  const [debts, setDebts] = useState<DebtRecord[]>([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [newName, setNewName] = useState('');
  const [newPhone, setNewPhone] = useState('');
  const [selectedColor, setSelectedColor] = useState(PERSON_COLORS[0]);

  useEffect(() => {
    setPersons(loadPersons());
    setDebts(loadDebts());
  }, []);

  function refresh() {
    setPersons(loadPersons());
    setDebts(loadDebts());
  }

  function handleCreate() {
    if (!newName.trim()) return;
    const db = getDb();
    const id = generateId();
    db.runSync('INSERT INTO persons (id, name, phone, color) VALUES (?, ?, ?, ?)',
      [id, newName.trim(), newPhone.trim() || null, selectedColor]);
    setNewName(''); setNewPhone('');
    setModalVisible(false);
    refresh();
  }

  // Group debts by person
  const debtsByPerson = new Map<string, { owesMe: number; iOwe: number }>();
  for (const debt of debts) {
    const curr = debtsByPerson.get(debt.personId) ?? { owesMe: 0, iOwe: 0 };
    if (debt.direction === 'owe_me') curr.owesMe += debt.amount;
    else curr.iOwe += debt.amount;
    debtsByPerson.set(debt.personId, curr);
  }

  const totalOwesMe = debts.filter(d => d.direction === 'owe_me').reduce((s, d) => s + d.amount, 0);
  const totalIOwe = debts.filter(d => d.direction === 'i_owe').reduce((s, d) => s + d.amount, 0);

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backBtn}>
          <MaterialCommunityIcons name="arrow-left" size={24} color={colors.text.secondary} />
        </Pressable>
        <Text style={styles.title}>Personas y deudas</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Summary */}
        {debts.length > 0 && (
          <View style={styles.summaryRow}>
            <Surface style={[styles.summaryCard, { borderTopColor: colors.income }]} elevation={2}>
              <Text style={styles.summaryLabel}>Te deben</Text>
              <Text style={[styles.summaryAmount, { color: colors.income }]}>
                {formatCurrency(totalOwesMe)}
              </Text>
            </Surface>
            <Surface style={[styles.summaryCard, { borderTopColor: colors.expense }]} elevation={2}>
              <Text style={styles.summaryLabel}>Debés</Text>
              <Text style={[styles.summaryAmount, { color: colors.expense }]}>
                {formatCurrency(totalIOwe)}
              </Text>
            </Surface>
          </View>
        )}

        {/* Persons list */}
        <Text style={styles.sectionTitle}>Personas</Text>
        {persons.length === 0 ? (
          <Surface style={styles.emptyCard} elevation={1}>
            <MaterialCommunityIcons name="account-group-outline" size={40} color={colors.text.muted} />
            <Text style={styles.emptyText}>Agregá personas para llevar un registro</Text>
          </Surface>
        ) : (
          <Surface style={styles.listCard} elevation={1}>
            {persons.map((person, idx) => {
              const debtInfo = debtsByPerson.get(person.id);
              return (
                <React.Fragment key={person.id}>
                  <View style={styles.personRow}>
                    <View style={[styles.avatar, { backgroundColor: person.color + '33' }]}>
                      <Text style={[styles.avatarText, { color: person.color }]}>
                        {getInitials(person.name)}
                      </Text>
                    </View>
                    <View style={styles.personInfo}>
                      <Text style={styles.personName}>{person.name}</Text>
                      {debtInfo && (
                        <Text style={styles.personDebt}>
                          {debtInfo.owesMe > 0 && `Te debe ${formatCurrency(debtInfo.owesMe)}`}
                          {debtInfo.iOwe > 0 && `Le debés ${formatCurrency(debtInfo.iOwe)}`}
                        </Text>
                      )}
                    </View>
                  </View>
                  {idx < persons.length - 1 && <Divider style={styles.divider} />}
                </React.Fragment>
              );
            })}
          </Surface>
        )}
        <View style={{ height: 100 }} />
      </ScrollView>

      <Portal>
        <Modal visible={modalVisible} onDismiss={() => setModalVisible(false)} contentContainerStyle={styles.modal}>
          <Text style={styles.modalTitle}>Nueva persona</Text>
          <TextInput mode="outlined" label="Nombre" value={newName} onChangeText={setNewName} style={styles.modalInput} autoFocus />
          <TextInput mode="outlined" label="Teléfono (opcional)" value={newPhone} onChangeText={setNewPhone} keyboardType="phone-pad" style={styles.modalInput} />
          <Text style={styles.colorLabel}>Color</Text>
          <View style={styles.colorPicker}>
            {PERSON_COLORS.map(c => (
              <Pressable key={c} onPress={() => setSelectedColor(c)}
                style={[styles.colorDot, { backgroundColor: c }, selectedColor === c && styles.colorDotSel]} />
            ))}
          </View>
          <View style={styles.modalActions}>
            <Button mode="text" onPress={() => setModalVisible(false)} textColor={colors.text.muted}>Cancelar</Button>
            <Button mode="contained" onPress={handleCreate} style={{ backgroundColor: selectedColor }}>Agregar</Button>
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
  title: { fontSize: typography.size.lg, fontWeight: typography.weight.bold, color: colors.text.primary },
  content: { padding: spacing.base, gap: spacing.md },
  summaryRow: { flexDirection: 'row', gap: spacing.md },
  summaryCard: {
    flex: 1, borderRadius: radius.lg, padding: spacing.base,
    backgroundColor: colors.bg.card, gap: 4, borderTopWidth: 3,
  },
  summaryLabel: { fontSize: typography.size.xs, color: colors.text.muted, textTransform: 'uppercase' },
  summaryAmount: { fontSize: typography.size.xl, fontWeight: typography.weight.bold },
  sectionTitle: { fontSize: typography.size.base, fontWeight: typography.weight.semibold, color: colors.text.primary },
  listCard: { borderRadius: radius.xl, overflow: 'hidden', backgroundColor: colors.bg.card },
  personRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.base },
  avatar: { width: 44, height: 44, borderRadius: radius.full, justifyContent: 'center', alignItems: 'center' },
  avatarText: { fontSize: typography.size.md, fontWeight: typography.weight.bold },
  personInfo: { flex: 1 },
  personName: { fontSize: typography.size.base, fontWeight: typography.weight.medium, color: colors.text.primary },
  personDebt: { fontSize: typography.size.xs, color: colors.text.secondary, marginTop: 2 },
  divider: { marginHorizontal: spacing.base, backgroundColor: colors.border.subtle },
  emptyCard: {
    borderRadius: radius.xl, padding: spacing['2xl'],
    backgroundColor: colors.bg.card, alignItems: 'center', gap: spacing.sm,
  },
  emptyText: { fontSize: typography.size.sm, color: colors.text.muted, textAlign: 'center' },
  fab: { position: 'absolute', right: spacing.base, bottom: spacing['2xl'], backgroundColor: colors.brand.primary },
  modal: {
    margin: spacing.base, padding: spacing.xl, borderRadius: radius.xl,
    backgroundColor: colors.bg.card, gap: spacing.md,
  },
  modalTitle: { fontSize: typography.size.lg, fontWeight: typography.weight.bold, color: colors.text.primary },
  modalInput: { backgroundColor: colors.bg.input },
  colorLabel: { fontSize: typography.size.sm, color: colors.text.secondary },
  colorPicker: { flexDirection: 'row', gap: spacing.sm },
  colorDot: { width: 32, height: 32, borderRadius: radius.full },
  colorDotSel: { borderWidth: 3, borderColor: '#FFFFFF' },
  modalActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm },
});
