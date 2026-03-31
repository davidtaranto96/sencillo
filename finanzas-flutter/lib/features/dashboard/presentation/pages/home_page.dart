import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/mock_data_provider.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_header.dart';

import '../widgets/balance_hero_card.dart';
import '../widgets/quick_stats_row.dart';
import '../widgets/accounts_row.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/add_transaction_fab.dart';
import '../../../alerts/presentation/widgets/alerts_bottom_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(monthlyBalanceProvider);
    final accounts = ref.watch(mockAccountsProvider);
    final txs = ref.watch(mockTransactionsProvider);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy', 'es').format(now);

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ──────────────────────────────────
          SliverAppBar(
            floating: true,
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finanzas',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  monthName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: cs.onSurface),
                onPressed: () {
                  AlertsBottomSheet.show(context);
                },
              ),
              IconButton(
                icon: Icon(Icons.settings_outlined, color: cs.onSurface),
                onPressed: () => context.push('/settings'),
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── Contenido ────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Hero: balance del mes
                BalanceHeroCard(balance: balance),
                const SizedBox(height: 12),

                // Stats rápidos
                QuickStatsRow(balance: balance),
                const SizedBox(height: 20),

                // Cuentas
                SectionHeader(
                  title: 'Mis cuentas',
                  actionLabel: 'Ver todas',
                  onAction: () => context.push('/accounts'),
                ),
                const SizedBox(height: 8),
                AccountsRow(accounts: accounts),
                const SizedBox(height: 20),

                // Pendiente a recuperar (si hay)
                if (balance.pendingToRecover > 0) ...[
                  _PendingRecoverBanner(amount: balance.pendingToRecover),
                  const SizedBox(height: 20),
                ],

                // Movimientos recientes
                SectionHeader(
                  title: 'Movimientos recientes',
                  actionLabel: 'Ver todos',
                  onAction: () => context.go('/transactions'),
                ),
                const SizedBox(height: 8),
                RecentTransactionsList(transactions: txs.take(5).toList()),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: const AddTransactionFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ─────────────────────────────────────────────────────
// Banner de pendiente a recuperar
// ─────────────────────────────────────────────────────
class _PendingRecoverBanner extends StatelessWidget {
  final double amount;
  const _PendingRecoverBanner({required this.amount});

  @override
  Widget build(BuildContext context) {

    return InkWell(
      onTap: () => context.go('/monthly_overview'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.colorWarning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.colorWarning.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.pending_actions_rounded,
                color: AppTheme.colorWarning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tenés ${formatAmount(amount)} pendientes de recuperar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.colorWarning,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    'De gastos compartidos con otras personas',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.colorWarning, size: 18),
          ],
        ),
      ),
    );
  }
}
