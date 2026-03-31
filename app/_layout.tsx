import { useEffect, Component, ReactNode } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { View, Text } from 'react-native';
import { PaperProvider } from 'react-native-paper';
import { runMigrations } from '@/src/db/migrations';
import { seedDatabase } from '@/src/db/seeds';
import { colors } from '@/src/lib/theme';
import { paperTheme } from '@/src/lib/paperTheme';

// Error boundary para capturar crashes antes de mostrarlos en pantalla
class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null };
  static getDerivedStateFromError(error: Error) {
    return { error };
  }
  render() {
    if (this.state.error) {
      return (
        <View style={{ flex: 1, backgroundColor: '#0F0F14', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
          <Text style={{ color: '#F87171', fontSize: 18, fontWeight: 'bold', marginBottom: 12 }}>Error al iniciar la app</Text>
          <Text style={{ color: '#9898AA', fontSize: 13, textAlign: 'center' }}>
            {(this.state.error as Error).message}
          </Text>
        </View>
      );
    }
    return this.props.children;
  }
}

export default function RootLayout() {
  useEffect(() => {
    async function init() {
      try {
        await runMigrations();
        await seedDatabase();
      } catch (e) {
        console.error('[DB INIT ERROR]', e);
      }
    }
    init();
  }, []);

  return (
    <ErrorBoundary>
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
    </ErrorBoundary>
  );
}
