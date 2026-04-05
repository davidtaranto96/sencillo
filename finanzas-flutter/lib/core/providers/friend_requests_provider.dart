import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';

/// Stream del conteo de solicitudes de amistad pendientes (para badge)
final friendRequestCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.watchPendingRequestCount();
});

/// Stream de solicitudes de amistad recibidas
final pendingFriendRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.watchPendingRequests();
});
