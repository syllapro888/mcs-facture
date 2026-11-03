import 'package:flutter/material.dart';

import 'app.dart';
import 'utils/app_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();
  runApp(const McsApp());
}
