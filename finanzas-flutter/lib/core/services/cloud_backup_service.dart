import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class CloudBackupService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String uid;

  CloudBackupService({required this.uid});

  Reference get _backupRef => _storage.ref('users/$uid/finanzas_app.sqlite');

  /// Sube el archivo SQLite local a Firebase Storage.
  Future<DateTime> uploadBackup() async {
    final dbFile = await _dbFile();
    if (!await dbFile.exists()) {
      throw Exception('No se encontró la base de datos local.');
    }

    await _backupRef.putFile(
      dbFile,
      SettableMetadata(
        contentType: 'application/octet-stream',
        customMetadata: {'createdAt': DateTime.now().toIso8601String()},
      ),
    );

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_backup_ts', now.toIso8601String());
    return now;
  }

  /// Descarga el backup de Firebase Storage y reemplaza la DB local.
  /// ⚠️ La app debe reiniciarse para que Drift use la nueva DB.
  ///
  /// Proceso seguro:
  /// 1. Descarga a `.tmp`
  /// 2. Valida header mágico SQLite
  /// 3. Renombra la DB actual a `.bak` (por si hay que revertir)
  /// 4. Rename atómico `.tmp` → real
  /// 5. Borra `.bak` si todo salió ok
  ///
  /// Si la validación falla, tira excepción y NO toca la DB actual.
  Future<void> downloadBackup() async {
    final dbFile = await _dbFile();
    final tempFile = File('${dbFile.path}.tmp');
    final backupFile = File('${dbFile.path}.bak');

    // Limpiar residuos de intentos previos
    if (await tempFile.exists()) await tempFile.delete();
    if (await backupFile.exists()) await backupFile.delete();

    await _backupRef.writeToFile(tempFile);

    if (!await tempFile.exists()) {
      throw Exception('No se pudo descargar el backup.');
    }

    // Validar que sea un SQLite válido antes de tocar la DB real
    final isValid = await _isValidSqlite(tempFile);
    if (!isValid) {
      await tempFile.delete();
      throw Exception('El backup descargado está corrupto.');
    }

    // Backup de la DB actual por si algo sale mal
    if (await dbFile.exists()) {
      await dbFile.rename(backupFile.path);
    }

    try {
      await tempFile.rename(dbFile.path);
      // Todo ok, eliminar el backup anterior
      if (await backupFile.exists()) await backupFile.delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_restore_ts', DateTime.now().toIso8601String());
    } catch (e) {
      // Rename falló: restaurar backup
      if (await backupFile.exists()) {
        await backupFile.rename(dbFile.path);
      }
      rethrow;
    }
  }

  /// Verifica que un archivo sea un SQLite válido leyendo el header mágico.
  /// Los primeros 16 bytes de un SQLite válido son "SQLite format 3\0".
  Future<bool> _isValidSqlite(File file) async {
    try {
      final length = await file.length();
      if (length < 100) return false; // Un SQLite tiene mínimo 100 bytes de header

      final raf = await file.open();
      try {
        final header = await raf.read(16);
        // "SQLite format 3\x00"
        const expected = [
          0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66,
          0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00,
        ];
        if (header.length != 16) return false;
        for (var i = 0; i < 16; i++) {
          if (header[i] != expected[i]) return false;
        }
        return true;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Check if a remote backup exists in Firebase Storage.
  /// Returns the creation date if found, null if not.
  Future<DateTime?> remoteBackupDate() async {
    try {
      final metadata = await _backupRef.getMetadata();
      final createdAt = metadata.customMetadata?['createdAt'];
      if (createdAt != null) return DateTime.tryParse(createdAt);
      return metadata.updated ?? metadata.timeCreated;
    } catch (_) {
      // File doesn't exist or no permission
      return null;
    }
  }

  /// Devuelve la fecha del último backup local, o null.
  Future<DateTime?> lastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString('last_backup_ts');
    return ts != null ? DateTime.tryParse(ts) : null;
  }

  /// Sprint 4.22 — Backup automático "open-app check".
  ///
  /// Llamar al startup de la app. Si han pasado más días que [intervalDays]
  /// desde el último backup (auto o manual), dispara un upload silencioso.
  /// Errors no se propagan (best-effort) — el usuario igual puede hacer manual.
  ///
  /// Por qué open-app vs workmanager:
  /// - 0 deps adicionales, 0 setup nativo (manifest/services).
  /// - 95% del valor: si el user usa la app al menos 1 vez por semana,
  ///   el backup se ejecuta. Si no la usa, no hay datos nuevos que respaldar.
  /// - Para verdadero background hay que evaluar workmanager (Sprint 4 backlog).
  Future<bool> runWeeklyBackupIfDue({int intervalDays = 7}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoEnabled = prefs.getBool('auto_backup_enabled') ?? true;
      if (!autoEnabled) return false;

      final lastTs = prefs.getString('last_auto_backup_ts');
      final last = lastTs != null ? DateTime.tryParse(lastTs) : null;
      final now = DateTime.now();
      if (last != null && now.difference(last).inDays < intervalDays) {
        return false; // todavía no toca
      }

      await uploadBackup();
      await prefs.setString('last_auto_backup_ts', now.toIso8601String());
      return true;
    } catch (_) {
      // Best-effort: si falla (sin red, sin auth), no lo grita al usuario.
      return false;
    }
  }

  Future<File> _dbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'finanzas_app.sqlite'));
  }
}
