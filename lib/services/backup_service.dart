import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../utils/app_paths.dart';

/// Sauvegarde complète (base + photos + logo) dans un seul fichier .json,
/// et restauration de ce fichier.
class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  static const _format = 'mcs_facture_backup';

  Future<Uint8List> buildBackup() async {
    final tables = await db.dumpAll();
    final files = <String, String>{};
    final photosDir = Directory(p.join(AppPaths.documents, 'photos'));
    if (await photosDir.exists()) {
      await for (final entity in photosDir.list()) {
        if (entity is File) {
          final rel = 'photos/${p.basename(entity.path)}';
          files[rel] = base64Encode(await entity.readAsBytes());
        }
      }
    }
    final json = jsonEncode({
      'format': _format,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
      'files': files,
    });
    return Uint8List.fromList(utf8.encode(json));
  }

  /// Demande où enregistrer le fichier. Renvoie le chemin, ou null si annulé.
  Future<String?> exportToDevice() async {
    final bytes = await buildBackup();
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(':', 'h')
        .replaceAll('T', '_');
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Enregistrer la sauvegarde',
      fileName: 'MCSV_sauvegarde_$stamp.json',
      mimeType: 'application/json',
      bytes: bytes,
    );
    return uri?.toString();
  }

  /// Choisit un fichier de sauvegarde et remplace les données actuelles.
  /// Renvoie false si l'utilisateur annule. Lève une exception si le
  /// fichier n'est pas valide (les données actuelles restent intactes).
  Future<bool> restoreFromDevice() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return false;
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const FormatException('Fichier illisible.');
    }
    await restore(bytes);
    return true;
  }

  Future<void> restore(Uint8List bytes) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('Ce fichier n’est pas une sauvegarde MCS VISION.');
    }
    if (decoded is! Map || decoded['format'] != _format) {
      throw const FormatException('Ce fichier n’est pas une sauvegarde MCS VISION.');
    }
    final rawTables = (decoded['tables'] as Map?) ?? const {};
    final tables = <String, List<Map<String, Object?>>>{};
    rawTables.forEach((key, value) {
      tables[key as String] = [
        for (final row in (value as List)) (row as Map).cast<String, Object?>()
      ];
    });

    // 1. Photos d'abord (les fichiers existants ne sont jamais supprimés).
    final files = (decoded['files'] as Map?) ?? const {};
    for (final entry in files.entries) {
      final rel = entry.key as String;
      if (!rel.startsWith('photos/') || rel.contains('..')) continue;
      await AppPaths.resolve(rel)
          .writeAsBytes(base64Decode(entry.value as String), flush: true);
    }
    // 2. Base de données (transaction).
    await db.restoreAll(tables);
  }
}
