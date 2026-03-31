import 'package:flutter/material.dart';

class AppProgressBar extends StatelessWidget {
  final double value;       // 0.0 – 1.0
  final Color? color;
  final double height;
  final bool showLabel;
  final String? label;

  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
    this.showLabel = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clampedValue = value.clamp(0.0, 1.0);
    final barColor = color ?? cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel && label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label!, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  '${(clampedValue * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: clampedValue,
            backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: height,
          ),
        ),
      ],
    );
  }
}
