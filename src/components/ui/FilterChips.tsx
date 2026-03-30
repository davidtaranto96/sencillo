import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import { Chip } from 'react-native-paper';
import { colors, spacing } from '@/src/lib/theme';

interface ChipOption {
  key: string;
  label: string;
  icon?: string;
}

interface Props {
  options: ChipOption[];
  selected: string;
  onSelect: (key: string) => void;
}

export function FilterChips({ options, selected, onSelect }: Props) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.container}
    >
      {options.map((opt) => {
        const isSelected = selected === opt.key;
        return (
          <Chip
            key={opt.key}
            selected={isSelected}
            onPress={() => onSelect(opt.key)}
            icon={opt.icon as any}
            style={[styles.chip, isSelected && styles.chipSelected]}
            textStyle={[styles.chipText, isSelected && styles.chipTextSelected]}
            showSelectedCheck={false}
          >
            {opt.label}
          </Chip>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: spacing.base,
    gap: spacing.sm,
    flexDirection: 'row',
    alignItems: 'center',
  },
  chip: {
    backgroundColor: colors.bg.elevated,
    borderColor: colors.border.default,
    borderWidth: 1,
  },
  chipSelected: {
    backgroundColor: colors.brand.muted,
    borderColor: colors.brand.primary,
  },
  chipText: {
    color: colors.text.secondary,
    fontSize: 13,
  },
  chipTextSelected: {
    color: colors.brand.primary,
    fontWeight: '600',
  },
});
