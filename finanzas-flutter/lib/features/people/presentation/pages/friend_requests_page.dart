import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/friend_requests_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';

class FriendRequestsPage extends ConsumerWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingFriendRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Solicitudes de amistad',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🤝', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    'No hay solicitudes pendientes',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cuando alguien escanee tu QR aparecerá aquí',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white24),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final req = requests[i];
              return _FriendRequestCard(request: req);
            },
          );
        },
      ),
    );
  }
}

class _FriendRequestCard extends ConsumerStatefulWidget {
  final FriendRequest request;
  const _FriendRequestCard({required this.request});

  @override
  ConsumerState<_FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends ConsumerState<_FriendRequestCard> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.acceptFriendRequest(widget.request.docId);

      // Vincular persona local si existe con ese nombre
      final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
      final name = widget.request.senderDisplayName.toLowerCase();
      final match = people.where((p) => p.name.toLowerCase() == name).toList();
      if (match.isNotEmpty) {
        final peopleService = ref.read(peopleServiceProvider);
        await peopleService.setLinkedUser(match.first.id, widget.request.senderUid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Ahora sos amigo de ${widget.request.senderDisplayName}!')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.declineFriendRequest(widget.request.docId);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            backgroundImage: req.senderPhotoUrl != null
                ? NetworkImage(req.senderPhotoUrl!)
                : null,
            child: req.senderPhotoUrl == null
                ? Text(
                    req.senderDisplayName.isNotEmpty ? req.senderDisplayName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF6C63FF)),
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
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  'Quiere conectarse contigo',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),

          // Actions
          if (_loading)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            GestureDetector(
              onTap: _decline,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _accept,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Aceptar',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
