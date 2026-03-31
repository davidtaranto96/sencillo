import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/wishlist_item.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/add_wishlist_bottom_sheet.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(mockWishlistProvider);
    final hourlyRate = ref.watch(mockHourlyRateProvider);
    final safeBudget = ref.watch(safeBudgetProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Compras Inteligentes',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length + 1, // +1 for the top banner
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SafeBudgetBanner(budget: safeBudget);
          }
          final itemIndex = index - 1;
          return _WishlistCard(
            item: items[itemIndex],
            hourlyRate: hourlyRate,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddWishlistBottomSheet.show(context),
        backgroundColor: AppTheme.colorWarning,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_shopping_cart_rounded),
      ),
    );
  }
}

class _SafeBudgetBanner extends StatelessWidget {
  final double budget;
  const _SafeBudgetBanner({required this.budget});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR');
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.colorTransfer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, color: AppTheme.colorTransfer),
              const SizedBox(width: 8),
              const Text('Presupuesto Libre Seguro', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(budget),
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.colorTransfer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sin comprometer alquiler, servicios ni deudas. Podés usar esta plata sin quedar en rojo.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _WishlistCard extends ConsumerWidget {
  final WishlistItem item;
  final double hourlyRate;

  const _WishlistCard({required this.item, required this.hourlyRate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 1, locale: 'es_AR');
    final cs = Theme.of(context).colorScheme;
    
    final daysPassed = DateTime.now().difference(item.createdAt).inDays;
    final isStale = daysPassed >= 7;
    final workHours = (item.estimatedCost / hourlyRate).ceil();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isStale ? AppTheme.colorWarning.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
          width: isStale ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isStale)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.colorWarning.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Icon(Icons.psychology_alt_rounded, color: AppTheme.colorWarning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lo guardaste hace $daysPassed días. ¿Realmente lo necesitás?',
                      style: GoogleFonts.inter(
                        color: AppTheme.colorWarning,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white54, size: 20),
                      onPressed: () => AddWishlistBottomSheet.show(context, itemToEdit: item),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      fmt.format(item.estimatedCost),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.colorExpense,
                      ),
                    ),
                  ],
                ),
                // Chips de info: cuotas, promo, link
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (item.installments > 1)
                      _InfoChip(
                        icon: Icons.credit_card_rounded,
                        label: '${item.installments} cuotas de ${NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0, locale: 'es_AR').format(item.estimatedCost / item.installments)}',
                        color: AppTheme.colorTransfer,
                      ),
                    if (item.hasPromo)
                      _InfoChip(
                        icon: Icons.local_offer_rounded,
                        label: 'Con promo',
                        color: const Color(0xFF4CAF50),
                      ),
                    if (item.url != null && item.url!.isNotEmpty)
                      _UrlChip(url: item.url!),
                  ],
                ),
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.note!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                
                // Horas de vida / trabajo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: AppTheme.colorNeutral, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Te cuesta $workHours horas de tu vida',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Calculado a \$${hourlyRate.toInt()}/hr',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Descartar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          ref.read(mockWishlistProvider.notifier).remove(item.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ítem descartado')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Comprar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.colorWarning,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final currentBudget = ref.read(safeBudgetProvider);
                          ref.read(safeBudgetProvider.notifier).state = currentBudget - item.estimatedCost;
                          ref.read(mockWishlistProvider.notifier).remove(item.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('¡A comprar se ha dicho!')),
                          );
                        },
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

// ─── Chips de info ────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _UrlChip extends StatelessWidget {
  final String url;
  const _UrlChip({required this.url});

  bool get _isMercadoLibre =>
      url.contains('mercadolibre') || url.contains('meli') || url.contains('mercadopago');

  @override
  Widget build(BuildContext context) {
    final color = _isMercadoLibre ? const Color(0xFFFFE600) : AppTheme.colorWarning;
    final textColor = _isMercadoLibre ? Colors.black87 : Colors.white;
    final label = _isMercadoLibre ? 'Ver en Mercado Libre' : 'Ver producto';
    final icon = _isMercadoLibre ? Icons.store_rounded : Icons.open_in_new_rounded;

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
