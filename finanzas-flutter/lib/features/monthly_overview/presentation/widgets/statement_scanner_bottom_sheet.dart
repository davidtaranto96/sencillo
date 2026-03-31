import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';

class StatementScannerBottomSheet extends StatefulWidget {
  const StatementScannerBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StatementScannerBottomSheet(),
    );
  }

  @override
  State<StatementScannerBottomSheet> createState() => _StatementScannerBottomSheetState();
}

class _StatementScannerBottomSheetState extends State<StatementScannerBottomSheet> {
  bool _isScanning = false;
  bool _scanComplete = false;

  void _startScan() async {
    setState(() => _isScanning = true);
    // Simulate image uploading and AI processing
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _isScanning = false;
        _scanComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.document_scanner_rounded, color: AppTheme.colorTransfer),
                const SizedBox(width: 8),
                Text(
                  'Escáner de Resúmenes',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Subí un PDF o foto de tu tarjeta. La IA extraerá los gastos, los clasificará y calculará tus cuotas.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _scanComplete ? _buildResults(cs) : _buildUploadState(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isScanning) ...[
            const CircularProgressIndicator(color: AppTheme.colorTransfer),
            const SizedBox(height: 24),
            Text('Procesando imagen con IA...', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            const Text('Clasificando 42 movimientos...', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.upload_file_rounded, size: 60, color: AppTheme.colorTransfer),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Tomar foto o subir PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      children: [
        // Resumen General
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumen Extraído', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 16),
              _SummaryRow(label: 'Total Tarjetas (Visa + Master)', amount: 485000, color: AppTheme.colorExpense),
              const SizedBox(height: 8),
              _SummaryRow(label: 'Tus gastos manuales del mes', amount: 150000, color: Colors.white54),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10, height: 1),
              ),
              _SummaryRow(label: 'Total Real Estimado', amount: 635000, color: Colors.white, isBold: true),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Advertencias Cuotas
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.colorWarning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.colorWarning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time_filled_rounded, color: AppTheme.colorWarning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Atención con las cuotas', style: TextStyle(color: AppTheme.colorWarning, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Se detectaron \$125.000 comprometidos para los próximos 3 meses por compras en 6 cuotas.', 
                      style: TextStyle(color: AppTheme.colorWarning.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Gastos Autoclasificados
        Text('Gastos Autoclasificados', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 12),
        _AutoExpenseItem(date: '12 Mar', title: 'Supermercado Coto', category: '🛒 Supermercado', amount: 45000),
        _AutoExpenseItem(date: '14 Mar', title: 'Netflix', category: '🎬 Entretenimiento', amount: 7500),
        _AutoExpenseItem(date: '15 Mar', title: 'MercadoLibre (Cuota 2/6)', category: '📦 Compras', amount: 25000, isInstallment: true),
        _AutoExpenseItem(date: '18 Mar', title: 'Shell', category: '🚗 Transporte', amount: 22000),
        
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado en la Base de Datos')));
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.colorTransfer),
            child: const Text('Importar a mis finanzas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isBold;

  const _SummaryRow({required this.label, required this.amount, required this.color, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: isBold ? FontWeight.w600 : FontWeight.w400)),
        Text(formatAmount(amount), style: TextStyle(color: color, fontSize: 15, fontWeight: isBold ? FontWeight.w700 : FontWeight.w600)),
      ],
    );
  }
}

class _AutoExpenseItem extends StatelessWidget {
  final String date;
  final String title;
  final String category;
  final double amount;
  final bool isInstallment;

  const _AutoExpenseItem({
    required this.date,
    required this.title,
    required this.category,
    required this.amount,
    this.isInstallment = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(category, style: const TextStyle(color: AppTheme.colorTransfer, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatAmount(amount), style: const TextStyle(color: AppTheme.colorExpense, fontWeight: FontWeight.w600)),
              if (isInstallment)
                Text('Cuota', style: TextStyle(color: AppTheme.colorWarning, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
