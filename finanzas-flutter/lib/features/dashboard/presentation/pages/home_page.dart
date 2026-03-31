import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/providers/mock_data_provider.dart'; // For MonthlyBalance model
import '../widgets/balance_hero_card.dart';
import '../widgets/card_alert_banner.dart';
import '../widgets/accounts_row.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/quick_stats_row.dart';
import '../widgets/add_transaction_fab.dart';
import '../../../transactions/domain/models/transaction.dart' as dom_tx;
import '../../../../core/database/database_seeder.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    
    // Real Data Streams
    final accountsAsync = ref.watch(accountsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final syncStatus = ref.watch(_syncTimerProvider);
    final isSyncing = syncStatus.isLoading;
    
    return accountsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (accounts) {
        return transactionsAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
          data: (transactions) {
            // Brain Calculation Logic
            if (accounts.isEmpty) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 24),
                        Text('No hay cuentas configuradas', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                        const SizedBox(height: 12),
                        Text('Parece que tu base de datos está vacía. Podés sembrar los datos de prueba del desarrollador para ver cómo funciona.', 
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final db = ref.read(databaseProvider);
                              await DatabaseSeeder(db).clearAndSeedMockData();
                              // El stream se actualizará automáticamente
                            },
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Sembrar datos de prueba'),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.colorTransfer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final arsCash = accounts.where((a) => a.currencyCode == 'ARS' && !a.isCreditCard)
                                   .fold(0.0, (sum, a) => sum + a.balance);
            final mcAccount = accounts.any((a) => a.id == 'mc_credit') ? accounts.firstWhere((a) => a.id == 'mc_credit') : null;
            final visaAccount = accounts.any((a) => a.id == 'visa_credit') ? accounts.firstWhere((a) => a.id == 'visa_credit') : null;

            // Safe Budget = Cash - (Card Debts + Fixed Expenses Estimate)
            final cardDebts = (mcAccount?.totalDebt ?? 0) + (visaAccount?.totalDebt ?? 0);
            final safeBudget = arsCash - cardDebts - 317000;
            
            // Calculate real MonthlyBalance for widgets
            final now = DateTime.now();
            final currentMonthTxs = transactions.where((t) => t.date.month == now.month && t.date.year == now.year).toList();
            final income = currentMonthTxs.where((t) => t.type == dom_tx.TransactionType.income).fold(0.0, (sum, t) => sum + t.amount);
            final expense = currentMonthTxs.where((t) => t.type == dom_tx.TransactionType.expense).fold(0.0, (sum, t) => sum + t.amount);
            
            final monthlyStats = MonthlyBalance(
              income: income, 
              expense: expense, 
              pendingToRecover: 0,
            );
            
            final monthName = DateFormat('MMMM yyyy', 'es').format(now);

            return Scaffold(
              backgroundColor: cs.surface,
              body: Stack(
                children: [
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        floating: true,
                        backgroundColor: cs.surface,
                        title: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Finanzas', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700)),
                                Text(monthName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                              ],
                            ),
                            const Spacer(),
                          ],
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined),
                            onPressed: () {}, // Temporarily disabled, alerts are now in the home list
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () => context.push('/settings'),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 8),
                            BalanceHeroCard(
                              balance: monthlyStats, 
                              safeBudget: safeBudget,
                            ),
                            const SizedBox(height: 12),

                            const SizedBox(height: 12),
                            const _AlertsSection(),
                            
                            const SizedBox(height: 12),
                            QuickStatsRow(balance: monthlyStats),
                            const SizedBox(height: 20),

                            _SectionHeader(
                              title: 'Mis cuentas',
                              actionLabel: 'Ver todas',
                              onAction: () => context.push('/accounts'),
                            ),
                            const SizedBox(height: 8),
                            AccountsRow(accounts: accounts),
                            const SizedBox(height: 20),

                            _SectionHeader(
                              title: 'Movimientos detallados',
                              actionLabel: 'Ver todos',
                              onAction: () => context.push('/transactions'),
                            ),
                            const SizedBox(height: 8),
                            RecentTransactionsList(transactions: transactions.take(10).toList()),
                            const SizedBox(height: 100),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  
                  if (isSyncing)
                    const _SyncLoadingOverlay(progress: 0.8),
                ],
              ),
              floatingActionButton: isSyncing ? null : const AddTransactionFab(),
            );
          },
        );
      },
    );
  }
}

// Clean sync timer without circularity
final _syncTimerProvider = FutureProvider<void>((ref) async {
  await Future.delayed(const Duration(seconds: 2));
});

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader({required this.title, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onAction, child: Text(actionLabel, style: TextStyle(color: AppTheme.colorTransfer))),
      ],
    );
  }
}

class _SyncLoadingOverlay extends StatelessWidget {
  final double progress;
  const _SyncLoadingOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.colorTransfer),
            const SizedBox(height: 16),
            Text('Sincronizando con base de datos...', style: GoogleFonts.inter(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}


class _AlertsSection extends ConsumerWidget {
  const _AlertsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final creditCards = accounts.where((a) => a.isCreditCard).toList();
    final now = DateTime.now();
    final alerts = <Widget>[];

    for (final card in creditCards) {
      if (card.closingDay != null) {
        final closingDate = DateTime(now.year, now.month, card.closingDay!);
        final diff = closingDate.difference(now).inDays;
        if (diff >= 0 && diff <= 5) {
          alerts.add(CardAlertBanner(
            cardName: card.name,
            amount: card.balance,
            closingDate: closingDate,
            dueDate: DateTime(now.year, now.month + 1, card.dueDay ?? 1),
            isClosingSoon: true,
          ));
        }
      }
      
      if (card.pendingStatementAmount > 0) {
        alerts.add(CardAlertBanner(
          cardName: card.name,
          amount: card.pendingStatementAmount,
          dueDate: DateTime(now.year, now.month, card.dueDay ?? 1),
          closingDate: DateTime(now.year, now.month - 1, card.closingDay ?? 1),
          isClosingSoon: false,
        ));
      }
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Alertas de vencimiento',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),
        ...alerts.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: a,
        )),
      ],
    );
  }
}
