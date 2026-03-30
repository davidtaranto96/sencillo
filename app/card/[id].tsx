import React from 'react';
import { View, StyleSheet, Pressable } from 'react-native';
import { Text, Surface } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { colors, spacing, radius, typography } from '@/src/lib/theme';

export default function CardDetailScreen() {
  return (
    <View style={styles.root}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} style={styles.backBtn}>
          <MaterialCommunityIcons name="arrow-left" size={24} color={colors.text.secondary} />
        </Pressable>
        <Text style={styles.headerTitle}>Tarjeta</Text>
        <View style={{ width: 40 }} />
      </View>
      <View style={styles.center}>
        <MaterialCommunityIcons name="credit-card-outline" size={48} color={colors.text.muted} />
        <Text style={styles.placeholder}>Próximamente</Text>
        <Text style={styles.placeholderSub}>
          Gestión de tarjetas de crédito — MVP 1.1
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg.primary },
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
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing['2xl'],
  },
  placeholder: {
    fontSize: typography.size.xl,
    fontWeight: typography.weight.semibold,
    color: colors.text.secondary,
  },
  placeholderSub: {
    fontSize: typography.size.sm,
    color: colors.text.muted,
    textAlign: 'center',
  },
});
