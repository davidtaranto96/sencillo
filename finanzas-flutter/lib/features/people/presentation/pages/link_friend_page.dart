import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';

class LinkFriendPage extends ConsumerStatefulWidget {
  const LinkFriendPage({super.key});

  @override
  ConsumerState<LinkFriendPage> createState() => _LinkFriendPageState();
}

class _LinkFriendPageState extends ConsumerState<LinkFriendPage> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _processing = false;
  String? _statusMessage;
  bool _success = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final raw = barcode!.rawValue!;
    // Formato esperado: "UID|APPCODE"
    final parts = raw.split('|');
    if (parts.length != 2) {
      setState(() => _statusMessage = 'QR no reconocido. Pedile a tu amigo que use Finanzas.');
      return;
    }

    setState(() { _processing = true; _statusMessage = null; });
    await _scanner.stop();

    final targetUid = parts[0];
    final myUid = ref.read(currentUidProvider);

    if (targetUid == myUid) {
      setState(() { _processing = false; _statusMessage = 'No podés agregarte a vos mismo 😅'; });
      await _scanner.start();
      return;
    }

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final myDoc = ref.read(currentUserDocProvider).valueOrNull;
      final targetDoc = await firestoreService.fetchUserDoc(targetUid);

      if (targetDoc == null) {
        setState(() { _processing = false; _statusMessage = 'Usuario no encontrado.'; });
        await _scanner.start();
        return;
      }

      final targetName = targetDoc['displayName'] as String? ?? 'Usuario';
      final myName = myDoc?['displayName'] as String? ?? 'Usuario';

      await firestoreService.sendFriendRequest(
        targetUid: targetUid,
        targetDisplayName: targetName,
        myDisplayName: myName,
        targetPhotoUrl: targetDoc['photoUrl'] as String?,
        myPhotoUrl: myDoc?['photoUrl'] as String?,
      );

      // Si ya tenemos a esa persona localmente, vinculamos el linkedUserId
      final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
      final matchPerson = people.firstWhere(
        (p) => p.name.toLowerCase() == targetName.toLowerCase(),
        orElse: () => people.isNotEmpty ? people.first : throw Exception('not found'),
      );
      // Solo vinculamos si la persona ya existe con ese nombre exacto
      if (people.any((p) => p.name.toLowerCase() == targetName.toLowerCase())) {
        final peopleService = ref.read(peopleServiceProvider);
        await peopleService.setLinkedUser(matchPerson.id, targetUid);
      }

      setState(() { _success = true; _statusMessage = '¡Solicitud enviada a $targetName! Esperá que la acepte.'; });
    } catch (e) {
      setState(() { _processing = false; _statusMessage = 'Error al enviar solicitud. Intentá de nuevo.'; });
      await _scanner.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Vincular amigo',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // ── QR Scanner ──
          if (!_success)
            MobileScanner(
              controller: _scanner,
              onDetect: _onDetect,
            ),

          if (_success)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 56),
                  ),
                  const SizedBox(height: 20),
                  Text(_statusMessage ?? '', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: Text('Listo', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),

          // ── Overlay instrucciones ──
          if (!_success)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_statusMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Text(
                      'Escaneá el QR de tu amigo desde su pestaña Más',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          if (_processing && !_success)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
