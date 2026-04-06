import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../core/services/notification_service.dart';
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
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
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
            const SliverToBoxAdapter(child: MyQrCard()),

            // ── Resumen financiero compacto ──
            SliverToBoxAdapter(child: _CompactBalanceCard()),

            // ── Insights rápidos ──
            SliverToBoxAdapter(child: _InsightsSection()),

            // ── Accesos rápidos (grid 4x2 compacto) ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'ACCESOS RÁPIDOS',
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
              sliver: SliverGrid.count(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
                children: [
                  _QuickTool(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Movimientos',
                    color: AppTheme.colorTransfer,
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const TransactionsPage(standalone: true),
                      ),
                    ),
                  ),
                  _QuickTool(
                    icon: Icons.donut_large_rounded,
                    label: 'Presupuestos',
                    color: AppTheme.colorWarning,
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const BudgetPage(standalone: true),
                      ),
                    ),
                  ),
                  _QuickTool(
                    icon: Icons.calendar_month_rounded,
                    label: 'Mes',
                    color: AppTheme.colorTransfer,
                    onTap: () => context.push('/monthly_overview'),
                  ),
                  _QuickTool(
                    icon: Icons.people_rounded,
                    label: 'Amigos',
                    color: AppTheme.colorIncome,
                    onTap: () => context.push('/people'),
                  ),
                  _QuickTool(
                    icon: Icons.shopping_cart_rounded,
                    label: 'Antojos',
                    color: AppTheme.colorWarning,
                    onTap: () => context.push('/wishlist'),
                  ),
                  _QuickTool(
                    icon: Icons.bar_chart_rounded,
                    label: 'Análisis',
                    color: AppTheme.colorExpense,
                    onTap: () => context.push('/reports'),
                  ),
                  _QuickTool(
                    icon: Icons.account_balance_rounded,
                    label: 'Cuentas',
                    color: AppTheme.colorIncome,
                    onTap: () => context.push('/accounts'),
                  ),
                  _QuickTool(
                    icon: Icons.savings_rounded,
                    label: 'Ahorros',
                    color: AppTheme.colorTransfer,
                    onTap: () => context.push('/savings'),
                  ),
                ],
              ),
            ),

            // ── Configuración section (lista compacta) ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
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
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      _NotificationRow(ref: ref),
                      _divider(),
                      _CompactRow(
                        icon: Icons.settings_rounded,
                        label: 'Ajustes generales',
                        color: AppTheme.colorNeutral,
                        onTap: () => context.push('/settings'),
                      ),
                      _divider(),
                      _CompactRow(
                        icon: Icons.tab_rounded,
                        label: 'Personalizar navegación',
                        color: AppTheme.colorTransfer,
                        onTap: () => showTabConfigSheet(context, ref),
                      ),
                      _divider(),
                      _CompactRow(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Ayuda y Tutorial',
                        color: const Color(0xFF6C63FF),
                        onTap: () => showHelpSheet(context),
                      ),
                      _divider(),
                      _CompactRow(
                        icon: Icons.rocket_launch_rounded,
                        label: 'Novedades',
                        subtitle: 'Versión actual: v1.5.5',
                        color: AppTheme.colorIncome,
                        onTap: () => context.push('/novedades'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Backup ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(child: _BackupRow()),
            ),

            // ── Apoyar el proyecto ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
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
                        const Color(0xFFf5a623).withValues(alpha: 0.06),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFf5a623).withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      _CompactRow(
                        icon: Icons.local_cafe_rounded,
                        label: 'Cafecito',
                        subtitle: 'cafecito.app/david-t',
                        color: const Color(0xFFf5a623),
                        trailing: Icons.open_in_new_rounded,
                        onTap: () => _launchUrl('https://cafecito.app/david-t'),
                      ),
                      _divider(),
                      _CompactRow(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Mercado Pago',
                        subtitle: 'Alias: david.taranto',
                        color: const Color(0xFF009ee3),
                        trailing: Icons.copy_rounded,
                        onTap: () {
                          Clipboard.setData(const ClipboardData(text: 'david.taranto'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Alias copiado: david.taranto'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      _divider(),
                      _CompactRow(
                        icon: Icons.code_rounded,
                        label: 'GitHub',
                        subtitle: 'github.com/davidtaranto96',
                        color: Colors.white60,
                        trailing: Icons.open_in_new_rounded,
                        onTap: () => _launchUrl('https://github.com/davidtaranto96'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Cerrar sesión ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _CompactRow(
                  icon: Icons.logout_rounded,
                  label: 'Cerrar sesión',
                  color: AppTheme.colorExpense,
                  standalone: true,
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
              ),
            ),

            // ── Versión ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Center(
                  child: GestureDetector(
                    onTap: () => context.push('/novedades'),
                    child: Text(
                      'Sencillo · v1.5.5',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.20),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

Widget _divider() => Divider(height: 1, color: Colors.white.withValues(alpha: 0.04), indent: 48);

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─────────────────────────────────────────────
// Compact Balance Card (más chico)
// ─────────────────────────────────────────────
class _CompactBalanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final safeBudget = ref.watch(safeBudgetProvider);

    final liquidAccounts = accounts.where((a) => !a.isCreditCard).toList();
    final availableMoney = liquidAccounts.fold(0.0, (sum, a) => sum + a.balance);
    final creditCards = accounts.where((a) => a.isCreditCard).toList();
    final totalCardDebt = creditCards.fold(0.0, (sum, a) => sum + a.totalDebt);

    final isPositive = availableMoney >= 0;
    final color = isPositive ? AppTheme.colorIncome : AppTheme.colorExpense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Disponible', style: GoogleFonts.inter(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    formatAmount(availableMoney),
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: isPositive ? Colors.white : color),
                  ),
                ],
              ),
            ),
            if (totalCardDebt > 0) ...[
              Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.06)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Deuda TC', style: GoogleFonts.inter(fontSize: 10, color: Colors.white30)),
                  Text(formatAmount(totalCardDebt, compact: true),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.colorExpense)),
                ],
              ),
            ],
            if (safeBudget > 0) ...[
              const SizedBox(width: 14),
              Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.06)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Seguro', style: GoogleFonts.inter(fontSize: 10, color: Colors.white30)),
                  Text(formatAmount(safeBudget, compact: true),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.colorIncome)),
                ],
              ),
            ],
          ],
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: insights.take(2).map((ins) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _InsightTile(data: ins),
            )).toList(),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: data.color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Text(data.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data.text,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 14, color: data.color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quick Tool (grid compacto 4 columnas)
// ─────────────────────────────────────────────
class _QuickTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickTool({
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Compact Row (para listas agrupadas)
// ─────────────────────────────────────────────
class _CompactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final IconData? trailing;
  final bool standalone;

  const _CompactRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
    this.trailing,
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
                ],
              ),
            ),
            Icon(trailing ?? Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.18), size: 16),
          ],
        ),
      ),
    );

    if (standalone) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: content,
      );
    }
    return content;
  }
}

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
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Iniciá sesión para hacer backup en la nube')),
        );
      }
      return;
    }
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
        final msg = e.toString();
        if (msg.contains('unauthorized') || msg.contains('permission')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error de permisos. Configurá las reglas de Firebase Storage en la consola.'),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $msg')),
          );
        }
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
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.cloud_rounded, color: color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Backup en la nube',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
                if (_loading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.04)),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _loading ? null : _backup,
                  icon: Icon(Icons.upload_rounded, size: 14, color: color),
                  label: Text('Subir', style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.04)),
              Expanded(
                child: TextButton.icon(
                  onPressed: _loading ? null : _restore,
                  icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white54),
                  label: Text('Restaurar', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Notification bell row with badge
// ─────────────────────────────────────────────
class _NotificationRow extends ConsumerWidget {
  final WidgetRef ref;
  const _NotificationRow({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return InkWell(
      onTap: () => context.push('/notifications'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.colorWarning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.notifications_rounded,
                  size: 18, color: AppTheme.colorWarning),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Notificaciones',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            if (unread > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.colorExpense,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
