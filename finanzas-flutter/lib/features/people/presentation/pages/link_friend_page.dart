import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _LinkFriendPageState extends ConsumerState<LinkFriendPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scanner = MobileScannerController();
  bool _processing = false;
  String? _errorMessage;
  bool _success = false;
  String? _successName;

  // Manual code entry
  bool _showManual = false;
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _scanner.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Core logic ─────────────────────────────────────────────────────────────

  Future<void> _processQrData(String raw) async {
    if (_processing) return;

    // Formato esperado: "UID|APPCODE"
    final parts = raw.trim().split('|');
    if (parts.length != 2 || parts[0].isEmpty) {
      setState(() => _errorMessage = 'QR no reconocido. Pedile a tu amigo que use Sencillo.');
      return;
    }

    await _sendRequest(targetUid: parts[0]);
  }

  Future<void> _sendRequest({required String targetUid}) async {
    if (_processing) return;
    setState(() { _processing = true; _errorMessage = null; });

    try {
      await _scanner.stop();
    } catch (_) {}

    final myUid = ref.read(currentUidProvider);

    if (targetUid == myUid) {
      setState(() {
        _processing = false;
        _errorMessage = 'No podés agregarte a vos mismo 😅';
      });
      _restartScanner();
      return;
    }

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final myDoc = ref.read(currentUserDocProvider).valueOrNull;
      final targetDoc = await firestoreService.fetchUserDoc(targetUid);

      if (targetDoc == null) {
        setState(() { _processing = false; _errorMessage = 'Usuario no encontrado. Verificá el código.'; });
        _restartScanner();
        return;
      }

      final targetName = targetDoc['displayName'] as String? ?? 'Usuario';
      final myName = myDoc?['displayName'] as String? ?? 'Usuario';

      // ── 1. Enviar solicitud (operación principal) ──────────────────────────
      await firestoreService.sendFriendRequest(
        targetUid: targetUid,
        targetDisplayName: targetName,
        myDisplayName: myName,
        targetPhotoUrl: targetDoc['photoUrl'] as String?,
        myPhotoUrl: myDoc?['photoUrl'] as String?,
      );

      // ── 2. Vincular localmente si ya existe esa persona (separado, no critico) ──
      try {
        final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
        final match = people.where(
          (p) => p.name.toLowerCase() == targetName.toLowerCase() ||
                 p.linkedUserId == targetUid,
        ).toList();
        if (match.isNotEmpty) {
          final peopleService = ref.read(peopleServiceProvider);
          await peopleService.setLinkedUser(match.first.id, targetUid);
        }
      } catch (_) {
        // Falla silenciosa — el linking local no es crítico,
        // la solicitud ya fue enviada correctamente.
      }

      // ── Éxito ────────────────────────────────────────────────────────────
      setState(() {
        _success = true;
        _successName = targetName;
        _errorMessage = null;
      });
    } catch (e) {
      final msg = _friendlyError(e);
      setState(() { _processing = false; _errorMessage = msg; });
      _restartScanner();
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('network') || s.contains('unavailable') || s.contains('timeout')) {
      return 'Sin conexión. Revisá tu internet e intentá de nuevo.';
    }
    if (s.contains('permission') || s.contains('denied')) {
      return 'No tenés permisos para realizar esta acción.';
    }
    return 'Error al enviar solicitud. Intentá de nuevo.';
  }

  void _restartScanner() {
    if (!_showManual) {
      Future.microtask(() {
        try { _scanner.start(); } catch (_) {}
      });
    }
  }

  // ── QR detect callback ─────────────────────────────────────────────────────

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _success || _showManual) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    await _processQrData(raw);
  }

  // ── Manual code submit ─────────────────────────────────────────────────────

  Future<void> _submitManualCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    // El código manual es el UID directo o UID|APPCODE
    await _processQrData(code.contains('|') ? code : '$code|manual');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

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
        actions: [
          if (!_success)
            TextButton.icon(
              onPressed: () => setState(() {
                _showManual = !_showManual;
                _errorMessage = null;
                if (!_showManual) _restartScanner();
              }),
              icon: Icon(
                _showManual ? Icons.qr_code_scanner_rounded : Icons.keyboard_rounded,
                size: 16,
                color: Colors.white54,
              ),
              label: Text(
                _showManual ? 'Cámara' : 'Manual',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
              ),
            ),
        ],
      ),
      body: _success ? _buildSuccess() : (_showManual ? _buildManual() : _buildScanner()),
    );
  }

  // ── Success screen ─────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 64),
            ),
            const SizedBox(height: 24),
            Text(
              '¡Solicitud enviada!',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Le enviamos una solicitud a $_successName.\nCuando la acepte quedarán vinculados.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white54, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Listo', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── QR Scanner screen ──────────────────────────────────────────────────────

  Widget _buildScanner() {
    return Stack(
      children: [
        // Camera
        MobileScanner(
          controller: _scanner,
          onDetect: _onDetect,
        ),

        // Frame overlay
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Corners
                ...[ Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight ]
                    .map((align) => Align(
                          alignment: align,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF),
                              borderRadius: BorderRadius.only(
                                topLeft: align == Alignment.topLeft ? const Radius.circular(8) : Radius.zero,
                                topRight: align == Alignment.topRight ? const Radius.circular(8) : Radius.zero,
                                bottomLeft: align == Alignment.bottomLeft ? const Radius.circular(8) : Radius.zero,
                                bottomRight: align == Alignment.bottomRight ? const Radius.circular(8) : Radius.zero,
                              ),
                            ),
                          ),
                        )),
              ],
            ),
          ),
        ),

        // Bottom overlay
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                Text(
                  'Escaneá el QR de tu amigo\ndesde su pestaña Más',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // Loading
        if (_processing)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  // ── Manual code entry screen ───────────────────────────────────────────────

  Widget _buildManual() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instruction
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pedile a tu amigo que copie su código desde la pestaña Más, y pegalo acá.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Código de amigo',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white38),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _codeCtrl,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16, letterSpacing: 1.2),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Ej: UID|CODIGO o solo el UID',
              hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste_rounded, color: Colors.white38, size: 18),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) _codeCtrl.text = data!.text!;
                },
                tooltip: 'Pegar',
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _processing ? null : _submitManualCode,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _processing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Enviar solicitud', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
