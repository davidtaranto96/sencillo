import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/providers/mock_data_provider.dart'; // For MonthlyBalance model
import '../../../../core/providers/shell_providers.dart';
import '../../../../core/database/app_database.dart';
import '../widgets/balance_hero_card.dart';
import '../widgets/card_alert_banner.dart';
import '../widgets/accounts_row.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/currency_rates_card.dart';
export '../widgets/currency_rates_card.dart' show currencyAutoRefreshProvider;
// AddTransactionFab moved to AppShell as MorphingFab
import '../../../transactions/domain/models/transaction.dart' as dom_tx;
import '../../../../core/providers/account_order_provider.dart';
import '../../../../core/providers/alerts_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _itemId<T>(T item) => (item as dynamic).id as String;

  List<T> _sortByCustomOrder<T>(List<T> items, List<String> order) {
    if (order.isEmpty) return items;
    final orderMap = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      orderMap[order[i]] = i;
    }
    final sorted = List<T>.from(items);
    sorted.sort((a, b) {
      final ai = orderMap[_itemId(a)] ?? 999;
      final bi = orderMap[_itemId(b)] ?? 999;
      return ai.compareTo(bi);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    
    // Real Data Streams
    final accountsAsync = ref.watch(accountsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final people = ref.watch(peopleStreamProvider).valueOrNull ?? [];
    final userProfile = ref.watch(userProfileStreamProvider).valueOrNull;
    final goals = ref.watch(goalsStreamProvider).valueOrNull ?? [];
    final totalSavedInGoals = goals.fold(0.0, (sum, g) => sum + g.savedAmount);
    final syncStatus = ref.watch(_syncTimerProvider);
    final isSyncing = syncStatus.isLoading;
    // Activar auto-refresh de cotizaciones cada 15 min
    ref.watch(currencyAutoRefreshProvider);
    
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
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.colorTransfer.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.account_balance_wallet_outlined,
                                size: 56,
                                color: AppTheme.colorTransfer.withValues(alpha: 0.8)),
                          ),
                          const SizedBox(height: 28),
                          Text('¡Bienvenido!',
                              style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          const SizedBox(height: 12),
                          Text(
                            'Empezá agregando tu primera cuenta para ver tu resumen financiero.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 15, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: () => context.push('/accounts'),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Agregar cuenta'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.colorTransfer),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'También podés ir a Movimientos para registrar tu primer gasto',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final arsCash = accounts.where((a) => a.currencyCode == 'ARS' && !a.isCreditCard)
                                   .fold(0.0, (sum, a) => sum + a.balance);

            // Pending credit card statements = real debt to discount from cash
            final pendingCards = accounts
                .where((a) => a.isCreditCard)
                .fold(0.0, (sum, a) => sum + a.pendingStatementAmount);
            final safeBudget = arsCash - pendingCards;
            
            // Calculate real MonthlyBalance for widgets
            final now = DateTime.now();
            final currentMonthTxs = transactions.where((t) => t.date.month == now.month && t.date.year == now.year).toList();
            final income = currentMonthTxs.where((t) => t.type == dom_tx.TransactionType.income).fold(0.0, (sum, t) => sum + t.amount);
            // Include transfers (card payments) as outflows in the monthly balance
            final expense = currentMonthTxs
                .where((t) =>
                    t.type == dom_tx.TransactionType.expense ||
                    t.type == dom_tx.TransactionType.transfer)
                .fold(0.0, (sum, t) => sum + t.amount);
            // Use actual person balances — reflects settled debts correctly
            final pendingToRecover = people
                .where((p) => p.totalBalance > 0)
                .fold(0.0, (sum, p) => sum + p.totalBalance);

            final monthlyStats = MonthlyBalance(
              income: income,
              expense: expense,
              pendingToRecover: pendingToRecover,
            );
            

            return Scaffold(
              backgroundColor: cs.surface,
              body: Stack(
                children: [
                  RefreshIndicator(
                    color: AppTheme.colorTransfer,
                    backgroundColor: const Color(0xFF1E1E2C),
                    displacement: 60,
                    onRefresh: () async {
                      ref.invalidate(accountsStreamProvider);
                      ref.invalidate(transactionsStreamProvider);
                      await Future.delayed(const Duration(milliseconds: 600));
                    },
                    child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        floating: true,
                        backgroundColor: cs.surface,
                        toolbarHeight: 64,
                        title: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hola${userProfile?.name != null ? ", ${userProfile!.name!.split(' ').first}" : ""}',
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    DateFormat("EEEE d 'de' MMMM", 'es').format(now),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          _NotificationBell(
                            onTap: () => _NotificationsBottomSheet.show(context, ref),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 22),
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
                              arsCash: arsCash,
                              pendingCards: pendingCards,
                              totalSavedInGoals: totalSavedInGoals,
                              onSavingsTap: () => context.push('/savings'),
                              onIncomeTap: () {
                                ref.read(txFilterProvider.notifier).state = TxFilterType.income;
                                ref.read(navigateToTabProvider.notifier).state = 'transactions';
                              },
                              onExpenseTap: () {
                                ref.read(txFilterProvider.notifier).state = TxFilterType.expense;
                                ref.read(navigateToTabProvider.notifier).state = 'transactions';
                              },
                            ),
                            const SizedBox(height: 12),
                            if (userProfile?.payDay != null)
                              _PaydayCountdown(profile: userProfile!),
                            const SizedBox(height: 12),
                            const CurrencyRatesCard(),
                            const SizedBox(height: 12),
                            const _AlertsSection(),
                            
                            // Quick stats strip
                            if (pendingToRecover > 0) ...[
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () {
                                  ref.read(navigateToTabProvider.notifier).state = 'people';
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.colorWarning.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.colorWarning.withValues(alpha: 0.15)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.people_outline_rounded, color: AppTheme.colorWarning, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Te deben ${formatAmount(pendingToRecover)}',
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            _SectionHeader(
                              title: 'Mis cuentas',
                              actionLabel: 'Ver todas',
                              onAction: () => context.push('/accounts'),
                            ),
                            const SizedBox(height: 8),
                            AccountsRow(accounts: _sortByCustomOrder(accounts, ref.watch(accountOrderProvider))),
                            const SizedBox(height: 20),

                            _SectionHeader(
                              title: 'Últimos movimientos',
                              actionLabel: 'Ver todos',
                              onAction: () {
                                ref.read(navigateToTabProvider.notifier).state = 'transactions';
                              },
                            ),
                            const SizedBox(height: 8),
                            RecentTransactionsList(transactions: transactions.take(10).toList()),
                            const SizedBox(height: 100),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  ),
                  if (isSyncing)
                    const _SyncLoadingOverlay(progress: 0.8),
                ],
              ),
              // FAB is now rendered by AppShell (morphing FAB)
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
        Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.colorTransfer.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel, style: GoogleFonts.inter(color: AppTheme.colorTransfer, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, color: AppTheme.colorTransfer, size: 16),
              ],
            ),
          ),
        ),
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


