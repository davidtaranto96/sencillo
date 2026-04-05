import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Utility for backing up and restoring the app database.
class BackupUtils {
  BackupUtils._();

  static const _dbName = 'finanzas_app.sqlite';

  /// Returns the path to the database file.
  static Future<String> _dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbName);
  }

  /// Creates a backup copy of the database in the Downloads folder.
  /// Returns the backup file path, or null if failed.
  static Future<String?> exportBackup() async {
    final dbPath = await _dbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) return null;

    // Copy to Downloads folder
    Directory? dir = await getExternalStorageDirectory();
    if (dir != null) {
      final downloadDir = Directory('${dir.path.split('Android')[0]}Download');
      if (await downloadDir.exists()) {
        dir = downloadDir;
      }
    }
    dir ??= await getApplicationDocumentsDirectory();

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupName = 'Fint_Backup_$timestamp.sqlite';
    final backupPath = p.join(dir.path, backupName);
    await dbFile.copy(backupPath);

    return backupPath;
  }

  /// Restores a database from a user-selected backup file.
  /// Returns true if successful. The app should be restarted after this.
  static Future<bool> restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return false;

      final file = result.files.first;
      if (file.bytes == null && file.path == null) return false;

      final dbPath = await _dbPath();

      if (file.path != null) {
        await File(file.path!).copy(dbPath);
      } else if (file.bytes != null) {
        await File(dbPath).writeAsBytes(file.bytes!);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns database file size in bytes.
  static Future<int> getDatabaseSize() async {
    final dbPath = await _dbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) return 0;
    return await dbFile.length();
  }
}
