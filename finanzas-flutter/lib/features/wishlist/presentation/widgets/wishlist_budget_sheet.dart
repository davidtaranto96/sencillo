import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/logic/budget_service.dart';
import '../../../../core/logic/wishlist_service.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/models/wishlist_item.dart';

class WishlistBudgetSheet extends ConsumerWidget {
  final WishlistItem item;
  const WishlistBudgetSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, WishlistItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WishlistBudgetSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetName = 'Ahorro: ${item.title}';

    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
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
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Icon(Icons.savings_rounded, color: AppTheme.colorTransfer, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Crear presupuesto de ahorro',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.colorTransfer.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.colorTransfer.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  budgetName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.flag_rounded,
                        color: AppTheme.colorTransfer, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Meta: ${formatAmount(item.estimatedCost)}',
                      style: TextStyle(
                        color: AppTheme.colorTransfer,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Se creará un presupuesto que trackea tus gastos hacia esta compra. '
                  'Cada gasto en esta categoría se descontará del objetivo.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Crear presupuesto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () async {
                try {
                  final budgetId = await ref
                      .read(budgetServiceProvider)
                      .addBudget(
                        categoryName: budgetName,
                        limitAmount: item.estimatedCost,
                        isFixed: true,
                        colorValue: AppTheme.colorTransfer.toARGB32(),
                        iconKey: 'savings',
                      );

                  await ref
                      .read(wishlistServiceProvider)
                      .linkBudget(item.id, budgetId);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Presupuesto "$budgetName" creado'),
                        backgroundColor:
                            AppTheme.colorTransfer.withValues(alpha: 0.8),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
