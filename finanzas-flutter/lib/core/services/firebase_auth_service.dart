import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // usuario canceló

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return null;

    // Crear o actualizar doc en Firestore
    await _ensureUserDoc(user);
    return user;
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> _ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'displayName': user.displayName ?? 'Usuario',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'appCode': _generateAppCode(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Actualizar nombre/foto si cambiaron
      await ref.update({
        'displayName': user.displayName ?? snap.data()!['displayName'],
        'photoUrl': user.photoURL ?? snap.data()!['photoUrl'],
      });
    }
  }

  /// Genera un código de 6 caracteres alfanumérico único para el QR.
  String _generateAppCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Lee el doc del usuario actual de Firestore.
  Future<Map<String, dynamic>?> fetchCurrentUserDoc() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data();
  }

  /// Stream del doc del usuario actual.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentUserDoc() {
    final uid = currentUser!.uid;
    return _db.collection('users').doc(uid).snapshots();
  }
}
