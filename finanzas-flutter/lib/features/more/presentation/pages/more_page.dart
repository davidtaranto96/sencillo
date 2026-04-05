import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/financial_logic.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/cloud_backup_service.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../budget/presentation/pages/budget_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../settings/presentation/pages/settings_page.dart'
    show showTabConfigSheet;
import 'help_page.dart' show showHelpSheet;
import '../widgets/my_qr_card.dart';

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
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Text(
                  'Más',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // ── Mi perfil / QR ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'MI PERFIL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white38,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: MyQrCard()),

            // ── Hero Balance Card ──
            SliverToBoxAdapter(child: _HeroBalanceCard()),

            // ── Insights rápidos ──
            SliverToBoxAdapter(child: _InsightsSection()),

            // ── Herramientas section ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  'HERRAMIENTAS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white38,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

            // ── Grid de herramientas ──
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.count(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
                children: [
                  _ToolCard(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Movimientos',
                    color: AppTheme.colorTransfer,
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const TransactionsPage(standalone: true),
                      ),
                    ),
                  ),
                  _ToolCard(
                    icon: Icons.donut_large_rounded,
                    label: 'Presupuestos',
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
                    color: AppTheme.colorTransfer,
                    onTap: () => context.push('/monthly_overview'),
                  ),
                  _ToolCard(
                    icon: Icons.people_rounded,
                    label: 'Personas',
                    color: AppTheme.colorIncome,
                    onTap: () => context.push('/people'),
                  ),
                  _ToolCard(
                    icon: Icons.shopping_cart_rounded,
                    label: 'Wishlist',
                    color: AppTheme.colorWarning,
                    onTap: () => context.push('/wishlist'),
                  ),
                  _ToolCard(
                    icon: Icons.bar_chart_rounded,
                    label: 'Reportes',
                    color: AppTheme.colorExpense,
                    onTap: () => context.push('/reports'),
                  ),
                  _ToolCard(
                    icon: Icons.account_balance_rounded,
                    label: 'Cuentas',
                    color: AppTheme.colorIncome,
                    onTap: () => context.push('/accounts'),
                  ),
                  _ToolCard(
                    icon: Icons.savings_rounded,
                    label: 'Ahorros',
                    color: AppTheme.colorTransfer,
                    onTap: () => context.push('/savings'),
                  ),
                ],
              ),
            ),

            // ── Apoyar el proyecto ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  'APOYAR EL PROYECTO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white38,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFf5a623).withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFf5a623).withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      _DonationRow(
                        icon: Icons.local_cafe_rounded,
                        label: 'Cafecito',
                        subtitle: 'cafecito.app/david-t',
                        color: const Color(0xFFf5a623),
                        onTap: () => _launchUrl('https://cafecito.app/david-t'),
                      ),
                      Divider(height: 1, color: Colors.white.withValues(alpha: 0.05), indent: 56),
                      _DonationRow(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Mercado Pago',
                        subtitle: 'Alias: david.taranto',
                        color: const Color(0xFF009ee3),
                        onTap: () => _launchUrl('https://link.mercadopago.com.ar/david.taranto'),
                      ),
                      Divider(height: 1, color: Colors.white.withValues(alpha: 0.05), indent: 56),
                      _DonationRow(
                        icon: Icons.code_rounded,
                        label: 'GitHub',
                        subtitle: 'github.com/davidtaranto96',
                        color: Colors.white60,
                        onTap: () => _launchUrl('https://github.com/davidtaranto96'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Configuración section ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  'CONFIGURACIÓN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white38,
                    letterSpacing: 1.2,
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
                  const SizedBox(height: 8),
                  _SettingsRow(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Ayuda y Tutorial',
                    subtitle: 'Guía de funciones, IA y trucos',
                    color: const Color(0xFF6C63FF),
                    onTap: () => showHelpSheet(context),
                  ),
                  const SizedBox(height: 8),
                  _SettingsRow(
                    icon: Icons.rocket_launch_rounded,
                    label: 'Novedades',
                    subtitle: 'Historial de versiones y roadmap',
                    color: AppTheme.colorIncome,
                    onTap: () => context.push('/novedades'),
                  ),
                  const SizedBox(height: 8),
                  _BackupRow(),
                  const SizedBox(height: 8),
                  _SettingsRow(
                    icon: Icons.logout_rounded,
                    label: 'Cerrar sesión',
                    subtitle: 'Salir de tu cuenta Google',
                    color: AppTheme.colorExpense,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A2E),
                          title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
                          content: const Text(
                            '¿Querés cerrar sesión? Tus datos locales se mantienen.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await ref.read(firebaseAuthServiceProvider).signOut();
                      }
                    },
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
// Hero Balance Card
// ─────────────────────────────────────────────
class _HeroBalanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final safeBudget = ref.watch(safeBudgetProvider);

    // Dinero disponible = solo cuentas que NO son tarjetas de crédito
    final liquidAccounts = accounts.where((a) => !a.isCreditCard).toList();
    final availableMoney = liquidAccounts.fold(0.0, (sum, a) => sum + a.balance);

    // Deuda total en tarjetas de crédito
    final creditCards = accounts.where((a) => a.isCreditCard).toList();
    final totalCardDebt = creditCards.fold(0.0, (sum, a) => sum + a.totalDebt);
    final totalCreditAvailable = creditCards.fold(0.0, (sum, a) => sum + a.availableCredit);

    final isPositive = availableMoney >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (isPositive ? AppTheme.colorIncome : AppTheme.colorExpense)
                      .withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isPositive ? AppTheme.colorIncome : AppTheme.colorExpense)
                    .withValues(alpha: 0.22),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 14,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dinero disponible',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white38,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Big number
                Text(
                  formatAmount(availableMoney),
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: isPositive ? Colors.white : AppTheme.colorExpense,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                if (liquidAccounts.isNotEmpty)
                  Text(
                    '${liquidAccounts.length} cuenta${liquidAccounts.length != 1 ? 's' : ''} · efectivo, banco y ahorros',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white30,
                    ),
                  ),

                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                const SizedBox(height: 14),

                // 3 secondary metrics in a row
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        icon: Icons.credit_card_rounded,
                        label: 'Deuda tarjetas',
                        value: totalCardDebt > 0 ? formatAmount(totalCardDebt, compact: true) : '—',
                        color: totalCardDebt > 0 ? AppTheme.colorExpense : Colors.white38,
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child: _MiniMetric(
                        icon: Icons.bolt_rounded,
                        label: 'Crédito disp.',
                        value: totalCreditAvailable > 0
                            ? formatAmount(totalCreditAvailable, compact: true)
                            : creditCards.isEmpty ? '—' : '\$0',
                        color: AppTheme.colorTransfer,
                      ),
                    ),
                    _VerticalDivider(),
                    Expanded(
                      child: _MiniMetric(
                        icon: Icons.shield_rounded,
                        label: 'Seguro gastar',
                        value: safeBudget > 0 ? formatAmount(safeBudget, compact: true) : '—',
                        color: safeBudget > 0 ? AppTheme.colorIncome : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white38,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.07),
    );
  }
}

