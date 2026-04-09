import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/wishlist_service.dart';
import '../../../../core/logic/budget_service.dart';
import '../../../../core/providers/price_tracker_provider.dart';
import '../../../../core/services/meli_price_service.dart';

import '../../../../core/utils/format_utils.dart';
import '../../../../core/providers/shell_providers.dart';
import '../../../budget/domain/models/budget.dart' as dom_b;
import '../../domain/models/wishlist_item.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/add_wishlist_bottom_sheet.dart';
import '../widgets/purchase_bottom_sheet.dart';
import '../widgets/wishlist_budget_sheet.dart';

class WishlistPage extends ConsumerWidget {
  /// [standalone] = true when pushed on top of the shell (from Más, router).
  /// In standalone mode the page shows its own FAB.
  final bool standalone;
  const WishlistPage({super.key, this.standalone = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeWishlistProvider);
    final hourlyRate = ref.watch(hourlyRateProvider);
    final globalReminderDays = ref.watch(globalReminderDaysProvider);
    final budgets = ref.watch(budgetsStreamProvider).valueOrNull ?? [];
    final shoppingBudget =
        budgets.where((b) => b.categoryId == 'shopping').firstOrNull;
    final priceDrops = ref.watch(priceDropAlertsProvider);

    // Trigger auto-check when page loads with items
    final items = itemsAsync.valueOrNull ?? [];
    if (items.isNotEmpty) {
      // Use Future.microtask to avoid calling during build
      Future.microtask(() => _autoCheckPrices(ref, items));
    }

    return Scaffold(
      floatingActionButton: standalone
          ? FloatingActionButton(
              onPressed: () => AddWishlistBottomSheet.show(context),
              backgroundColor: AppTheme.colorWarning,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      appBar: AppBar(
        title: Text(
          'Compras Inteligentes',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (items.any((i) => i.url != null && MeliPriceService.extractItemId(i.url ?? '') != null))
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Actualizar precios MeLi',
              onPressed: () => _forceCheckPrices(context, ref, items),
            ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState(shoppingBudget: shoppingBudget);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            physics: const BouncingScrollPhysics(),
            itemCount: items.length + 1 + (priceDrops.isNotEmpty ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              // Price drop alert banner
              if (priceDrops.isNotEmpty && index == 0) {
                return _PriceDropBanner(drops: priceDrops, onDismiss: () {
                  ref.read(priceDropAlertsProvider.notifier).state = [];
                });
              }

              final adjustedIndex = priceDrops.isNotEmpty ? index - 1 : index;

              if (adjustedIndex == 0) {
                return _ShoppingBudgetCard(budget: shoppingBudget);
              }
              final item = items[adjustedIndex - 1];

              // Find linked budget progress
              double? budgetSpent;
              double? budgetLimit;
              if (item.linkedBudgetId != null) {
                final budget = budgets
                    .where((b) => b.id == item.linkedBudgetId)
                    .firstOrNull;
                if (budget != null) {
                  budgetSpent = budget.spentAmount;
                  budgetLimit = budget.limitAmount;
                }
              }

              return _WishlistCard(
                item: item,
                hourlyRate: hourlyRate,
                globalReminderDays: globalReminderDays,
                budgetSpent: budgetSpent,
                budgetLimit: budgetLimit,
              );
            },
          );
        },
      ),
    );
  }

  static bool _autoCheckTriggered = false;

  Future<void> _autoCheckPrices(WidgetRef ref, List<WishlistItem> items) async {
    if (_autoCheckTriggered) return;
    _autoCheckTriggered = true;
    try {
      final drops = await ref.read(priceTrackerProvider.notifier).autoCheckPrices(items);
      if (drops.isNotEmpty) {
        ref.read(priceDropAlertsProvider.notifier).state = drops;
      }
    } catch (_) {}
  }

  Future<void> _forceCheckPrices(BuildContext context, WidgetRef ref, List<WishlistItem> items) async {
    _autoCheckTriggered = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('price_tracker_last_auto_check');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Actualizando precios de MercadoLibre...'),
          backgroundColor: AppTheme.colorWarning.withValues(alpha: 0.8),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final drops = await ref.read(priceTrackerProvider.notifier).autoCheckPrices(items);
    if (drops.isNotEmpty) {
      ref.read(priceDropAlertsProvider.notifier).state = drops;
    }
    if (context.mounted) {
      final meliCount = items.where((i) => i.url != null && MeliPriceService.extractItemId(i.url ?? '') != null).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(drops.isNotEmpty
              ? '${drops.length} producto${drops.length > 1 ? 's' : ''} bajó de precio!'
              : '$meliCount precios actualizados'),
          backgroundColor: drops.isNotEmpty
              ? const Color(0xFF4CAF50).withValues(alpha: 0.8)
              : AppTheme.colorWarning.withValues(alpha: 0.8),
        ),
      );
    }
  }
}

