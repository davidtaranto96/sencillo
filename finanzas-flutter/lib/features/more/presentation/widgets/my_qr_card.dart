import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/providers/auth_provider.dart';

class MyQrCard extends ConsumerWidget {
  const MyQrCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDocAsync = ref.watch(currentUserDocProvider);
    final uid = ref.watch(currentUidProvider);

    return userDocAsync.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (doc) {
        if (doc == null || uid == null) return const SizedBox.shrink();
        final displayName = doc['displayName'] as String? ?? 'Yo';
        final appCode = doc['appCode'] as String? ?? '------';
        final qrData = '$uid|$appCode';

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👤', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(
                          'Mi perfil',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9B96FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Código de 6 chars
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: appCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado al portapapeles')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            appCode,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 13, color: Colors.white38),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // QR Code
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 160,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0F0F1A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F0F1A),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                displayName,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mostrá este QR a tu amigo para que te agregue',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
