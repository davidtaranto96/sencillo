import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/mock_data_provider.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_progress_bar.dart';

class BalanceHeroCard extends StatelessWidget {
  final MonthlyBalance balance;
  final double safeBudget;

  const BalanceHeroCard({
    super.key, 
    required this.balance,
    required this.safeBudget,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final savingsRate = balance.savings.clamp(0.0, 1.0);
    final savingsColor = savingsRate > 0.2
        ? AppTheme.colorIncome
        : savingsRate > 0.05
            ? AppTheme.colorWarning
            : AppTheme.colorExpense;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.15),
            cs.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Presupuesto Libre Seguro',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              _buildSavingsBadge(savingsRate, savingsColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatAmount(safeBudget),
            style: GoogleFonts.inter(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: safeBudget >= 0 ? cs.onSurface : AppTheme.colorExpense,
              letterSpacing: -1,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          AppProgressBar(
            value: savingsRate,
            color: savingsColor,
            height: 8,
          ),
          const SizedBox(height: 20),
          
          // Fila de Estadísticas Detalladas
          Row(
            children: [
              _DetailStat(
                label: 'Sueldo',
                value: formatAmount(balance.income, compact: true),
                icon: Icons.payments_outlined,
                color: AppTheme.colorIncome,
              ),
              _DetailStat(
                label: 'Gastado',
                value: formatAmount(balance.expense, compact: true),
                icon: Icons.shopping_cart_outlined,
                color: AppTheme.colorExpense,
              ),
              _DetailStat(
                label: 'Ahorro',
                value: formatAmount(balance.income - balance.expense, compact: true),
                icon: Icons.savings_outlined,
                color: AppTheme.colorTransfer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsBadge(double rate, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${(rate * 100).toStringAsFixed(0)}% ahorro',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
