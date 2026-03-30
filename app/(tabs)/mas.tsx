import React from 'react';
import { View, ScrollView, StyleSheet, Pressable } from 'react-native';
import { Text, Surface, List, Divider } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { colors, spacing, radius, typography } from '@/src/lib/theme';

type MenuItem = {
  icon: string;
  iconColor: string;
  title: string;
  description: string;
  route: string;
};

const MENU_SECTIONS: { title: string; items: MenuItem[] }[] = [
  {
    title: 'Finanzas',
    items: [
      {
        icon: 'account-group',
        iconColor: colors.saving,
        title: 'Personas y deudas',
        description: 'Seguimiento de lo que te deben y debés',
        route: '/personas/index',
      },
      {
        icon: 'cart-heart',
        iconColor: colors.investment,
        title: 'Compras inteligentes',
        description: 'Lista de deseos con análisis anti-impulso',
        route: '/compras/index',
      },
      {
        icon: 'calendar-repeat',
        iconColor: colors.warning,
        title: 'Gastos fijos',
        description: 'Gastos recurrentes y vencimientos',
        route: '/gastos-fijos/index',
      },
    ],
  },
  {
    title: 'Análisis',
    items: [
      {
        icon: 'chart-bar',
        iconColor: colors.brand.primary,
        title: 'Reportes',
        description: 'Estadísticas y gráficos de tus finanzas',
        route: '/personas/index', // placeholder
      },
      {
        icon: 'credit-card-multiple',
        iconColor: colors.expense,
        title: 'Tarjetas de crédito',
        description: 'Cierres, vencimientos y resúmenes',
        route: '/personas/index', // placeholder
      },
      {
        icon: 'archive-arrow-down',
        iconColor: colors.transfer,
        title: 'Cierre de mes',
        description: 'Resumen mensual y balance',
        route: '/personas/index', // placeholder
      },
    ],
  },
  {
    title: 'App',
    items: [
      {
        icon: 'cog',
        iconColor: colors.text.muted,
        title: 'Configuración',
        description: 'Cuentas, categorías, perfil',
        route: '/personas/index', // placeholder
      },
    ],
  },
];

export default function MasScreen() {
  return (
    <ScrollView
      style={styles.root}
      contentContainerStyle={styles.content}
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.header}>
        <Text style={styles.title}>Más</Text>
      </View>

      {MENU_SECTIONS.map((section) => (
        <View key={section.title} style={styles.section}>
          <Text style={styles.sectionTitle}>{section.title}</Text>
          <Surface style={styles.sectionCard} elevation={1}>
            {section.items.map((item, idx) => (
              <React.Fragment key={item.route + item.title}>
                <Pressable
                  onPress={() => router.push(item.route as any)}
                  style={({ pressed }) => [styles.menuItem, pressed && styles.menuItemPressed]}
                  android_ripple={{ color: colors.brand.muted }}
                >
                  <View style={[styles.menuIcon, { backgroundColor: item.iconColor + '22' }]}>
                    <MaterialCommunityIcons name={item.icon as any} size={22} color={item.iconColor} />
                  </View>
                  <View style={styles.menuText}>
                    <Text style={styles.menuTitle}>{item.title}</Text>
                    <Text style={styles.menuDesc} numberOfLines={1}>{item.description}</Text>
                  </View>
                  <MaterialCommunityIcons name="chevron-right" size={20} color={colors.text.muted} />
                </Pressable>
                {idx < section.items.length - 1 && (
                  <Divider style={styles.divider} />
                )}
              </React.Fragment>
            ))}
          </Surface>
        </View>
      ))}

      {/* Version */}
      <Text style={styles.version}>Finanzas App · v1.0.0</Text>

      <View style={{ height: 80 }} />
    </ScrollView>
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
    marginBottom: spacing.xs,
  },
  title: {
    fontSize: typography.size['2xl'],
    fontWeight: typography.weight.bold,
    color: colors.text.primary,
  },
  section: {
    gap: spacing.sm,
  },
  sectionTitle: {
    fontSize: typography.size.xs,
    fontWeight: typography.weight.semibold,
    color: colors.text.muted,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    paddingHorizontal: spacing.xs,
  },
  sectionCard: {
    borderRadius: radius.xl,
    backgroundColor: colors.bg.card,
    overflow: 'hidden',
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.base,
  },
  menuItemPressed: {
    backgroundColor: colors.brand.muted,
  },
  menuIcon: {
    width: 44,
    height: 44,
    borderRadius: radius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  menuText: {
    flex: 1,
    gap: 2,
  },
  menuTitle: {
    fontSize: typography.size.base,
    fontWeight: typography.weight.medium,
    color: colors.text.primary,
  },
  menuDesc: {
    fontSize: typography.size.xs,
    color: colors.text.muted,
  },
  divider: {
    marginHorizontal: spacing.base,
    backgroundColor: colors.border.subtle,
  },
  version: {
    textAlign: 'center',
    fontSize: typography.size.xs,
    color: colors.text.muted,
    marginTop: spacing.lg,
  },
});
