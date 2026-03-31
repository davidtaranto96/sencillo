import React, { useEffect, useState } from 'react';
import { View, ScrollView, StyleSheet, Pressable } from 'react-native';
import {
  Text, Surface, Button, TextInput, SegmentedButtons, Divider,
  Menu, TouchableRipple,
} from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { SmartExpenseInput } from '@/src/components/SmartExpenseInput';
import { ParsedExpense } from '@/src/lib/expenseParser';
import { useAccountStore } from '@/src/stores/accountStore';
import { useCategoryStore } from '@/src/stores/categoryStore';
import { useTransactionStore } from '@/src/stores/transactionStore';
import { Transaction, TransactionType } from '@/src/lib/types';
import { colors, spacing, radius, typography } from '@/src/lib/theme';
import { formatCurrency } from '@/src/lib/utils';

type Mode = 'smart' | 'manual';

const TYPE_OPTIONS = [
  { value: 'expense', label: 'Gasto' },
  { value: 'income', label: 'Ingreso' },
  { value: 'transfer', label: 'Transferencia' },
  { value: 'saving', label: 'Ahorro' },
];

export default function NewTransactionScreen() {
  const params = useLocalSearchParams<{ type?: string }>();
  const { accounts, load: loadAccounts } = useAccountStore();
  const { categories, load: loadCategories } = useCategoryStore();
  const { create: createTransaction, load: loadTransactions } = useTransactionStore();

  const [mode, setMode] = useState<Mode>('smart');
  const [txType, setTxType] = useState<TransactionType>((params.type as TransactionType) ?? 'expense');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [selectedCategoryId, setSelectedCategoryId] = useState('');
  const [selectedAccountId, setSelectedAccountId] = useState('');
  const [categoryMenuVisible, setCategoryMenuVisible] = useState(false);
  const [accountMenuVisible, setAccountMenuVisible] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadAccounts();
    loadCategories();
    if (accounts.length > 0) setSelectedAccountId(accounts[0].id);
  }, []);

  useEffect(() => {
    if (accounts.length > 0 && !selectedAccountId) {
      setSelectedAccountId(accounts[0].id);
    }
  }, [accounts]);

  const relevantCategories = categories.filter((c) => {
    if (txType === 'income') return c.type === 'income' || c.type === 'both';
    return c.type === 'expense' || c.type === 'both';
  });

  function handleSmartConfirm(parsed: ParsedExpense) {
    setAmount(String(parsed.amount ?? ''));
    setDescription(parsed.description);
    setTxType(parsed.transactionType);
    if (parsed.categoryId) setSelectedCategoryId(parsed.categoryId);
    setMode('manual'); // Switch to manual to let user confirm/adjust
  }

  async function handleSave() {
    const numAmount = parseFloat(amount);
    if (isNaN(numAmount) || numAmount <= 0) return;
    if (!selectedAccountId) return;

    const catId = selectedCategoryId || (txType === 'income' ? 'cat-otros-ingreso' : 'cat-otros-gasto');

    setSaving(true);
    try {
      createTransaction({
        type: txType,
        amount: numAmount,
        date: new Date().toISOString().split('T')[0],
        categoryId: catId,
        accountId: selectedAccountId,
        description: description || undefined,
        isFixed: false,
        isShared: false,
      });
      loadTransactions();
      loadAccounts();
      router.back();
    } finally {
      setSaving(false);
    }
  }

  const selectedCategory = categories.find((c) => c.id === selectedCategoryId);
  const selectedAccount = accounts.find((a) => a.id === selectedAccountId);

  return (
    <View style={styles.root}>
      {/* Header */}
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.closeBtn}>
          <MaterialCommunityIcons name="close" size={24} color={colors.text.secondary} />
        </Pressable>
        <Text style={styles.headerTitle}>Nuevo movimiento</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        {/* Mode Toggle */}
        <SegmentedButtons
          value={mode}
          onValueChange={(v) => setMode(v as Mode)}
          buttons={[
            { value: 'smart', label: '✨ Inteligente', icon: 'creation' },
            { value: 'manual', label: 'Manual', icon: 'pencil' },
          ]}
          style={styles.modeToggle}
        />

        {mode === 'smart' ? (
          <View style={styles.smartSection}>
            <Text style={styles.smartHint}>
              Escribí lo que gastaste en lenguaje natural
            </Text>
            <SmartExpenseInput
              onConfirm={handleSmartConfirm}
              onCancel={() => router.back()}
            />
          </View>
        ) : (
          <View style={styles.manualSection}>
            {/* Transaction Type */}
            <Text style={styles.fieldLabel}>Tipo</Text>
            <SegmentedButtons
              value={txType}
              onValueChange={(v) => setTxType(v as TransactionType)}
              buttons={TYPE_OPTIONS}
              style={styles.typeButtons}
            />

            {/* Amount */}
            <Text style={styles.fieldLabel}>Monto</Text>
            <TextInput
              mode="outlined"
              value={amount}
              onChangeText={setAmount}
              keyboardType="numeric"
              left={<TextInput.Affix text="$" />}
              placeholder="0"
              style={styles.input}
            />

            {/* Description */}
            <Text style={styles.fieldLabel}>Descripción</Text>
            <TextInput
              mode="outlined"
              value={description}
              onChangeText={setDescription}
              placeholder="Ej: Pizza con amigos"
              style={styles.input}
            />

            {/* Category */}
            <Text style={styles.fieldLabel}>Categoría</Text>
            <Menu
              visible={categoryMenuVisible}
              onDismiss={() => setCategoryMenuVisible(false)}
              anchor={
                <Pressable
                  onPress={() => setCategoryMenuVisible(true)}
                  style={styles.pickerButton}
                >
                  <Surface style={styles.pickerSurface} elevation={1}>
                    {selectedCategory ? (
                      <View style={styles.pickerContent}>
                        <View style={[styles.catDot, { backgroundColor: selectedCategory.color }]} />
                        <Text style={styles.pickerText}>{selectedCategory.name}</Text>
                      </View>
                    ) : (
                      <Text style={styles.pickerPlaceholder}>Seleccionar categoría...</Text>
                    )}
                    <MaterialCommunityIcons name="chevron-down" size={20} color={colors.text.muted} />
                  </Surface>
                </Pressable>
              }
            >
              <ScrollView style={{ maxHeight: 300 }}>
                {relevantCategories.map((cat) => (
                  <Menu.Item
                    key={cat.id}
                    leadingIcon={cat.icon as any}
                    title={cat.name}
                    onPress={() => {
                      setSelectedCategoryId(cat.id);
                      setCategoryMenuVisible(false);
                    }}
                  />
                ))}
              </ScrollView>
            </Menu>

            {/* Account */}
            <Text style={styles.fieldLabel}>Cuenta</Text>
            <Menu
              visible={accountMenuVisible}
              onDismiss={() => setAccountMenuVisible(false)}
              anchor={
                <Pressable
                  onPress={() => setAccountMenuVisible(true)}
                  style={styles.pickerButton}
                >
                  <Surface style={styles.pickerSurface} elevation={1}>
                    {selectedAccount ? (
                      <View style={styles.pickerContent}>
                        <View style={[styles.catDot, { backgroundColor: selectedAccount.color }]} />
                        <Text style={styles.pickerText}>{selectedAccount.name}</Text>
                        <Text style={styles.pickerBalance}>
                          {formatCurrency(selectedAccount.balance)}
                        </Text>
                      </View>
                    ) : (
                      <Text style={styles.pickerPlaceholder}>Seleccionar cuenta...</Text>
                    )}
                    <MaterialCommunityIcons name="chevron-down" size={20} color={colors.text.muted} />
                  </Surface>
                </Pressable>
              }
            >
              {accounts.map((acc) => (
                <Menu.Item
                  key={acc.id}
                  leadingIcon={acc.icon as any ?? 'bank'}
                  title={`${acc.name}  ${formatCurrency(acc.balance)}`}
                  onPress={() => {
                    setSelectedAccountId(acc.id);
                    setAccountMenuVisible(false);
                  }}
                />
              ))}
            </Menu>

            {/* Save Button */}
            <Button
              mode="contained"
              onPress={handleSave}
              loading={saving}
              disabled={saving || !amount || !selectedAccountId}
              style={styles.saveBtn}
              contentStyle={styles.saveBtnContent}
            >
              Guardar movimiento
            </Button>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: colors.bg.primary,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: 56,
    paddingHorizontal: spacing.base,
    paddingBottom: spacing.base,
    borderBottomWidth: 1,
    borderBottomColor: colors.border.subtle,
  },
  closeBtn: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: typography.size.md,
    fontWeight: typography.weight.semibold,
    color: colors.text.primary,
  },
  content: {
    padding: spacing.base,
    gap: spacing.md,
  },
  modeToggle: {
    marginBottom: spacing.sm,
  },
  smartSection: {
    gap: spacing.sm,
  },
  smartHint: {
    fontSize: typography.size.sm,
    color: colors.text.secondary,
    textAlign: 'center',
  },
  manualSection: {
    gap: spacing.sm,
  },
  fieldLabel: {
    fontSize: typography.size.sm,
    fontWeight: typography.weight.medium,
    color: colors.text.secondary,
    marginBottom: 2,
  },
  input: {
    backgroundColor: colors.bg.input,
  },
  typeButtons: {
    marginBottom: spacing.xs,
  },
  pickerButton: {
    marginBottom: spacing.xs,
  },
  pickerSurface: {
    borderRadius: radius.md,
    padding: spacing.md,
    backgroundColor: colors.bg.input,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border.default,
  },
  pickerContent: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  pickerText: {
    fontSize: typography.size.base,
    color: colors.text.primary,
    flex: 1,
  },
  pickerBalance: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
  },
  pickerPlaceholder: {
    flex: 1,
    fontSize: typography.size.base,
    color: colors.text.muted,
  },
  catDot: {
    width: 12,
    height: 12,
    borderRadius: radius.full,
  },
  saveBtn: {
    marginTop: spacing.md,
    borderRadius: radius.md,
    backgroundColor: colors.brand.primary,
  },
  saveBtnContent: {
    paddingVertical: spacing.sm,
  },
});
