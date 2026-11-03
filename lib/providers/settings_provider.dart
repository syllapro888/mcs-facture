import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/company_settings.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this.db);
  final AppDatabase db;

  CompanySettings _settings = const CompanySettings();
  CompanySettings get settings => _settings;

  Future<void> load() async {
    _settings = await db.loadSettings();
    notifyListeners();
  }

  Future<void> save(CompanySettings s) async {
    await db.saveSettings(s);
    _settings = s;
    notifyListeners();
  }
}
