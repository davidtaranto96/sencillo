import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/mock_data_provider.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/theme/app_theme.dart';

class QuickStatsRow extends StatelessWidget {
  final MonthlyBalance balance;
  const QuickStatsRow({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickStat(
          label: 'Disponible',
          value: formatAmount(balance.balance, compact: true),
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.colorIncome,
        ),
        const SizedBox(width: 8),
        _QuickStat(
          label: 'A recuperar',
          value: formatAmount(balance.pendingToRecover, compact: true),
          icon: Icons.pending_outlined,
          color: AppTheme.colorWarning,
        ),
        const SizedBox(width: 8),
        _QuickStat(
          label: 'Este mes',
          value: '${DateTime.now().day}d',
          icon: Icons.calendar_today_outlined,
          color: AppTheme.colorTransfer,
        ),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
