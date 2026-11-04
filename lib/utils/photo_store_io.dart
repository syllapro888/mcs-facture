// Téléphone (Android / iPhone) : photos rangées dans des fichiers.
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String? _docs;

Future<void> init() async {
  _docs = (await getApplicationDocumentsDirectory()).path;
  await Directory(p.join(_docs!, 'photos')).create(recursive: true);
}

File _file(String rel) {
  final d = _docs;
  if (d == null) throw StateError('AppPaths.init() non appelé');
  return File(p.join(d, rel));
}

Future<void> write(String rel, Uint8List bytes) async {
  final f = _file(rel);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes, flush: true);
}

Future<Uint8List?> read(String rel) async {
  final f = _file(rel);
  if (!await f.exists()) return null;
  return f.readAsBytes();
}

Future<Map<String, Uint8List>> all() async {
  final result = <String, Uint8List>{};
  final dir = Directory(p.join(_docs!, 'photos'));
  if (!await dir.exists()) return result;
  await for (final entity in dir.list()) {
    if (entity is File) {
      result['photos/${p.basename(entity.path)}'] = await entity.readAsBytes();
    }
  }
  return result;
}
