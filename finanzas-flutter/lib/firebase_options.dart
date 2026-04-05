// File generated from google-services.json — project: finanzas-app-c183e
// @dart=2.12

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBErRa_dc01vCAojoEZ5USSVIy3Ju7dGdE',
    appId: '1:615200157804:android:47add3543d3de10188a849',
    messagingSenderId: '615200157804',
    projectId: 'finanzas-app-c183e',
    storageBucket: 'finanzas-app-c183e.firebasestorage.app',
  );

  // ⚠️ iOS: agregá la app iOS desde Firebase Console para obtener estos valores.
  // Por ahora la app corre solo en Android.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_IOS_KEY',
    appId: 'PLACEHOLDER_IOS_APP_ID',
    messagingSenderId: '615200157804',
    projectId: 'finanzas-app-c183e',
    storageBucket: 'finanzas-app-c183e.firebasestorage.app',
    iosClientId: 'PLACEHOLDER_IOS_CLIENT_ID',
    iosBundleId: 'com.davidtaranto.finanzasApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBErRa_dc01vCAojoEZ5USSVIy3Ju7dGdE',
    appId: '1:615200157804:android:47add3543d3de10188a849',
    messagingSenderId: '615200157804',
    projectId: 'finanzas-app-c183e',
    storageBucket: 'finanzas-app-c183e.firebasestorage.app',
    authDomain: 'finanzas-app-c183e.firebaseapp.com',
  );
}