class _NotificationsBottomSheet extends ConsumerWidget {
  const _NotificationsBottomSheet();

  static void show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NotificationsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final smartAlerts = ref.watch(visibleAlertsProvider);
    final now = DateTime.now();

    final allNotifs = <Map<String, dynamic>>[];

    // 1. Credit card alerts
    for (final card in accounts.where((a) => a.isCreditCard)) {
      if (card.closingDay != null) {
        final closing = DateTime(now.year, now.month, card.closingDay!);
        if (closing.isAfter(now) && closing.difference(now).inDays <= 7) {
          allNotifs.add({
            'alertId': 'card_closing_${card.id}',
            'title': 'Cierre: ${card.name}',
            'body': 'Cierra en ${closing.difference(now).inDays} días.',
            'icon': Icons.credit_card_rounded,
            'color': AppTheme.colorWarning,
          });
        }
      }
      if (card.pendingStatementAmount > 0 && card.dueDay != null) {
        final due = DateTime(now.year, now.month, card.dueDay!);
        if (due.difference(now).inDays <= 7) {
          allNotifs.add({
            'alertId': 'card_due_${card.id}',
            'title': due.isBefore(now) ? 'VENCIDO: ${card.name}' : 'Vencimiento: ${card.name}',
            'body': 'Resumen de \$${formatAmount(card.pendingStatementAmount)}.',
            'icon': due.isBefore(now) ? Icons.error_outline_rounded : Icons.warning_rounded,
            'color': AppTheme.colorExpense,
          });
        }
      }
    }

