import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/job_expense.dart';

class JobExpenseProvider extends ChangeNotifier {
  JobExpenseProvider(this.db);
  final AppDatabase db;

  List<JobExpense> _items = [];
  List<JobExpense> get items => _items;
  bool loading = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      _items = await db.jobExpenses();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save(JobExpense e) async {
    await db.saveJobExpense(e);
    await load();
  }

  Future<void> delete(JobExpense e) async {
    if (e.id == null) return;
    await db.deleteJobExpense(e.id!);
    await load();
  }

  /// Total des dépenses des chantiers en cours.
  int get openTotal => _items
      .where((e) => e.status == JobStatus.enCours)
      .fold(0, (s, e) => s + e.total);
}
