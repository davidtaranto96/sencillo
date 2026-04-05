import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/mercado_pago_provider.dart';

/// Widget compacto para el Home que muestra info de Mercado Pago
class MpHomeCard extends ConsumerWidget {
  const MpHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(mpConnectedProvider);

    return isConnected.when(
      data: (connected) => connected ? const _MpConnectedCard() : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MpConnectedCard extends ConsumerWidget {
  const _MpConnectedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(mpBalanceProvider);
    final movements = ref.watch(mpMovementsProvider);
    final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    return GestureDetector(
      onTap: () => context.push('/mercado-pago'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF009EE3), Color(0xFF00B1EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Mercado Pago',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.6), size: 20),
              ],
            ),

            // Balance
            balance.when(
              data: (b) {
                if (b == null) return const SizedBox(height: 4);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    fmt.format(b.availableBalance),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 80, height: 24,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(Colors.white54),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox(height: 4),
            ),

            const SizedBox(height: 10),

            // Últimos 3 movimientos
            movements.when(
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    'Sin movimientos recientes',
                    style: GoogleFonts.inter(
                        color: Colors.white60, fontSize: 12),
                  );
                }
                return Column(
                  children: list.take(3).map((m) {
                    final isIncome = m.amount > 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            isIncome
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            size: 12,
                            color: isIncome
                                ? Colors.white.withValues(alpha: 0.8)
                                : const Color(0xFFFF8A80),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              m.description ?? 'Movimiento',
                              style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${isIncome ? '+' : ''}${fmt.format(m.amount)}',
                            style: GoogleFonts.inter(
                              color: isIncome
                                  ? Colors.white
                                  : const Color(0xFFFF8A80),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox(height: 40),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
