import { Tabs } from 'expo-router';
import { View, StyleSheet } from 'react-native';
import { Text } from 'react-native-paper';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { colors, spacing, typography } from '@/src/lib/theme';

type TabIconProps = {
  name: string;
  label: string;
  focused: boolean;
  size?: number;
};

function TabIcon({ name, label, focused, size = 22 }: TabIconProps) {
  return (
    <View style={styles.tabItem}>
      <MaterialCommunityIcons
        name={name as any}
        size={size}
        color={focused ? colors.brand.primary : colors.text.muted}
      />
      <Text style={[styles.tabLabel, focused && styles.tabLabelFocused]}>
        {label}
      </Text>
    </View>
  );
}

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: styles.tabBar,
        tabBarShowLabel: false,
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon name="home-variant" label="Inicio" focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="movimientos"
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon name="swap-horizontal" label="Movimientos" focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="presupuesto"
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon name="chart-donut" label="Presupuesto" focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="objetivos"
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon name="flag-checkered" label="Objetivos" focused={focused} />
          ),
        }}
      />
      <Tabs.Screen
        name="mas"
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon name="menu" label="Más" focused={focused} />
          ),
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    backgroundColor: colors.bg.secondary,
    borderTopColor: colors.border.default,
    borderTopWidth: 1,
    height: 72,
    paddingBottom: 8,
    paddingTop: 8,
  },
  tabItem: {
    alignItems: 'center',
    gap: 3,
  },
  tabLabel: {
    fontSize: 10,
    color: colors.text.muted,
    fontWeight: typography.weight.medium,
  },
  tabLabelFocused: {
    color: colors.brand.primary,
  },
});
