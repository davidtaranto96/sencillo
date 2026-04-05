import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../budget/presentation/pages/budget_page.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../settings/presentation/pages/settings_page.dart'
    show showTabConfigSheet;

class MorePage extends ConsumerStatefulWidget {
  const MorePage({super.key});

  @override
  ConsumerState<MorePage> createState() => _MorePageState();
}

class _MorePageState extends ConsumerState<MorePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Más',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // ── Quick Stats ──
            SliverToBoxAdapter(child: _QuickStats()),

            // ── Herramientas section ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  'Herramientas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // ── Grid de herramientas ──
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  _ToolCard(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Movimientos',
                    subtitle: 'Historial completo',
                    color: AppTheme.colorTransfer,
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const TransactionsPage(standalone: true),
                      ),
                    ),
                  ),
                  _ToolCard(
                    icon: Icons.pie_chart_rounded,
                    label: 'Presupuestos',
                    subtitle: 'Límites por categoría',
                    color: AppTheme.colorWarning,
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const BudgetPage(standalone: true),
                      ),
                    ),
                  ),
                  _ToolCard(
                    icon: Icons.calendar_month_rounded,
                    label: 'Mes',
                    subtitle: 'Resumen mensual',
                    color: AppTheme.colorTransfer,
                    onTap: () => context.push('/monthly_overview'),
                  ),
                  _ToolCard(
                    icon: Icons.people_rounded,
                    label: 'Personas',
                    subtitle: 'Deudas y préstamos',
                    color: AppTheme.colorIncome,
                    onTap: () => context.push('/people'),
                  ),
                  _ToolCard(
                    icon: Icons.shopping_cart_rounded,
                    label: 'Wishlist',
                    subtitle: 'Compras inteligentes',
                    color: AppTheme.colorWarning,
                    onTap: () => context.push('/wishlist'),
                  ),
                  _ToolCard(
                    icon: Icons.bar_chart_rounded,
                    label: 'Reportes',
                    subtitle: 'Métricas y análisis',
                    color: AppTheme.colorExpense,
                    onTap: () => context.push('/reports'),
                  ),
                  _ToolCard(
                    icon: Icons.account_balance_rounded,
                    label: 'Cuentas',
                    subtitle: 'Saldos y detalle',
                    color: AppTheme.colorIncome,
                    onTap: () => context.push('/accounts'),
                  ),
                  _ToolCard(
                    icon: Icons.savings_rounded,
                    label: 'Ahorros',
                    subtitle: 'Fondo de ahorro',
                    color: AppTheme.colorTransfer,
                    onTap: () => context.push('/savings'),
                  ),
                ],
              ),
            ),

            // ── Configuración section ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  'Configuración',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SettingsRow(
                    icon: Icons.settings_rounded,
                    label: 'Ajustes generales',
                    subtitle: 'Perfil, moneda, categorías',
                    color: AppTheme.colorNeutral,
                    onTap: () => context.push('/settings'),
                  ),
                  const SizedBox(height: 8),
                  _SettingsRow(
                    icon: Icons.tab_rounded,
                    label: 'Personalizar navegación',
                    subtitle: 'Elegí qué pestañas mostrar',
                    color: AppTheme.colorTransfer,
                    onTap: () => showTabConfigSheet(context, ref),
                  ),
                ]),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quick Stats
// ─────────────────────────────────────────────
class _QuickStats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final goalsSummary = ref.watch(goalsSummaryProvider);
    final budgetLimit = ref.watch(totalBudgetLimitProvider);
    final budgetSpent = ref.watch(totalBudgetSpentProvider);

    // Saldo total
    double totalBalance = 0;
    for (final a in accounts) {
      totalBalance += a.balance;
    }

    final budgetPct = budgetLimit > 0 ? (budgetSpent / budgetLimit).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Saldo total',
              value: formatAmount(totalBalance, compact: true),
              color: totalBalance >= 0 ? AppTheme.colorIncome : AppTheme.colorExpense,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              icon: Icons.donut_large_rounded,
              label: 'Presupuesto',
              value: '${(budgetPct * 100).toInt()}% usado',
              color: budgetPct >= 0.8 ? AppTheme.colorExpense : AppTheme.colorWarning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatChip(
              icon: Icons.flag_rounded,
              label: 'Objetivos',
              value: goalsSummary.activeCount > 0
                  ? '${(goalsSummary.progress * 100).toInt()}%'
                  : '—',
              color: AppTheme.colorTransfer,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tool Card (Grid)
// ─────────────────────────────────────────────
class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Settings Row (List)
// ─────────────────────────────────────────────
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }
}
