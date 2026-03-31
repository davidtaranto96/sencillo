import { View, ViewProps, StyleSheet, Pressable, PressableProps } from 'react-native';
import { colors, radius, spacing, shadows } from '@/src/lib/theme';

interface CardProps extends ViewProps {
  elevated?: boolean;
}

export function Card({ elevated = false, style, children, ...props }: CardProps) {
  return (
    <View
      style={[styles.card, elevated && styles.elevated, style]}
      {...props}
    >
      {children}
    </View>
  );
}

interface PressableCardProps extends PressableProps {
  elevated?: boolean;
}

export function PressableCard({ elevated = false, style, children, ...props }: PressableCardProps) {
  return (
    <Pressable
      style={({ pressed }) => [
        styles.card,
        elevated && styles.elevated,
        pressed && styles.pressed,
        typeof style === 'function' ? style({ pressed }) : style,
      ]}
      {...props}
    >
      {children}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.bg.card,
    borderRadius: radius.lg,
    padding: spacing.base,
    borderWidth: 1,
    borderColor: colors.border.default,
  },
  elevated: {
    ...shadows.card,
  },
  pressed: {
    opacity: 0.85,
    transform: [{ scale: 0.99 }],
  },
});
