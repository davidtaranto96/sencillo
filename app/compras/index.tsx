import React, { useEffect, useState } from 'react';
import { View, ScrollView, StyleSheet, Pressable } from 'react-native';
import { Text, Surface, FAB, Portal, Modal, Button, TextInput, Chip, Divider } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import * as SQLite from 'expo-sqlite';
import { generateId, formatCurrency } from '@/src/lib/utils';
import { WishlistItem } from '@/src/lib/types';
import { colors, spacing, radius, typography } from '@/src/lib/theme';

function getDb() { return SQLite.openDatabaseSync('finanzas.db'); }

function loadItems(): WishlistItem[] {
  return getDb().getAllSync<any>(
    "SELECT * FROM wishlist_items WHERE status = 'pending' ORDER BY created_at DESC", []
  ).map((r: any) => ({
    id: r.id, name: r.name, price: r.price, link: r.link, imageUri: r.image_uri,
    isNeed: Boolean(r.is_need), reminderDays: r.reminder_days,
    reminderDate: r.reminder_date, status: r.status, goalId: r.goal_id, createdAt: r.created_at,
  }));
}

function daysSince(dateStr: string): number {
  const diff = Date.now() - new Date(dateStr).getTime();
  return Math.floor(diff / (1000 * 60 * 60 * 24));
}

