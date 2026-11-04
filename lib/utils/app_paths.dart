import 'dart:typed_data';

import 'photo_store_io.dart' if (dart.library.js_interop) 'photo_store_web.dart'
    as store;

/// Photos des produits et logo.
///
/// Chaque photo est désignée par un chemin RELATIF (ex. "photos/169999.jpg").
/// Sur téléphone, c'est un fichier dans le dossier privé de l'application
/// (sur iPhone ce dossier change à chaque mise à jour : un chemin relatif reste
/// valable). Dans le navigateur, la photo est rangée dans la base de données.
class AppPaths {
  AppPaths._();

  static final Map<String, Uint8List> _cache = {};
  static int _counter = 0;

  static Future<void> init() => store.init();

  /// Enregistre une image et renvoie son chemin relatif.
  static Future<String> savePhoto(Uint8List bytes, String extension) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_${_counter++}.${ext.isEmpty ? 'jpg' : ext}';
    final rel = 'photos/$name';
    await store.write(rel, bytes);
    _cache[rel] = bytes;
    return rel;
  }

  /// Écrit une photo à un chemin donné (restauration d'une sauvegarde).
  static Future<void> writePhoto(String rel, Uint8List bytes) async {
    await store.write(rel, bytes);
    _cache[rel] = bytes;
  }

  /// Lit une photo ; null si absente (le PDF met alors un emplacement neutre).
  static Future<Uint8List?> readPhoto(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final cached = _cache[relativePath];
    if (cached != null) return cached;
    try {
      final bytes = await store.read(relativePath);
      if (bytes != null) _cache[relativePath] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Photo déjà chargée (affichage immédiat, sans clignotement).
  static Uint8List? cached(String? rel) => rel == null ? null : _cache[rel];

  /// Toutes les photos (pour la sauvegarde).
  static Future<Map<String, Uint8List>> allPhotos() => store.all();
}