// ─── Price Drop Banner ──────────────────────────────────────

class _PriceDropBanner extends StatelessWidget {
  final List<PriceDropAlert> drops;
  final VoidCallback onDismiss;
  const _PriceDropBanner({required this.drops, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0, locale: 'es_AR');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withValues(alpha: 0.15),
            const Color(0xFF4CAF50).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_down_rounded, color: Color(0xFF4CAF50), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${drops.length} producto${drops.length > 1 ? 's bajaron' : ' bajó'} de precio!',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close_rounded, color: Colors.white30, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...drops.take(3).map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 26),
                Expanded(
                  child: Text(d.itemTitle,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${fmt.format(d.oldPrice)} → ${fmt.format(d.newPrice)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final dom_b.Budget? shoppingBudget;

  const _EmptyState({this.shoppingBudget});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      physics: const BouncingScrollPhysics(),
      children: [
        _ShoppingBudgetCard(budget: shoppingBudget),
        const SizedBox(height: 48),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.colorWarning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_cart_outlined,
                    size: 48,
                    color: AppTheme.colorWarning.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 20),
              Text(
                'Tu lista está vacía',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Agregá algo que quieras comprar\npara tomar decisiones más inteligentes.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shopping Budget Card ────────────────────────────────────

class _ShoppingBudgetCard extends ConsumerWidget {
  final dom_b.Budget? budget;
  const _ShoppingBudgetCard({this.budget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (budget != null) {
      final spent = budget!.spentAmount;
      final limit = budget!.limitAmount;
      final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
      final remaining = (limit - spent).clamp(0.0, double.infinity);
      final fmt = NumberFormat.currency(
          symbol: '\$', decimalDigits: 0, locale: 'es_AR');

      return GestureDetector(
        onTap: () =>
            ref.read(navigateToTabProvider.notifier).state = 'budget',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.colorWarning.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.colorWarning.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              // Mini progress circle
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      color: progress >= 1.0
                          ? AppTheme.colorExpense
                          : AppTheme.colorWarning,
                    ),
                    Icon(Icons.shopping_bag_rounded,
                        color: AppTheme.colorWarning, size: 14),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Presupuesto de Compras',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text(
                      '${fmt.format(spent)} / ${fmt.format(limit)}',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                fmt.format(remaining),
                style: TextStyle(
                  color: remaining > 0
                      ? AppTheme.colorIncome
                      : AppTheme.colorExpense,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 16),
            ],
          ),
        ),
      );
    }

    // No shopping budget — compact create row
    return GestureDetector(
      onTap: () => _createShoppingBudget(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.colorWarning.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.colorWarning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add_rounded,
                  color: AppTheme.colorWarning, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Crear Presupuesto de Compras',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _createShoppingBudget(
      BuildContext context, WidgetRef ref) async {
    final amountController = TextEditingController();

    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.shopping_bag_rounded,
                color: AppTheme.colorWarning, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Presupuesto de Compras',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Cuánto querés destinar por mes a compras?',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorFormatter()],
              autofocus: true,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: TextStyle(
                    color: AppTheme.colorWarning,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
                hintText: '50.000',
                hintStyle: const TextStyle(color: Colors.white24),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppTheme.colorWarning),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () {
              final val = parseFormattedAmount(amountController.text);
              if (val > 0) Navigator.pop(ctx, val);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorWarning),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (amount != null && amount > 0) {
      try {
        await ref.read(budgetServiceProvider).addBudgetForCategory(
              categoryId: 'shopping',
              categoryName: 'Compras',
              limitAmount: amount,
              isFixed: false,
              colorValue: AppTheme.colorWarning.toARGB32(),
              iconKey: 'shopping_bag',
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Presupuesto de compras creado'),
              backgroundColor:
                  AppTheme.colorWarning.withValues(alpha: 0.8),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

// ─── Wishlist Card ────────────────────────────────────────────

class _WishlistCard extends ConsumerWidget {
  final WishlistItem item;
  final double? hourlyRate;
  final int globalReminderDays;
  final double? budgetSpent;
  final double? budgetLimit;

  const _WishlistCard({
    required this.item,
    required this.hourlyRate,
    required this.globalReminderDays,
    this.budgetSpent,
    this.budgetLimit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.compactCurrency(
        symbol: '\$', decimalDigits: 1, locale: 'es_AR');
    final now = DateTime.now();
    final daysPassed = now.difference(item.createdAt).inDays;
    final effectiveReminderDays = item.reminderDays ?? globalReminderDays;
    final isSnoozed = item.reminderSnoozedUntil != null &&
        now.isBefore(item.reminderSnoozedUntil!);
    final showReminder = daysPassed >= effectiveReminderDays &&
        !item.reminderDismissed &&
        !isSnoozed;
    final workHours =
        hourlyRate != null ? (item.estimatedCost / hourlyRate!).ceil() : null;
    final hasBudget = budgetSpent != null && budgetLimit != null;
    final savingsProgress =
        hasBudget && budgetLimit! > 0
            ? (budgetSpent! / budgetLimit!).clamp(0.0, 1.0)
            : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: showReminder
              ? AppTheme.colorWarning.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: showReminder ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reminder banner
          if (showReminder)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.colorWarning.withValues(alpha: 0.12),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.psychology_alt_rounded,
                      color: AppTheme.colorWarning, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hace $daysPassed días. ¿Realmente lo necesitás?',
                      style: GoogleFonts.inter(
                        color: AppTheme.colorWarning,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref
                        .read(wishlistServiceProvider)
                        .snoozeReminder(
                            item.id, Duration(days: effectiveReminderDays)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.colorWarning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Posponer',
                          style: TextStyle(
                              color: AppTheme.colorWarning,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => ref
                        .read(wishlistServiceProvider)
                        .dismissReminder(item.id),
                    child: Icon(Icons.close_rounded,
                        color: AppTheme.colorWarning.withValues(alpha: 0.5),
                        size: 14),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: Title + actions ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => AddWishlistBottomSheet.show(context, itemToEdit: item),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.edit_rounded, color: Colors.white24, size: 16),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref.read(wishlistServiceProvider).deleteItem(item.id),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, color: Colors.white24, size: 16),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ── Price + work hours ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      fmt.format(item.estimatedCost),
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.colorExpense,
                      ),
                    ),
                    if (workHours != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '${workHours}h de trabajo',
                        style: const TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                    ],
                  ],
                ),

                // ── Installments + promo ──
                if (item.installments > 1 || item.hasPromo) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (item.installments > 1)
                        Text(
                          '${item.installments} cuotas de ${NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(item.estimatedCost / item.installments)}',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      if (item.installments > 1 && item.hasPromo)
                        Text('  ·  ', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      if (item.hasPromo)
                        Text('En promo', style: TextStyle(color: const Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],

                // ── Note ──
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.note!,
                      style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic)),
                ],

                const SizedBox(height: 14),

                // ── Action row: Link + Savings + History ──
                Row(
                  children: [
                    // Link button (opens URL directly)
                    if (item.url != null && item.url!.isNotEmpty) ...[
                      _LinkButton(url: item.url!),
                      const SizedBox(width: 8),
                    ],

                    // Savings indicator
                    GestureDetector(
                      onTap: hasBudget
                          ? () => ref.read(navigateToTabProvider.notifier).state = 'budget'
                          : () => WishlistBudgetSheet.show(context, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: hasBudget
                              ? AppTheme.colorTransfer.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasBudget
                                ? AppTheme.colorTransfer.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasBudget)
                              SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  value: savingsProgress,
                                  strokeWidth: 2,
                                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                                  color: AppTheme.colorTransfer,
                                ),
                              )
                            else
                              Icon(Icons.savings_outlined, size: 16, color: Colors.white30),
                            const SizedBox(width: 6),
                            Text(
                              hasBudget ? '${(savingsProgress * 100).toInt()}%' : 'Ahorrar',
                              style: TextStyle(
                                color: hasBudget ? AppTheme.colorTransfer : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Price history button
                    _PriceHistoryButton(item: item),

                    const Spacer(),

                    // Buy button — icon only to avoid overflow
                    GestureDetector(
                      onTap: () => PurchaseBottomSheet.show(context, item),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.colorWarning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.colorWarning.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.shopping_cart_checkout_rounded, size: 18, color: AppTheme.colorWarning),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Price History ───────────────────────────────────

class _PriceHistoryButton extends ConsumerWidget {
  final WishlistItem item;
  const _PriceHistoryButton({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(priceTrackerProvider);
    final history = tracker[item.id];
    final hasEntries = history != null && history.entries.isNotEmpty;
    final hasDrop = history?.hasDrop ?? false;

    final color = hasDrop ? const Color(0xFF4CAF50) : Colors.white38;

    return GestureDetector(
      onTap: () => _showPriceHistorySheet(context, ref, item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hasDrop
              ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDrop
                ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasEntries ? Icons.timeline_rounded : Icons.add_chart_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              hasEntries
                  ? (hasDrop ? '↓ Bajó' : '${history!.entries.length} precios')
                  : 'Historial',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

void _showPriceHistorySheet(BuildContext context, WidgetRef ref, WishlistItem item) {
  final ctrl = TextEditingController();
  final fmt = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0, locale: 'es_AR');
  final dateFmt = DateFormat('dd/MM', 'es');

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF18181F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final tracker = ref.watch(priceTrackerProvider);
        final history = tracker[item.id];
        final entries = history?.entries ?? [];

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('Historial de precios',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(item.title,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                textAlign: TextAlign.center,
              ),

              // Stats row
              if (entries.length >= 2) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCol('Mínimo', fmt.format(history!.lowestPrice!), const Color(0xFF4CAF50)),
                      _StatCol('Último', fmt.format(history.latestPrice!), Colors.white70),
                      _StatCol('Máximo', fmt.format(history.highestPrice!), AppTheme.colorExpense),
                    ],
                  ),
                ),
              ],

              // Price list
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    reverse: true,
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final prev = i > 0 ? entries[i - 1] : null;
                      final diff = prev != null ? e.price - prev.price : null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(dateFmt.format(e.date), style: TextStyle(color: Colors.white30, fontSize: 12)),
                            const SizedBox(width: 12),
                            Text(fmt.format(e.price), style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            if (diff != null && diff != 0) ...[
                              const SizedBox(width: 8),
                              Icon(
                                diff < 0 ? Icons.arrow_drop_down_rounded : Icons.arrow_drop_up_rounded,
                                color: diff < 0 ? const Color(0xFF4CAF50) : AppTheme.colorExpense,
                                size: 20,
                              ),
                              Text(
                                fmt.format(diff.abs()),
                                style: TextStyle(
                                  color: diff < 0 ? const Color(0xFF4CAF50) : AppTheme.colorExpense,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              e.source == 'meli' ? 'MeLi' : 'Manual',
                              style: TextStyle(color: Colors.white24, fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                Text('Sin registros todavía', style: TextStyle(color: Colors.white24, fontSize: 13)),
                Text('Anotá el precio cada vez que lo mires', style: TextStyle(color: Colors.white.withValues(alpha: 0.16), fontSize: 11)),
              ],

              // Add price input
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: AppTheme.colorWarning, fontSize: 18, fontWeight: FontWeight.w700),
                        hintText: 'Precio actual',
                        hintStyle: const TextStyle(color: Colors.white24),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.colorWarning),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.colorWarning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final val = double.tryParse(ctrl.text.replaceAll('.', '').replaceAll(',', '.'));
                      if (val != null && val > 0) {
                        ref.read(priceTrackerProvider.notifier).logPrice(item.id, val);
                        if (val != item.estimatedCost) {
                          ref.read(wishlistServiceProvider).updateItem(item.id, estimatedCost: val);
                        }
                        ctrl.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Precio registrado: ${fmt.format(val)}'),
                            backgroundColor: AppTheme.colorWarning.withValues(alpha: 0.8),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCol(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ─── Action Buttons ──────────────────────────────────

/// Link button — opens URL directly. Shows "MeLi" for MercadoLibre, "Ver" for others.
class _LinkButton extends StatelessWidget {
  final String url;
  const _LinkButton({required this.url});

  bool get _isMeli =>
      url.contains('mercadolibre') || url.contains('meli');

  @override
  Widget build(BuildContext context) {
    final isMeli = _isMeli;
    final color = isMeli ? const Color(0xFFFFE600) : Colors.white38;
    final textColor = isMeli ? Colors.black87 : Colors.white60;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el link')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isMeli ? 0.15 : 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: isMeli ? 0.4 : 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMeli ? Icons.store_rounded : Icons.open_in_new_rounded,
              color: textColor,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              isMeli ? 'MeLi' : 'Ver',
              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

