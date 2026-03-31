import { View, StyleSheet } from 'react-native';
import { colors, radius } from '@/src/lib/theme';

interface Props {
  progress: number; // 0-100
  color?: string;
  height?: number;
  backgroundColor?: string;
}

export function ProgressBar({
  progress,
  color = colors.brand.primary,
  height = 6,
  backgroundColor = colors.bg.elevated,
}: Props) {
  const clamped = Math.min(Math.max(progress, 0), 100);
  return (
    <View style={[styles.track, { height, backgroundColor }]}>
      <View
        style={[
          styles.fill,
          {
            width: `${clamped}%`,
            height,
            backgroundColor: color,
          },
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  track: {
    width: '100%',
    borderRadius: radius.full,
    overflow: 'hidden',
  },
  fill: {
    borderRadius: radius.full,
  },
});
