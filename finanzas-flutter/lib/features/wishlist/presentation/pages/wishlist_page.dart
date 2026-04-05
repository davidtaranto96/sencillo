import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/wishlist_service.dart';
import '../../../../core/logic/budget_service.dart';

import '../../../../core/utils/format_utils.dart';
import '../../../../core/providers/shell_providers.dart';
import '../../../budget/domain/models/budget.dart' as dom_b;
import '../../domain/models/wishlist_item.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/add_wishlist_bottom_sheet.dart';
import '../widgets/purchase_bottom_sheet.dart';
import '../widgets/wishlist_budget_sheet.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeWishlistProvider);
    final hourlyRate = ref.watch(hourlyRateProvider);
    final globalReminderDays = ref.watch(globalReminderDaysProvider);
    final budgets = ref.watch(budgetsStreamProvider).valueOrNull ?? [];
    final shoppingBudget =
        budgets.where((b) => b.categoryId == 'shopping').firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Compras Inteligentes',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            itemCount: items.length + 1, // +1 for shopping budget
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ShoppingBudgetCard(budget: shoppingBudget);
              }
              final item = items[index - 1];

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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with X discard + edit
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                fmt.format(item.estimatedCost),
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.colorExpense,
                                ),
                              ),
                              if (workHours != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${workHours}h de trabajo',
                                    style: const TextStyle(
                                      color: Colors.white30,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Edit icon
                    GestureDetector(
                      onTap: () => AddWishlistBottomSheet.show(context,
                          itemToEdit: item),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.edit_rounded,
                            color: Colors.white24, size: 16),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // X discard icon
                    GestureDetector(
                      onTap: () => ref
                          .read(wishlistServiceProvider)
                          .deleteItem(item.id),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            color: Colors.white24, size: 16),
                      ),
                    ),
                  ],
                ),

                // Info chips
                if (item.installments > 1 ||
                    item.hasPromo ||
                    (item.url != null && item.url!.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.installments > 1)
                        _InfoChip(
                          icon: Icons.credit_card_rounded,
                          label:
                              '${item.installments}x ${NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(item.estimatedCost / item.installments)}',
                          color: AppTheme.colorTransfer,
                        ),
                      if (item.hasPromo)
                        _InfoChip(
                          icon: Icons.local_offer_rounded,
                          label: 'Promo',
                          color: const Color(0xFF4CAF50),
                        ),
                      if (item.url != null && item.url!.isNotEmpty)
                        _UrlChip(url: item.url!),
                    ],
                  ),
                ],

                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.note!,
                      style: TextStyle(color: Colors.white30, fontSize: 11)),
                ],

                if (hourlyRate == null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: Text(
                      'Configurá tu sueldo para ver horas de trabajo →',
                      style: TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Action row: Savings indicator + Buy button
                Row(
                  children: [
                    // Savings piggy bank (tap to create/view)
                    GestureDetector(
                      onTap: hasBudget
                          ? () => ref
                              .read(navigateToTabProvider.notifier)
                              .state = 'budget'
                          : () => WishlistBudgetSheet.show(context, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: hasBudget
                              ? AppTheme.colorTransfer
                                  .withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasBudget
                                ? AppTheme.colorTransfer
                                    .withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Mini piggy bank with fill
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (hasBudget)
                                    CircularProgressIndicator(
                                      value: savingsProgress,
                                      strokeWidth: 2.5,
                                      backgroundColor: Colors.white
                                          .withValues(alpha: 0.06),
                                      color: AppTheme.colorTransfer,
                                    ),
                                  Icon(
                                    Icons.savings_rounded,
                                    size: hasBudget ? 12 : 16,
                                    color: hasBudget
                                        ? AppTheme.colorTransfer
                                        : Colors.white24,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasBudget
                                  ? '${(savingsProgress * 100).toInt()}%'
                                  : 'Ahorrar',
                              style: TextStyle(
                                color: hasBudget
                                    ? AppTheme.colorTransfer
                                    : Colors.white30,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Buy button
                    FilledButton.icon(
                      icon: const Icon(
                          Icons.shopping_cart_checkout_rounded,
                          size: 15),
                      label: const Text('Comprar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.colorWarning,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () =>
                          PurchaseBottomSheet.show(context, item),
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

// ─── Chips ────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _UrlChip extends StatelessWidget {
  final String url;
  const _UrlChip({required this.url});

  bool get _isMercadoLibre =>
      url.contains('mercadolibre') ||
      url.contains('meli') ||
      url.contains('mercadopago');

  @override
  Widget build(BuildContext context) {
    final color =
        _isMercadoLibre ? const Color(0xFFFFE600) : AppTheme.colorWarning;
    final textColor = _isMercadoLibre ? Colors.black87 : Colors.white;
    final label = _isMercadoLibre ? 'MeLi' : 'Ver';
    final icon =
        _isMercadoLibre ? Icons.store_rounded : Icons.open_in_new_rounded;

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 12),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
