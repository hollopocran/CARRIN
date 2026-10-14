import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

/// Service responsible for managing database backups and restores.
/// 
/// Allows users to export their local SQLite database file (.db)
/// and import it back, enabling complete data backup and restore.
class BackupService {
  static const String _backupFileNamePrefix = 'CARRIN_Backup_';

  /// Exports the current active SQLite database file to a temporary location
  /// and opens the system share sheet.
  static Future<void> exportBackup() async {
    try {
      // 1. Close current connection to write any pending changes and ensure no locks
      await DatabaseHelper.closeDatabase();

      // 2. Get current active database path
      final dbPath = await DatabaseHelper.getCurrentDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('Banco de dados local não encontrado para exportar.');
      }

      // 3. Copy to a temporary file
      final directory = await getTemporaryDirectory();
      final String date = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final File backupFile = File('${directory.path}/$_backupFileNamePrefix$date.db');
      
      await dbFile.copy(backupFile.path);

      // 4. Trigger the system share dialog
      await Share.shareXFiles([XFile(backupFile.path)], text: 'Meu Backup do CARRIN ($date)');
    } catch (e) {
      debugPrint('Erro ao exportar backup: $e');
      rethrow;
    }
  }

  /// Imports a SQLite database file selected by the user, replacing the current one.
  /// 
  /// Returns true if the import was successful, false otherwise.
  static Future<bool> importBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any, // Allow picking any file (e.g. .db or .sqlite)
      );

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final File selectedFile = File(result.files.single.path!);
      
      // Basic validation: must exist and not be empty
      if (!await selectedFile.exists() || await selectedFile.length() == 0) {
        throw Exception('Arquivo de backup inválido ou vazio.');
      }

      // Close the current database connection first
      await DatabaseHelper.closeDatabase();

      // Get target database path
      final dbPath = await DatabaseHelper.getCurrentDatabasePath();

      // Copy selected backup over the current active database path
      await selectedFile.copy(dbPath);

      debugPrint('🔍 Backup restaurado com sucesso para o banco de dados atual.');
      return true;
    } catch (e) {
      debugPrint('Erro ao importar backup: $e');
      rethrow;
    }
  }
}
