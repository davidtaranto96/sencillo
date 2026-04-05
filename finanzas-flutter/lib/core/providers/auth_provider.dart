import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_auth_service.dart';

/// Singleton del servicio de autenticación
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

/// Stream del estado de autenticación — null = no logueado
final authStateProvider = StreamProvider<User?>((ref) {
  final service = ref.watch(firebaseAuthServiceProvider);
  return service.authStateChanges;
});

/// Doc del usuario en Firestore (displayName, appCode, etc.)
final currentUserDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      final service = ref.read(firebaseAuthServiceProvider);
      return service.watchCurrentUserDoc().map((snap) => snap.data());
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

/// UID del usuario actual — null si no logueado
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});
