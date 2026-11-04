// Navigateur (version web) : photos rangées dans la base de données.
import 'dart:typed_data';

import '../database/app_database.dart';

Future<void> init() async {}

Future<void> write(String rel, Uint8List bytes) =>
    AppDatabase.instance.writeFile(rel, bytes);

Future<Uint8List?> read(String rel) => AppDatabase.instance.readFile(rel);

Future<Map<String, Uint8List>> all() => AppDatabase.instance.allFiles();
