import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/logic/month_closure_service.dart';
import 'package:google_fonts/google_fonts.dart';

class MonthClosureWizard extends ConsumerWidget {
  final DateTime month;

  const MonthClosureWizard({super.key, required this.month});

  static Future<void> show(BuildContext context, DateTime month) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MonthClosureWizard(month: month),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                const Text(
                'Cierre de Mes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Estás por cerrar el ciclo de este mes. Esto reseteará tus gastos corrientes y moverá tus deudas de tarjeta a tu "Próximo Pagar".',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          // Resumen de Deudas a Ciclar
          _ClosureStatRow(label: 'Mastercard Black', amount: 1522588.00, isDebt: true),
          _ClosureStatRow(label: 'Visa Signature', amount: 511659.00, isDebt: true),
          const Divider(color: Colors.white10, height: 32),
          
          const SizedBox(height: 24),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.colorTransfer,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              // Implementation of the closure
              await ref.read(monthClosureServiceProvider).closeMonth(month);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Mes cerrado satisfactoriamente!')),
                );
              }
            },
            child: const Text('Confirmar Cierre de Mes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }
}

class _ClosureStatRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDebt;

  const _ClosureStatRow({
    required this.label,
    required this.amount,
    this.isDebt = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          Text(
            formatAmount(amount),
            style: GoogleFonts.inter(
              color: isDebt ? AppTheme.colorExpense : AppTheme.colorIncome,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
