import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

enum EmptyStateVariant { full, compact, inline }

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? ctaLabel;
  final IconData? ctaIcon;
  final VoidCallback? onCta;
  final String? secondaryCtaLabel;
  final IconData? secondaryCtaIcon;
  final VoidCallback? onSecondaryCta;
  final Widget? extraContent;
  final EmptyStateVariant variant;
  final Color? accentColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.ctaIcon,
    this.onCta,
    this.secondaryCtaLabel,
    this.secondaryCtaIcon,
    this.onSecondaryCta,
    this.extraContent,
    this.variant = EmptyStateVariant.full,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.primary;
    final spec = _spec(variant);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: spec.iconBoxSize,
          height: spec.iconBoxSize,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: spec.iconSize, color: accent),
        ),
        SizedBox(height: spec.titleGap),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: spec.titleSize,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: spec.descSize,
              color: AppTheme.textSecondaryDark,
              height: 1.45,
            ),
          ),
        ),
        if (extraContent != null) ...[
          SizedBox(height: spec.contentGap),
          extraContent!,
        ],
        if (ctaLabel != null && onCta != null) ...[
          SizedBox(height: spec.ctaGap),
          _PrimaryCta(
            label: ctaLabel!,
            icon: ctaIcon,
            color: accent,
            onTap: onCta!,
            compact: variant != EmptyStateVariant.full,
          ),
        ],
        if (secondaryCtaLabel != null && onSecondaryCta != null) ...[
          const SizedBox(height: 8),
          _SecondaryCta(
            label: secondaryCtaLabel!,
            icon: secondaryCtaIcon,
            onTap: onSecondaryCta!,
          ),
        ],
      ],
    );

    return Padding(
      padding: spec.outerPadding,
      child: content,
    );
  }

  _Spec _spec(EmptyStateVariant v) {
    switch (v) {
      case EmptyStateVariant.full:
        return const _Spec(
          outerPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          iconBoxSize: 80,
          iconSize: 40,
          titleSize: 18,
          descSize: 13,
          titleGap: 18,
          contentGap: 18,
          ctaGap: 20,
        );
      case EmptyStateVariant.compact:
        return const _Spec(
          outerPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          iconBoxSize: 56,
          iconSize: 28,
          titleSize: 15,
          descSize: 12,
          titleGap: 12,
          contentGap: 14,
          ctaGap: 16,
        );
      case EmptyStateVariant.inline:
        return const _Spec(
          outerPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          iconBoxSize: 44,
          iconSize: 22,
          titleSize: 14,
          descSize: 12,
          titleGap: 10,
          contentGap: 10,
          ctaGap: 12,
        );
    }
  }
}

class _Spec {
  final EdgeInsets outerPadding;
  final double iconBoxSize;
  final double iconSize;
  final double titleSize;
  final double descSize;
  final double titleGap;
  final double contentGap;
  final double ctaGap;
  const _Spec({
    required this.outerPadding,
    required this.iconBoxSize,
    required this.iconSize,
    required this.titleSize,
    required this.descSize,
    required this.titleGap,
    required this.contentGap,
    required this.ctaGap,
  });
}

class _PrimaryCta extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;
  final bool compact;
  const _PrimaryCta({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 20,
          vertical: compact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryCta extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _SecondaryCta({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper para ejemplos chip-style ("café 3500" debajo del empty state).
class EmptyStateExampleChip extends StatelessWidget {
  final String text;
  final IconData? leadingIcon;
  final Color? color;
  const EmptyStateExampleChip({
    super.key,
    required this.text,
    this.leadingIcon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 14, color: c),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