export default function ComprasScreen() {
  const [items, setItems] = useState<WishlistItem[]>([]);
  const [modalVisible, setModalVisible] = useState(false);
  const [newName, setNewName] = useState('');
  const [newPrice, setNewPrice] = useState('');
  const [isNeed, setIsNeed] = useState(false);
  const [reminderDays, setReminderDays] = useState(7);

  useEffect(() => { setItems(loadItems()); }, []);

  function refresh() { setItems(loadItems()); }

  function handleCreate() {
    const price = parseFloat(newPrice);
    if (!newName.trim() || isNaN(price)) return;
    const db = getDb();
    const id = generateId();
    const createdAt = new Date().toISOString();
    const reminderDate = new Date(Date.now() + reminderDays * 86400000).toISOString();
    db.runSync(
      'INSERT INTO wishlist_items (id, name, price, is_need, reminder_days, reminder_date, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [id, newName.trim(), price, isNeed ? 1 : 0, reminderDays, reminderDate, 'pending', createdAt]
    );
    setNewName(''); setNewPrice('');
    setModalVisible(false);
    refresh();
  }

  function handlePurchase(id: string) {
    getDb().runSync("UPDATE wishlist_items SET status = 'purchased' WHERE id = ?", [id]);
    refresh();
  }

  function handleDiscard(id: string) {
    getDb().runSync("UPDATE wishlist_items SET status = 'discarded' WHERE id = ?", [id]);
    refresh();
  }

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backBtn}>
          <MaterialCommunityIcons name="arrow-left" size={24} color={colors.text.secondary} />
        </Pressable>
        <Text style={styles.title}>Compras inteligentes</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Explanation */}
        <Surface style={styles.infoCard} elevation={1}>
          <MaterialCommunityIcons name="lightbulb-on" size={20} color={colors.transfer} />
          <Text style={styles.infoText}>
            Guardá lo que querés comprar y esperá antes de decidir. Si después de X días todavía lo querés, compralo.
          </Text>
        </Surface>

        {items.length === 0 ? (
          <Surface style={styles.emptyCard} elevation={1}>
            <MaterialCommunityIcons name="cart-heart" size={48} color={colors.text.muted} />
            <Text style={styles.emptyTitle}>Sin items</Text>
            <Text style={styles.emptyText}>Guardá lo que querés comprar antes de decidir</Text>
          </Surface>
        ) : (
          items.map((item) => {
            const waited = daysSince(item.createdAt);
            const canBuy = waited >= item.reminderDays;
            return (
              <Surface key={item.id} style={styles.itemCard} elevation={2}>
                <View style={styles.itemHeader}>
                  <View style={styles.itemTitleRow}>
                    <Text style={styles.itemName}>{item.name}</Text>
                    <Chip
                      style={[styles.needChip, { backgroundColor: item.isNeed ? colors.income + '22' : colors.warning + '22' }]}
                      textStyle={{ color: item.isNeed ? colors.income : colors.warning, fontSize: 11 }}
                    >
                      {item.isNeed ? 'Necesidad' : 'Deseo'}
                    </Chip>
                  </View>
                  <Text style={styles.itemPrice}>{formatCurrency(item.price)}</Text>
                </View>

                <View style={styles.waitRow}>
                  <MaterialCommunityIcons
                    name="clock-outline"
                    size={16}
                    color={canBuy ? colors.income : colors.warning}
                  />
                  <Text style={[styles.waitText, { color: canBuy ? colors.income : colors.warning }]}>
                    {canBuy
                      ? `¡Esperaste ${waited} días! ¿Todavía lo querés?`
                      : `Esperaste ${waited} de ${item.reminderDays} días`}
                  </Text>
                </View>

                <View style={styles.itemActions}>
                  <Button
                    mode="text"
                    textColor={colors.expense}
                    onPress={() => handleDiscard(item.id)}
                    compact
                  >
                    Descartar
                  </Button>
                  <Button
                    mode={canBuy ? 'contained' : 'outlined'}
                    onPress={() => handlePurchase(item.id)}
                    style={canBuy ? { backgroundColor: colors.income } : {}}
                    compact
                  >
                    Comprar
                  </Button>
                </View>
              </Surface>
            );
          })
        )}
        <View style={{ height: 100 }} />
      </ScrollView>

      <Portal>
        <Modal visible={modalVisible} onDismiss={() => setModalVisible(false)} contentContainerStyle={styles.modal}>
          <Text style={styles.modalTitle}>Guardar compra</Text>
          <TextInput mode="outlined" label="¿Qué querés comprar?" value={newName} onChangeText={setNewName} style={styles.modalInput} autoFocus />
          <TextInput
            mode="outlined" label="Precio" value={newPrice} onChangeText={setNewPrice}
            keyboardType="numeric" left={<TextInput.Affix text="$" />} style={styles.modalInput}
          />
          <View style={styles.switchRow}>
            <Pressable onPress={() => setIsNeed(!isNeed)} style={styles.switchOption}>
              <MaterialCommunityIcons
                name={isNeed ? 'checkbox-marked' : 'checkbox-blank-outline'}
                size={22} color={isNeed ? colors.income : colors.text.muted}
              />
              <Text style={{ color: colors.text.secondary }}>Es una necesidad</Text>
            </Pressable>
          </View>
          <Text style={styles.reminderLabel}>Esperá antes de comprar:</Text>
          <View style={styles.reminderOptions}>
            {[7, 15, 30].map((d) => (
              <Pressable key={d} onPress={() => setReminderDays(d)}
                style={[styles.reminderBtn, reminderDays === d && { backgroundColor: colors.brand.muted, borderColor: colors.brand.primary }]}>
                <Text style={[styles.reminderBtnText, reminderDays === d && { color: colors.brand.primary }]}>{d} días</Text>
              </Pressable>
            ))}
          </View>
          <View style={styles.modalActions}>
            <Button mode="text" onPress={() => setModalVisible(false)} textColor={colors.text.muted}>Cancelar</Button>
            <Button mode="contained" onPress={handleCreate} style={{ backgroundColor: colors.brand.primary }}>Guardar</Button>
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
  infoCard: {
    borderRadius: radius.lg, padding: spacing.base, backgroundColor: colors.bg.card,
    flexDirection: 'row', gap: spacing.sm, alignItems: 'flex-start',
  },
  infoText: { flex: 1, fontSize: typography.size.sm, color: colors.text.secondary, lineHeight: 20 },
  emptyCard: {
    borderRadius: radius.xl, padding: spacing['3xl'],
    backgroundColor: colors.bg.card, alignItems: 'center', gap: spacing.sm,
  },
  emptyTitle: { fontSize: typography.size.lg, fontWeight: typography.weight.semibold, color: colors.text.secondary },
  emptyText: { fontSize: typography.size.sm, color: colors.text.muted, textAlign: 'center' },
  itemCard: { borderRadius: radius.xl, padding: spacing.base, backgroundColor: colors.bg.card, gap: spacing.sm },
  itemHeader: { gap: 4 },
  itemTitleRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  itemName: { fontSize: typography.size.md, fontWeight: typography.weight.semibold, color: colors.text.primary, flex: 1 },
  needChip: { height: 24 },
  itemPrice: { fontSize: typography.size.xl, fontWeight: typography.weight.bold, color: colors.text.primary },
  waitRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  waitText: { fontSize: typography.size.sm, flex: 1 },
  itemActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm },
  fab: { position: 'absolute', right: spacing.base, bottom: spacing['2xl'], backgroundColor: colors.brand.primary },
  modal: { margin: spacing.base, padding: spacing.xl, borderRadius: radius.xl, backgroundColor: colors.bg.card, gap: spacing.md },
  modalTitle: { fontSize: typography.size.lg, fontWeight: typography.weight.bold, color: colors.text.primary },
  modalInput: { backgroundColor: colors.bg.input },
  switchRow: { flexDirection: 'row' },
  switchOption: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  reminderLabel: { fontSize: typography.size.sm, color: colors.text.secondary },
  reminderOptions: { flexDirection: 'row', gap: spacing.sm },
  reminderBtn: {
    flex: 1, paddingVertical: spacing.sm, borderRadius: radius.md,
    backgroundColor: colors.bg.elevated, borderWidth: 1, borderColor: colors.border.default,
    alignItems: 'center',
  },
  reminderBtnText: { fontSize: typography.size.sm, color: colors.text.secondary, fontWeight: typography.weight.medium },
  modalActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm },
});
