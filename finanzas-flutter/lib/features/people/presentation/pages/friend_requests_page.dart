import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/friend_requests_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';
import '../../../../core/theme/app_theme.dart';

class FriendRequestsPage extends ConsumerWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingFriendRequestsProvider);
    final sentAsync = ref.watch(sentFriendRequestsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Solicitudes',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  dividerHeight: 0,
                  labelColor: AppTheme.colorTransfer,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    Tab(
                      child: requestsAsync.when(
                        data: (r) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Recibidas'),
                            if (r.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.colorTransfer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${r.length}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                        loading: () => const Text('Recibidas'),
                        error: (_, __) => const Text('Recibidas'),
                      ),
                    ),
                    const Tab(text: 'Enviadas'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // ── Recibidas ──
            requestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: 'Error al cargar solicitudes'),
              data: (requests) => requests.isEmpty
                  ? _EmptyState(
                      emoji: '🤝',
                      title: 'Sin solicitudes recibidas',
                      subtitle: 'Cuando alguien escanee tu QR,\naparecerá aquí',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _RequestCard(request: requests[i], isReceived: true),
                    ),
            ),
            // ── Enviadas ──
            sentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: 'Error al cargar solicitudes enviadas'),
              data: (sent) => sent.isEmpty
                  ? _EmptyState(
                      emoji: '📨',
                      title: 'Sin solicitudes enviadas',
                      subtitle: 'Escaneá el QR de tu amigo para\nenviarle una solicitud',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: sent.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _RequestCard(request: sent[i], isReceived: false),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Request Card ─────────────────────────────────────────────────────────────

class _RequestCard extends ConsumerStatefulWidget {
  final FriendRequest request;
  final bool isReceived;
  const _RequestCard({required this.request, required this.isReceived});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _loading = false;
  String? _error;

  Future<void> _accept() async {
    setState(() { _loading = true; _error = null; });
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.acceptFriendRequest(widget.request.docId);

      // Link or create person locally
      try {
        final peopleService = ref.read(peopleServiceProvider);
        final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
        final name = widget.request.senderDisplayName.toLowerCase();

        final match = people.where((p) =>
            p.linkedUserId == widget.request.senderUid ||
            p.name.toLowerCase() == name).toList();

        if (match.isNotEmpty) {
          await peopleService.setLinkedUser(match.first.id, widget.request.senderUid);
        } else {
          final newId = await peopleService.addPerson(name: widget.request.senderDisplayName);
          await peopleService.setLinkedUser(newId, widget.request.senderUid);
        }
      } catch (_) {
        // Falla local silenciosa — el friendships doc ya se actualizó
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('¡Ahora sos amigo de ${widget.request.senderDisplayName}!'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'No se pudo aceptar. Intentá de nuevo.'; });
    }
  }

  Future<void> _decline() async {
    setState(() { _loading = true; _error = null; });
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.declineFriendRequest(widget.request.docId);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'No se pudo rechazar. Intentá de nuevo.'; });
    }
  }

  Future<void> _cancel() async {
    setState(() { _loading = true; _error = null; });
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.declineFriendRequest(widget.request.docId);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'No se pudo cancelar.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final timeAgo = req.createdAt != null ? _formatTimeAgo(req.createdAt!) : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                backgroundImage: req.senderPhotoUrl != null
                    ? NetworkImage(req.senderPhotoUrl!)
                    : null,
                child: req.senderPhotoUrl == null
                    ? Text(
                        req.senderDisplayName.isNotEmpty
                            ? req.senderDisplayName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF6C63FF)),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.senderDisplayName,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Row(
                      children: [
                        Text(
                          widget.isReceived ? 'Quiere conectarse contigo' : 'Solicitud pendiente',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                        ),
                        if (timeAgo != null) ...[
                          Text(' · ', style: GoogleFonts.inter(fontSize: 12, color: Colors.white24)),
                          Text(timeAgo, style: GoogleFonts.inter(fontSize: 11, color: Colors.white24)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge for sent
              if (!widget.isReceived)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'En espera',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange),
                  ),
                ),
            ],
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: GoogleFonts.inter(fontSize: 11, color: Colors.redAccent)),
            ),
          ],

          // Actions (only for received)
          if (widget.isReceived) ...[
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _decline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white38,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text('Rechazar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _accept,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text('Aceptar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],

          // Cancel for sent
          if (!widget.isReceived) ...[
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _cancel,
                  child: Text(
                    'Cancelar solicitud',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ayer';
    return DateFormat('d MMM', 'es').format(date);
  }
}

// ─── Supporting widgets ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const _EmptyState({required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white54)),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: Colors.white24), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: GoogleFonts.inter(color: Colors.white38, fontSize: 14)),
    );
  }
}
