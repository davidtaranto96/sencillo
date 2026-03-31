import React, { useState, useRef } from 'react';
import { View, StyleSheet, Animated } from 'react-native';
import { TextInput, Button, Surface, Text, Chip, ActivityIndicator, IconButton } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { parseExpenseText, ParsedExpense } from '@/src/lib/expenseParser';
import { classifyWithAI } from '@/src/services/aiClassifier';
import { colors, spacing, radius } from '@/src/lib/theme';
import { formatCurrency } from '@/src/lib/utils';

type TransactionTypeLabel = {
  label: string;
  color: string;
  icon: string;
};

const TYPE_LABELS: Record<string, TransactionTypeLabel> = {
  expense: { label: 'Gasto', color: colors.expense, icon: 'arrow-down-circle' },
  income: { label: 'Ingreso', color: colors.income, icon: 'arrow-up-circle' },
  loan_given: { label: 'Presté', color: colors.warning, icon: 'hand-coin' },
  loan_received: { label: 'Me prestaron', color: colors.saving, icon: 'hand-coin-outline' },
  saving: { label: 'Ahorro', color: colors.saving, icon: 'piggy-bank' },
};

interface Props {
  onConfirm: (result: ParsedExpense) => void;
  onCancel?: () => void;
  defaultAccountId?: string;
}

export function SmartExpenseInput({ onConfirm, onCancel }: Props) {
  const [text, setText] = useState('');
  const [result, setResult] = useState<ParsedExpense | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [editAmount, setEditAmount] = useState('');
  const [editDescription, setEditDescription] = useState('');
  const fadeAnim = useRef(new Animated.Value(0)).current;

  const PLACEHOLDERS = [
    'Ej: "gasté 500 en pizza"',
    'Ej: "taxi 1200 con tarjeta"',
    'Ej: "le presté 3000 a Juan"',
    'Ej: "cobré el sueldo 150000"',
    'Ej: "supermercado 8500"',
  ];
  const [placeholder] = useState(PLACEHOLDERS[Math.floor(Math.random() * PLACEHOLDERS.length)]);

  async function handleProcess() {
    if (!text.trim()) return;
    setIsProcessing(true);
    setResult(null);

    // Try local parser first
    const local = parseExpenseText(text);

    let final = local;
    if (local.confidence < 70 && process.env.EXPO_PUBLIC_ANTHROPIC_API_KEY) {
      const ai = await classifyWithAI(text);
      if (ai) final = ai;
    }

    setResult(final);
    setEditAmount(final.amount ? String(final.amount) : '');
    setEditDescription(final.description);
    setIsProcessing(false);

    Animated.spring(fadeAnim, { toValue: 1, useNativeDriver: true }).start();
  }

  function handleConfirm() {
    if (!result) return;
    const amount = parseFloat(editAmount);
    if (isNaN(amount) || amount <= 0) return;
    onConfirm({
      ...result,
      amount,
      description: editDescription,
    });
  }

  function handleReset() {
    setResult(null);
    setText('');
    setEditAmount('');
    setEditDescription('');
    fadeAnim.setValue(0);
  }

  const typeInfo = result ? TYPE_LABELS[result.transactionType] ?? TYPE_LABELS.expense : null;

  return (
    <View style={styles.container}>
      {/* Input Row */}
      <View style={styles.inputRow}>
        <TextInput
          mode="outlined"
          value={text}
          onChangeText={setText}
          placeholder={placeholder}
          style={styles.input}
          right={
            isProcessing
              ? <TextInput.Icon icon={() => <ActivityIndicator size={18} color={colors.brand.primary} />} />
              : text.length > 0
              ? <TextInput.Icon icon="send" onPress={handleProcess} />
              : undefined
          }
          onSubmitEditing={handleProcess}
          returnKeyType="send"
          multiline={false}
          editable={!isProcessing}
        />
      </View>

      {/* Hint */}
      {!result && !isProcessing && (
        <View style={styles.hintRow}>
          <MaterialCommunityIcons name="creation" size={14} color={colors.brand.light} />
          <Text style={styles.hintText}>
            Escribí en lenguaje natural — la IA clasifica automáticamente
          </Text>
        </View>
      )}

      {/* Result Preview */}
      {result && (
        <Animated.View style={[styles.resultCard, { opacity: fadeAnim }]}>
          <Surface style={styles.surface} elevation={2}>
            {/* Type badge + confidence */}
            <View style={styles.resultHeader}>
              <Chip
                icon={typeInfo?.icon}
                style={[styles.typeChip, { backgroundColor: typeInfo?.color + '22' }]}
                textStyle={{ color: typeInfo?.color, fontWeight: '600' }}
              >
                {typeInfo?.label}
              </Chip>
              {result.categoryName && (
                <Chip
                  style={styles.categoryChip}
                  textStyle={{ color: colors.text.secondary, fontSize: 12 }}
                >
                  {result.categoryName}
                </Chip>
              )}
              {result.confidence >= 70 ? (
                <MaterialCommunityIcons name="check-circle" size={16} color={colors.income} style={styles.confidenceIcon} />
              ) : (
                <MaterialCommunityIcons name="creation" size={16} color={colors.brand.light} style={styles.confidenceIcon} />
              )}
            </View>

            {/* Editable Amount */}
            <TextInput
              mode="outlined"
              label="Monto"
              value={editAmount}
              onChangeText={setEditAmount}
              keyboardType="numeric"
              left={<TextInput.Affix text="$" />}
              style={styles.amountInput}
              dense
            />

            {/* Editable Description */}
            <TextInput
              mode="outlined"
              label="Descripción"
              value={editDescription}
              onChangeText={setEditDescription}
              style={styles.descInput}
              dense
            />

            {/* Person */}
            {result.person && (
              <View style={styles.personRow}>
                <MaterialCommunityIcons name="account" size={16} color={colors.text.secondary} />
                <Text style={styles.personText}>{result.person}</Text>
              </View>
            )}

            {/* Actions */}
            <View style={styles.actions}>
              <Button mode="text" onPress={handleReset} textColor={colors.text.muted}>
                Limpiar
              </Button>
              <Button
                mode="contained"
                onPress={handleConfirm}
                disabled={!editAmount || parseFloat(editAmount) <= 0}
                style={styles.confirmBtn}
              >
                Confirmar
              </Button>
            </View>
          </Surface>
        </Animated.View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: spacing.sm,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  input: {
    flex: 1,
    backgroundColor: colors.bg.input,
  },
  hintRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.xs,
  },
  hintText: {
    fontSize: 12,
    color: colors.text.muted,
    flex: 1,
  },
  resultCard: {
    marginTop: spacing.xs,
  },
  surface: {
    borderRadius: radius.lg,
    padding: spacing.base,
    backgroundColor: colors.bg.card,
    gap: spacing.sm,
  },
  resultHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: spacing.xs,
    marginBottom: spacing.xs,
  },
  typeChip: {
    height: 28,
  },
  categoryChip: {
    height: 28,
    backgroundColor: colors.bg.elevated,
  },
  confidenceIcon: {
    marginLeft: 'auto',
  },
  amountInput: {
    backgroundColor: colors.bg.input,
  },
  descInput: {
    backgroundColor: colors.bg.input,
  },
  personRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  personText: {
    fontSize: 13,
    color: colors.text.secondary,
  },
  actions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    alignItems: 'center',
    gap: spacing.sm,
    marginTop: spacing.xs,
  },
  confirmBtn: {
    borderRadius: radius.md,
  },
});
