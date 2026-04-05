import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/mock_data_provider.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_progress_bar.dart';

enum _HeroView { disponible, efectivo, deuda }

class BalanceHeroCard extends StatefulWidget {
  final MonthlyBalance balance;
  final double safeBudget;
  final double arsCash;
  final double pendingCards;
  final double totalSavedInGoals;
  final VoidCallback? onSavingsTap;
  final VoidCallback? onIncomeTap;
  final VoidCallback? onExpenseTap;

  const BalanceHeroCard({
    super.key,
    required this.balance,
    required this.safeBudget,
    required this.arsCash,
    required this.pendingCards,
    this.totalSavedInGoals = 0,
    this.onSavingsTap,
    this.onIncomeTap,
    this.onExpenseTap,
  });

  @override
  State<BalanceHeroCard> createState() => _BalanceHeroCardState();
}

class _BalanceHeroCardState extends State<BalanceHeroCard> {
  _HeroView _view = _HeroView.disponible;

  double get _mainValue {
    switch (_view) {
      case _HeroView.disponible:
        return widget.safeBudget;
      case _HeroView.efectivo:
        return widget.arsCash;
      case _HeroView.deuda:
        return widget.pendingCards;
    }
  }

  String get _label {
    switch (_view) {
      case _HeroView.disponible:
        return 'Disponible';
      case _HeroView.efectivo:
        return 'Efectivo total';
      case _HeroView.deuda:
        return 'Deuda tarjetas';
    }
  }

  void _nextView() {
    setState(() {
      _view = _HeroView.values[(_view.index + 1) % _HeroView.values.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Savings rate based on real money allocated to goals vs income
    final realSavings = widget.totalSavedInGoals;
    final savingsRate = widget.balance.income > 0
        ? (realSavings / widget.balance.income).clamp(0.0, 1.0)
        : 0.0;
    final savingsColor = savingsRate > 0.2
        ? AppTheme.colorIncome
        : savingsRate > 0.05
            ? AppTheme.colorWarning
            : AppTheme.colorExpense;

    final isNegative = _view == _HeroView.deuda ? false : _mainValue < 0;
    final valueColor = _view == _HeroView.deuda
        ? AppTheme.colorExpense
        : (isNegative ? AppTheme.colorExpense : cs.onSurface);

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
              GestureDetector(
                onTap: _nextView,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.swap_horiz_rounded, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),
              _buildSavingsBadge(savingsRate, savingsColor),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Align(
              key: ValueKey(_view),
              alignment: Alignment.centerLeft,
              child: Text(
                formatAmount(_mainValue),
                style: GoogleFonts.inter(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppProgressBar(
            value: savingsRate,
            color: savingsColor,
            height: 8,
          ),
          const SizedBox(height: 20),

          // Fila de Estadísticas Detalladas — siempre 3 columnas simétricas
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onIncomeTap,
                  child: _DetailStat(
                    label: 'Ingresos',
                    value: formatAmount(widget.balance.income, compact: true),
                    icon: Icons.payments_outlined,
                    color: AppTheme.colorIncome,
                    tappable: widget.onIncomeTap != null,
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onExpenseTap,
                  child: _DetailStat(
                    label: 'Gastado',
                    value: formatAmount(widget.balance.expense, compact: true),
                    icon: Icons.shopping_cart_outlined,
                    color: AppTheme.colorExpense,
                    tappable: widget.onExpenseTap != null,
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onSavingsTap,
                  child: _DetailStat(
                    label: 'Ahorro',
                    value: formatAmount(realSavings, compact: true),
                    icon: Icons.savings_outlined,
                    color: AppTheme.colorTransfer,
                    tappable: widget.onSavingsTap != null,
                  ),
                ),
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
  final bool tappable;

  const _DetailStat({required this.label, required this.value, required this.icon, required this.color, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
            ),
            if (tappable) ...[
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 12, color: Colors.white24),
            ],
          ],
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
    );
  }
}
