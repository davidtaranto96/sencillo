import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/transaction_service.dart';
import '../../../../core/logic/wishlist_service.dart';
import '../../../../core/logic/financial_logic.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../accounts/domain/models/account.dart' as dom_acc;
import '../../domain/models/wishlist_item.dart';

class PurchaseBottomSheet extends ConsumerStatefulWidget {
  final WishlistItem item;
  const PurchaseBottomSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, WishlistItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PurchaseBottomSheet(item: item),
    );
  }

  @override
  ConsumerState<PurchaseBottomSheet> createState() => _PurchaseBottomSheetState();
}

class _PurchaseBottomSheetState extends ConsumerState<PurchaseBottomSheet> {
  String _method = 'account'; // 'account', 'regalo'
  dom_acc.Account? _selectedAccount;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? [];
    final safeBudget = ref.watch(safeBudgetProvider);
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR');
    final cost = widget.item.estimatedCost;
    final overBudget = cost > safeBudget;

    if (_selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.firstWhere(
        (a) => a.isDefault,
        orElse: () => accounts.first,
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(
        24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Icon(Icons.shopping_cart_checkout_rounded,
                    color: AppTheme.colorWarning, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Comprar: ${widget.item.title}',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fmt.format(cost),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.colorExpense,
              ),
            ),

            if (overBudget) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.colorExpense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.colorExpense.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.colorExpense, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Supera tu presupuesto libre (${fmt.format(safeBudget)})',
                        style: TextStyle(
                          color: AppTheme.colorExpense,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Method selection
            Text('¿Cómo lo compraste?',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            // Method toggles
            Row(
              children: [
                Expanded(
                  child: _MethodChip(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Cuenta / Tarjeta',
                    isSelected: _method == 'account',
                    color: AppTheme.colorTransfer,
                    onTap: () => setState(() => _method = 'account'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MethodChip(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Fue un regalo',
                    isSelected: _method == 'regalo',
                    color: AppTheme.colorIncome,
                    onTap: () => setState(() => _method = 'regalo'),
                  ),
                ),
              ],
            ),

            // Account selector (only for 'account' method)
            if (_method == 'account' && accounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Desde qué cuenta',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: accounts.map((acc) {
                  final isSelected = _selectedAccount?.id == acc.id;
                  final color = isSelected
                      ? AppTheme.colorTransfer
                      : Colors.white;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAccount = acc),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? color.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            acc.isCreditCard
                                ? Icons.credit_card_rounded
                                : Icons.account_balance_wallet_outlined,
                            color: isSelected ? color : Colors.white38,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            acc.name,
                            style: TextStyle(
                              color: isSelected ? color : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (acc.isCreditCard) ...[
                            const SizedBox(width: 6),
                            Text(
                              formatAmount(acc.availableCredit, compact: true),
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 28),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.colorWarning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _method == 'regalo' ? 'Registrar como regalo' : 'Confirmar compra',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    final item = widget.item;
    final ws = ref.read(wishlistServiceProvider);

    try {
      if (_method == 'regalo') {
        await ws.markAsPurchased(item.id, method: 'regalo');
      } else {
        if (_selectedAccount == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seleccioná una cuenta')),
          );
          return;
        }

        // Determine category: use budget's category if linked, else 'shopping'
        String categoryId = 'shopping';
        if (item.linkedBudgetId != null) {
          final budget = await (ref.read(databaseProvider)
                  .select(ref.read(databaseProvider).budgetsTable)
                ..where((t) => t.id.equals(item.linkedBudgetId!)))
              .getSingleOrNull();
          if (budget != null) {
            categoryId = budget.categoryId;
          }
        }

        await ref.read(transactionServiceProvider).addTransaction(
          title: 'Compra: ${item.title}',
          amount: item.estimatedCost,
          type: 'expense',
          categoryId: categoryId,
          accountId: _selectedAccount!.id,
          note: 'Compra Inteligente',
        );

        await ws.markAsPurchased(
          item.id,
          method: 'account',
          accountId: _selectedAccount!.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_method == 'regalo'
                ? '¡Regalo registrado!'
                : '¡Compra registrada!'),
            backgroundColor: AppTheme.colorIncome.withValues(alpha: 0.8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _MethodChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _MethodChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.white24, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white38,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
