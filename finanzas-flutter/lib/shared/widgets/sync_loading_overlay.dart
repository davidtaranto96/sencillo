import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class SyncLoadingOverlay extends StatelessWidget {
  final String status;
  final double progress;

  const SyncLoadingOverlay({
    super.key,
    this.status = 'Sincronizando resúmenes...',
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Branded Neon Spinner
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                color: AppTheme.colorTransfer,
                backgroundColor: AppTheme.colorTransfer.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(height: 32),
            
            // Status text
            Text(
               status,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            
            // Progress Bar (AstroPay style)
            Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.colorTransfer,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.colorTransfer.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Calculando presupuestos y deudas...',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
