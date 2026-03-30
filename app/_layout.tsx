import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { View } from 'react-native';
import { PaperProvider } from 'react-native-paper';
import { runMigrations } from '@/src/db/migrations';
import { seedDatabase } from '@/src/db/seeds';
import { colors } from '@/src/lib/theme';
import { paperTheme } from '@/src/lib/paperTheme';

export default function RootLayout() {
  useEffect(() => {
    async function init() {
      await runMigrations();
      await seedDatabase();
    }
    init();
  }, []);

  return (
    <PaperProvider theme={paperTheme}>
      <View style={{ flex: 1, backgroundColor: colors.bg.primary }}>
        <StatusBar style="light" />
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen
            name="transaction/new"
            options={{ presentation: 'modal', animation: 'slide_from_bottom' }}
          />
          <Stack.Screen
            name="transaction/[id]"
            options={{ presentation: 'card', animation: 'slide_from_right' }}
          />
          <Stack.Screen
            name="account/[id]"
            options={{ presentation: 'card', animation: 'slide_from_right' }}
          />
          <Stack.Screen
            name="goal/[id]"
            options={{ presentation: 'card', animation: 'slide_from_right' }}
          />
          <Stack.Screen
            name="card/[id]"
            options={{ presentation: 'card', animation: 'slide_from_right' }}
          />
          <Stack.Screen
            name="personas/index"
            options={{ presentation: 'card', animation: 'slide_from_right' }}
          />
          <Stack.Screen
            name="compras/index"
            options={{ presentation: 'card', animation: 'slide_from_right' }}
          />
          <Stack.Screen
            name="gastos-fijos/index"
            options={{ presentation: 'card', animation: 'slide_from_right' }}
          />
        </Stack>
      </View>
    </PaperProvider>
  );
}
