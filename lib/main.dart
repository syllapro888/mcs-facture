import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'database/app_database.dart';
import 'utils/app_paths.dart';
import 'utils/web_storage_io.dart'
    if (dart.library.js_interop) 'utils/web_storage_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();
  // Version web : demander un stockage durable (pas d'effacement automatique).
  requestPersistentStorage();
  if (kIsWeb) {
    try {
      final n = await AppDatabase.instance.countOpening();
      debugPrint('MCS_DB_OK opens=$n');
    } catch (e) {
      debugPrint('MCS_DB_ERROR $e');
    }
  }
  runApp(const McsApp());
}
