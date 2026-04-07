import React, { useEffect, useState } from 'react';
import { View, ScrollView, StyleSheet, Pressable, Alert } from 'react-native';
import { Text, Surface, Button, Chip, Divider } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router, useLocalSearchParams } from 'expo-router';
import { useTransactionStore } from '@/src/stores/transactionStore';
import { useCategoryStore } from '@/src/stores/categoryStore';
import { useAccountStore } from '@/src/stores/accountStore';
import { colors, spacing, radius, typography } from '@/src/lib/theme';
import { formatCurrency, formatDate } from '@/src/lib/utils';

const TYPE_CONFIG: Record<string, { color: string; label: string; icon: string }> = {
  income:        { color: colors.income,     label: 'Ingreso',       icon: 'arrow-up-circle' },
  expense:       { color: colors.expense,    label: 'Gasto',         icon: 'arrow-down-circle' },
  transfer:      { color: colors.transfer,   label: 'Transferencia', icon: 'swap-horizontal' },
  saving:        { color: colors.saving,     label: 'Ahorro',        icon: 'piggy-bank' },
  investment:    { color: colors.investment, label: 'Inversión',     icon: 'trending-up' },
  loan_given:    { color: colors.warning,    label: 'Presté',        icon: 'hand-coin' },
  loan_received: { color: colors.saving,     label: 'Me prestaron',  icon: 'hand-coin-outline' },
};

export default function TransactionDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { transactions, delete: deleteTransaction, load } = useTransactionStore();
  const { categories, load: loadCat } = useCategoryStore();
  const { accounts, load: loadAcc } = useAccountStore();

  useEffect(() => {
    load(); loadCat(); loadAcc();
  }, []);

  const transaction = transactions.find((t) => t.id === id);

  if (!transaction) {
    return (
      <View style={[styles.root, styles.center]}>
        <Text style={{ color: colors.text.muted }}>Movimiento no encontrado</Text>
        <Button onPress={() => router.back()}>Volver</Button>
      </View>
    );
  }

  const category = categories.find((c) => c.id === transaction.categoryId);
  const account = accounts.find((a) => a.id === transaction.accountId);
  const typeConf = TYPE_CONFIG[transaction.type] ?? TYPE_CONFIG.expense;

  function handleDelete() {
    const tx = transaction!;
    let message = '¿Estás seguro? Se revertirá el saldo de la cuenta.';
    if (tx.type === 'transfer') {
      message = '¿Estás seguro? Se revertirá el saldo de ambas cuentas (origen y destino).';
    } else if (tx.isShared) {
      message = '¿Estás seguro? Se revertirá el saldo, se eliminará la deuda asociada y los datos del gasto compartido.';
    } else if (tx.goalId) {
      message = '¿Estás seguro? Se revertirá el saldo y la contribución al objetivo.';
    }

    Alert.alert(
      'Eliminar movimiento',
      message,
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Eliminar',
          style: 'destructive',
          onPress: () => {
            deleteTransaction(tx.id);
            router.back();
          },
        },
      ]
    );
  }

  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backBtn}>
          <MaterialCommunityIcons name="arrow-left" size={24} color={colors.text.secondary} />
        </Pressable>
        <Text style={styles.headerTitle}>Detalle</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Amount Card */}
        <Surface style={[styles.amountCard, { borderTopColor: typeConf.color }]} elevation={3}>
          <View style={[styles.typeIconBg, { backgroundColor: typeConf.color + '22' }]}>
            <MaterialCommunityIcons name={typeConf.icon as any} size={32} color={typeConf.color} />
          </View>
          <Text style={[styles.amountText, { color: typeConf.color }]}>
            {formatCurrency(transaction.amount)}
          </Text>
          <Chip style={{ backgroundColor: typeConf.color + '22' }} textStyle={{ color: typeConf.color }}>
            {typeConf.label}
          </Chip>
        </Surface>

        {/* Details */}
        <Surface style={styles.detailCard} elevation={1}>
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Fecha</Text>
            <Text style={styles.detailValue}>{formatDate(transaction.date)}</Text>
          </View>
          <Divider style={styles.rowDivider} />
          {transaction.description && (
            <>
              <View style={styles.detailRow}>
                <Text style={styles.detailLabel}>Descripción</Text>
                <Text style={styles.detailValue}>{transaction.description}</Text>
              </View>
              <Divider style={styles.rowDivider} />
            </>
          )}
          {category && (
            <>
              <View style={styles.detailRow}>
                <Text style={styles.detailLabel}>Categoría</Text>
                <View style={styles.catChip}>
                  <View style={[styles.catDot, { backgroundColor: category.color }]} />
                  <Text style={styles.detailValue}>{category.name}</Text>
                </View>
              </View>
              <Divider style={styles.rowDivider} />
            </>
          )}
          {account && (
            <View style={styles.detailRow}>
              <Text style={styles.detailLabel}>Cuenta</Text>
              <Text style={styles.detailValue}>{account.name}</Text>
            </View>
          )}
        </Surface>

        <Button
          mode="outlined"
          onPress={handleDelete}
          textColor={colors.error}
          style={styles.deleteBtn}
          icon="trash-can-outline"
        >
          Eliminar movimiento
        </Button>
      </ScrollView>
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
  amountCard: {
    borderRadius: radius.xl,
    padding: spacing.xl,
    backgroundColor: colors.bg.card,
    alignItems: 'center',
    gap: spacing.md,
    borderTopWidth: 3,
  },
  typeIconBg: {
    width: 64,
    height: 64,
    borderRadius: radius.full,
    justifyContent: 'center',
    alignItems: 'center',
  },
  amountText: {
    fontSize: typography.size['2xl'],
    fontWeight: typography.weight.bold,
  },
  detailCard: {
    borderRadius: radius.lg,
    backgroundColor: colors.bg.card,
    overflow: 'hidden',
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: spacing.base,
  },
  detailLabel: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
  },
  detailValue: {
    fontSize: typography.size.base,
    color: colors.text.primary,
    fontWeight: typography.weight.medium,
  },
  rowDivider: {
    marginHorizontal: spacing.base,
    backgroundColor: colors.border.subtle,
  },
  catChip: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  catDot: { width: 10, height: 10, borderRadius: radius.full },
  deleteBtn: {
    borderColor: colors.error,
    marginTop: spacing.md,
    borderRadius: radius.md,
  },
});
