import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final uid = ref.watch(currentUidProvider);
  return FirestoreService(uid: uid);
});

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? uid;

  FirestoreService({required this.uid});

  // ─── Amistades ──────────────────────────────────────────────────────────────

  /// Envía una solicitud de amistad al usuario con [targetUid].
  /// [targetDisplayName] y [targetPhotoUrl] se obtienen del doc de Firestore del target.
  Future<void> sendFriendRequest({
    required String targetUid,
    required String targetDisplayName,
    required String myDisplayName,
    String? targetPhotoUrl,
    String? myPhotoUrl,
  }) async {
    if (uid == null) return;

    // Verificar si ya son amigos o hay solicitud pendiente
    final existing = await _db
        .collection('friendships')
        .where('participants', arrayContains: uid)
        .get();

    for (final doc in existing.docs) {
      final participants = List<String>.from(doc['participants'] as List);
      if (participants.contains(targetUid)) return; // ya existe
    }

    await _db.collection('friendships').add({
      'participants': [uid, targetUid],
      'initiatedBy': uid,
      'status': 'pending',
      'displayName_$uid': myDisplayName,
      'displayName_$targetUid': targetDisplayName,
      'photoUrl_$uid': myPhotoUrl,
      'photoUrl_$targetUid': targetPhotoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream de solicitudes pendientes donde soy el destinatario.
  Stream<List<FriendRequest>> watchPendingRequests() {
    if (uid == null) return Stream.value([]);
    return _db
        .collection('friendships')
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      return snap.docs
          .where((doc) => doc['initiatedBy'] != uid) // solo las que me enviaron
          .map((doc) => FriendRequest.fromDoc(doc, myUid: uid!))
          .toList();
    });
  }

  /// Stream de solicitudes pendientes que YO envié.
  Stream<List<FriendRequest>> watchSentRequests() {
    if (uid == null) return Stream.value([]);
    return _db
        .collection('friendships')
        .where('initiatedBy', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => FriendRequest.fromDoc(doc, myUid: uid!)).toList());
  }

  /// Acepta una solicitud de amistad.
  Future<void> acceptFriendRequest(String docId) async {
    await _db.collection('friendships').doc(docId).update({'status': 'accepted'});
  }

  /// Rechaza / elimina una solicitud.
  Future<void> declineFriendRequest(String docId) async {
    await _db.collection('friendships').doc(docId).delete();
  }

  /// Cuenta de solicitudes pendientes recibidas (para badge).
  Stream<int> watchPendingRequestCount() {
    return watchPendingRequests().map((list) => list.length);
  }

  /// Lee el doc de un usuario por UID.
  Future<Map<String, dynamic>?> fetchUserDoc(String targetUid) async {
    final snap = await _db.collection('users').doc(targetUid).get();
    return snap.data();
  }

  // ─── Gastos compartidos ────────────────────────────────────────────────��─────

  /// Crea un gasto compartido en Firestore para sincronizar con el amigo.
  Future<void> createSharedExpense({
    required String expenseId,
    required String friendUid,
    required String title,
    required double totalAmount,
    required double myAmount,
    required double friendAmount,
    required DateTime date,
    String? category,
    String? myLocalTxId,
  }) async {
    if (uid == null) return;
    await _db.collection('sharedExpenses').doc(expenseId).set({
      'createdByUid': uid,
      'title': title,
      'totalAmount': totalAmount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'status': 'active',
      'splits': {
        uid!: {
          'amount': myAmount,
          'accepted': true,
          'localTxId': myLocalTxId,
        },
        friendUid: {
          'amount': friendAmount,
          'accepted': false,
          'localTxId': null,
        },
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream de gastos compartidos donde soy participante y no acepté.
  Stream<List<IncomingSharedExpense>> watchIncomingExpenses() {
    if (uid == null) return Stream.value([]);
    return _db
        .collection('sharedExpenses')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) {
      return snap.docs
          .where((doc) {
            final splits = doc['splits'] as Map<String, dynamic>?;
            final mySplit = splits?[uid] as Map<String, dynamic>?;
            // Me incluye Y no acepté Y no soy quien lo creó
            return mySplit != null &&
                mySplit['accepted'] == false &&
                doc['createdByUid'] != uid;
          })
          .map((doc) => IncomingSharedExpense.fromDoc(doc, myUid: uid!))
          .toList();
    });
  }

  /// Marca mi split como aceptado y guarda el ID de transacción local.
  Future<void> acceptSharedExpense(String expenseId, String localTxId) async {
    if (uid == null) return;
    await _db.collection('sharedExpenses').doc(expenseId).update({
      'splits.$uid.accepted': true,
      'splits.$uid.localTxId': localTxId,
    });
  }

  /// Rechaza / ignora un gasto compartido (marca como ignorado para mí).
  Future<void> declineSharedExpense(String expenseId) async {
    if (uid == null) return;
    await _db.collection('sharedExpenses').doc(expenseId).update({
      'splits.$uid.accepted': true, // lo marcamos como procesado para no volver a verlo
      'splits.$uid.declined': true,
    });
  }
}

// ─── Data classes ─────────────────────────���──────────────────────────────────

class FriendRequest {
  final String docId;
  final String senderUid;
  final String senderDisplayName;
  final String? senderPhotoUrl;
  final DateTime? createdAt;

  const FriendRequest({
    required this.docId,
    required this.senderUid,
    required this.senderDisplayName,
    this.senderPhotoUrl,
    this.createdAt,
  });

  factory FriendRequest.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      {required String myUid}) {
    final data = doc.data();
    final participants = List<String>.from(data['participants'] as List);
    final senderUid = participants.firstWhere((p) => p != myUid, orElse: () => '');
    final ts = data['createdAt'] as Timestamp?;
    return FriendRequest(
      docId: doc.id,
      senderUid: senderUid,
      senderDisplayName: data['displayName_$senderUid'] as String? ?? 'Usuario',
      senderPhotoUrl: data['photoUrl_$senderUid'] as String?,
      createdAt: ts?.toDate(),
    );
  }
}

class IncomingSharedExpense {
  final String docId;
  final String createdByUid;
  final String title;
  final double totalAmount;
  final double myAmount;
  final DateTime date;
  final String? category;

  const IncomingSharedExpense({
    required this.docId,
    required this.createdByUid,
    required this.title,
    required this.totalAmount,
    required this.myAmount,
    required this.date,
    this.category,
  });

  factory IncomingSharedExpense.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      {required String myUid}) {
    final data = doc.data();
    final splits = data['splits'] as Map<String, dynamic>;
    final mySplit = splits[myUid] as Map<String, dynamic>;
    final ts = data['date'] as Timestamp;
    return IncomingSharedExpense(
      docId: doc.id,
      createdByUid: data['createdByUid'] as String,
      title: data['title'] as String,
      totalAmount: (data['totalAmount'] as num).toDouble(),
      myAmount: (mySplit['amount'] as num).toDouble(),
      date: ts.toDate(),
      category: data['category'] as String?,
    );
  }
}
