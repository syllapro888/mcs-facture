import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Les photos sont enregistrées dans le dossier privé de l'application,
/// avec un chemin RELATIF (ex. "photos/169999.jpg"). Sur iPhone le dossier
/// change à chaque mise à jour : un chemin relatif reste toujours valable.
class AppPaths {
  AppPaths._();

  static String? _docs;

  static Future<void> init() async {
    _docs = (await getApplicationDocumentsDirectory()).path;
    await Directory(p.join(_docs!, 'photos')).create(recursive: true);
  }

  static String get documents {
    final d = _docs;
    if (d == null) throw StateError('AppPaths.init() non appelé');
    return d;
  }

  static File resolve(String relativePath) =>
      File(p.join(documents, relativePath));

  static int _counter = 0;

  /// Enregistre une image et renvoie son chemin relatif.
  static Future<String> savePhoto(Uint8List bytes, String extension) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_${_counter++}.${ext.isEmpty ? 'jpg' : ext}';
    final rel = 'photos/$name';
    await resolve(rel).writeAsBytes(bytes, flush: true);
    return rel;
  }

  /// Lit une photo ; null si absente (le PDF met alors un emplacement neutre).
  static Future<Uint8List?> readPhoto(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    try {
      final f = resolve(relativePath);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
