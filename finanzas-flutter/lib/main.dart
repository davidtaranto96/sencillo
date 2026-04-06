import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar AudioPlayer global con contexto de notificación/UI
  // (Necesario en Android para que los sonidos cortos de UI funcionen)
  try {
    await AudioPlayer.global.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.notificationEvent,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        isSpeakerphoneOn: false,
        stayAwake: false,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    ));
  } catch (_) {
    // Silencioso — el sonido es decorativo
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notifications
  await NotificationService.initialize();
  await NotificationService.requestPermission();

  // Nota: sqlite3_flutter_libs se carga automáticamente al importar.
  // En versiones 0.6.0+, applyWorkaroundToOpenSqliteOnOldAndroidVersions() fue removido.
  // El import del paquete es suficiente para garantizar que libsqlite3.so se empaquete correctamente.

  // Inicializar localización en español
  await initializeDateFormatting('es', null);

  // Barra de sistema transparente (edge-to-edge)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    const ProviderScope(
      child: SencilloApp(),
    ),
  );
}