    // 2. Smart alerts (budget + goals + debts)
    for (final a in smartAlerts) {
      allNotifs.add({
        'alertId': a.id,
        'title': a.title,
        'body': a.body,
        'icon': a.icon,
        'color': a.color,
      });
    }

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Notificaciones', style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const Spacer(),
              if (allNotifs.isNotEmpty)
                Text('${allNotifs.length}', style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.colorTransfer)),
            ],
          ),
          const SizedBox(height: 16),
          if (allNotifs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Todo en orden, no hay alertas.',
                  style: TextStyle(color: Colors.white38))),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allNotifs.length,
                itemBuilder: (context, index) {
                  final a = allNotifs[index];
                  final alertId = a['alertId'] as String?;
                  return Dismissible(
                    key: ValueKey(alertId ?? 'notif_$index'),
                    // Swipe right = snooze 7 days
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.snooze_rounded, color: AppTheme.colorTransfer, size: 18),
                          const SizedBox(width: 8),
                          Text('Recordar en 7 días', style: TextStyle(color: AppTheme.colorTransfer, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    // Swipe left = dismiss permanently
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Descartar', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                        ],
                      ),
                    ),
                    onDismissed: (direction) {
                      if (alertId != null) {
                        if (direction == DismissDirection.startToEnd) {
                          // Snooze for 7 days
                          ref.read(dismissedAlertsProvider.notifier).snooze(alertId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Te lo recordamos en 7 días'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          // Permanent dismiss
                          ref.read(dismissedAlertsProvider.notifier).dismiss(alertId);
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: (a['color'] as Color).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: (a['color'] as Color).withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (a['color'] as Color).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['title'] as String, style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(a['body'] as String, style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PaydayCountdown extends StatelessWidget {
  final UserProfileEntity profile;
  const _PaydayCountdown({required this.profile});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final payDay = profile.payDay!;
    final salary = profile.monthlySalary;
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR');

    // Calculate next payday
    DateTime nextPayday = DateTime(now.year, now.month, payDay.clamp(1, 28));
    if (nextPayday.isBefore(now) || nextPayday.isAtSameMomentAs(now)) {
      // If today IS payday, show special message
      if (now.day == payDay) {
        return _buildPaydayBanner(salary, fmt);
      }
      // Otherwise, next month
      nextPayday = DateTime(now.year, now.month + 1, payDay.clamp(1, 28));
    }

    final daysLeft = nextPayday.difference(DateTime(now.year, now.month, now.day)).inDays;

    final isClose = daysLeft <= 3;
    final color = isClose ? AppTheme.colorIncome : AppTheme.colorTransfer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daysLeft == 1 ? '¡Mañana cobrás!' : 'Faltan $daysLeft días para cobrar',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (salary != null)
                  Text(
                    'Ingreso esperado: ${fmt.format(salary)}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$daysLeft',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaydayBanner(double? salary, NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.colorIncome.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.colorIncome.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration_rounded, color: AppTheme.colorIncome, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hoy es día de cobro!',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.colorIncome,
                  ),
                ),
                if (salary != null)
                  Text(
                    'Ingreso: ${fmt.format(salary)}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  final VoidCallback onTap;
  const _NotificationBell({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(visibleAlertsProvider).length;
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontSize: 10)),
        backgroundColor: AppTheme.colorExpense,
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: onTap,
    );
  }
}

class _AlertsSection extends ConsumerWidget {
  const _AlertsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    final creditCards = accounts.where((a) => a.isCreditCard).toList();
    final smartAlerts = ref.watch(visibleAlertsProvider);
    final now = DateTime.now();
    final cardAlerts = <Widget>[];

    for (final card in creditCards) {
      if (card.closingDay != null) {
        final closingDate = DateTime(now.year, now.month, card.closingDay!);
        final diff = closingDate.difference(now).inDays;
        if (diff >= 0 && diff <= 7) {
          cardAlerts.add(CardAlertBanner(
            cardId: card.id,
            cardName: card.name,
            amount: card.balance,
            closingDate: closingDate,
            dueDate: DateTime(now.year, now.month + 1, card.dueDay ?? 1),
            isClosingSoon: true,
          ));
        }
      }

      if (card.pendingStatementAmount > 0 && card.dueDay != null) {
        final dueDate = DateTime(now.year, now.month, card.dueDay!);
        final daysUntilDue = dueDate.difference(now).inDays;
        if (daysUntilDue <= 7) {
          cardAlerts.add(CardAlertBanner(
            cardId: card.id,
            cardName: card.name,
            amount: card.pendingStatementAmount,
            dueDate: dueDate,
            closingDate: DateTime(now.year, now.month - 1, card.closingDay ?? 1),
            isClosingSoon: false,
          ));
        }
      }
    }

    final hasCardAlerts = cardAlerts.isNotEmpty;
    final hasSmartAlerts = smartAlerts.isNotEmpty;

    if (!hasCardAlerts && !hasSmartAlerts) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCardAlerts) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Tarjetas', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54,
              letterSpacing: 0.5,
            )),
          ),
          ...cardAlerts.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: a,
          )),
        ],
        if (hasSmartAlerts) ...[
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8, top: hasCardAlerts ? 8 : 0),
            child: Text('Alertas', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white54,
              letterSpacing: 0.5,
            )),
          ),
          ...smartAlerts.map((alert) => _SmartAlertBanner(
            key: ValueKey(alert.id),
            alert: alert,
            onDismiss: () => ref.read(dismissedAlertsProvider.notifier).dismiss(alert.id),
            onTap: alert.type == AlertType.monthClosing ? () => context.push('/monthly_overview') : null,
          )),
        ],
      ],
    );
  }
}

class _SmartAlertBanner extends StatelessWidget {
  final AppAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const _SmartAlertBanner({super.key, required this.alert, required this.onDismiss, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: alert.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: alert.color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: alert.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(alert.icon, color: alert.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title, style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13,
                    )),
                    const SizedBox(height: 2),
                    Text(alert.body, style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 11,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