// ─────────────────────────────────────────────
// Insights rápidos
// ─────────────────────────────────────────────
class _InsightsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleStreamProvider).valueOrNull ?? [];
    final budgets = ref.watch(budgetsStreamProvider).valueOrNull ?? [];
    final goals = ref.watch(activeGoalsProvider);

    final insights = <_InsightData>[];

    // Personas que te deben
    final debtors = people.where((p) => p.totalBalance > 0).toList();
    if (debtors.isNotEmpty) {
      final total = debtors.fold(0.0, (s, p) => s + p.totalBalance);
      insights.add(_InsightData(
        emoji: '👥',
        text: debtors.length == 1
            ? '${debtors.first.name} te debe ${formatAmount(total, compact: true)}'
            : '${debtors.length} personas te deben ${formatAmount(total, compact: true)}',
        color: AppTheme.colorIncome,
        route: '/people',
      ));
    }

    // Presupuesto en alerta (> 80%)
    final overBudgets = budgets
        .where((b) => b.limitAmount > 0 && b.spentAmount / b.limitAmount >= 0.80)
        .toList()
      ..sort((a, b) => (b.spentAmount / b.limitAmount).compareTo(a.spentAmount / a.limitAmount));
    if (overBudgets.isNotEmpty) {
      final b = overBudgets.first;
      final pct = (b.spentAmount / b.limitAmount * 100).toInt();
      insights.add(_InsightData(
        emoji: '⚠️',
        text: '${b.categoryName}: $pct% del presupuesto',
        color: pct >= 100 ? AppTheme.colorExpense : AppTheme.colorWarning,
        isWarning: true,
        navigatePush: true,
        pushWidget: const BudgetPage(standalone: true),
      ));
    }

    // Meta más cercana a completarse
    final almostDone = goals
        .where((g) => g.progress >= 0.75 && !g.isCompleted)
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    if (almostDone.isNotEmpty && insights.length < 2) {
      final g = almostDone.first;
      insights.add(_InsightData(
        emoji: '🎯',
        text: '${g.name}: ${(g.progress * 100).toInt()}% completado',
        color: AppTheme.colorTransfer,
        route: '/goals',
      ));
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESTACADO',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ...insights.take(2).map((ins) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InsightTile(data: ins),
              )),
        ],
      ),
    );
  }
}

class _InsightData {
  final String emoji;
  final String text;
  final Color color;
  final bool isWarning;
  final String? route;
  final bool navigatePush;
  final Widget? pushWidget;

  const _InsightData({
    required this.emoji,
    required this.text,
    required this.color,
    this.isWarning = false,
    this.route,
    this.navigatePush = false,
    this.pushWidget,
  });
}

class _InsightTile extends StatelessWidget {
  final _InsightData data;
  const _InsightTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (data.navigatePush && data.pushWidget != null) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => data.pushWidget!),
          );
        } else if (data.route != null) {
          context.push(data.route!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: data.color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Text(data.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: data.color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tool Card (Grid) — rediseñado
// ─────────────────────────────────────────────
class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// Backup Row
// ─────────────────────────────────────────────
class _BackupRow extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BackupRow> createState() => _BackupRowState();
}

class _BackupRowState extends ConsumerState<_BackupRow> {
  bool _loading = false;

  Future<void> _backup() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      final service = CloudBackupService(uid: uid);
      await service.uploadBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup completado ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Restaurar backup', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Esto reemplaza todos tus datos locales con el último backup. La app se reiniciará.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar', style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final service = CloudBackupService(uid: uid);
      await service.downloadBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restaurado. Reiniciá la app para ver los cambios.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorTransfer;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.cloud_rounded, color: color, size: 18),
            ),
            title: Text('Backup en la nube',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            subtitle: Text('Guardá y restaurá tus datos',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
            trailing: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _loading ? null : _backup,
                  icon: Icon(Icons.upload_rounded, size: 16, color: color),
                  label: Text('Hacer backup', style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.05)),
              Expanded(
                child: TextButton.icon(
                  onPressed: _loading ? null : _restore,
                  icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white54),
                  label: Text('Restaurar', style: GoogleFonts.inter(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Settings Row (List)
// ─────────────────────────────────────────────
Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _DonationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DonationRow({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
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
            Icon(Icons.open_in_new_rounded,
                color: Colors.white.withValues(alpha: 0.2), size: 16),
          ],
        ),
      ),
    );
  }
}

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
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                      fontSize: 14,
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
