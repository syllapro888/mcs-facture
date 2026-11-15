import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/china_order.dart';

class ChinaOrderProvider extends ChangeNotifier {
  ChinaOrderProvider(this.db);
  final AppDatabase db;

  static const _rateKey = 'china_rate';

  List<ChinaOrder> _orders = [];
  List<ChinaOrder> get orders => _orders;
  bool loading = false;

  /// Dernier taux utilisé (FCFA pour 1 yuan), proposé par défaut.
  double lastRate = 0;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      _orders = await db.chinaOrders();
      lastRate = double.tryParse(await db.getValue(_rateKey) ?? '') ?? 0;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save(ChinaOrder o) async {
    await db.saveChinaOrder(o);
    if (o.rate > 0) await db.setValue(_rateKey, '${o.rate}');
    await load();
  }

  Future<void> delete(ChinaOrder o) async {
    if (o.id == null) return;
    await db.deleteChinaOrder(o.id!);
    await load();
  }

  /// Montant total en cours (commandes non arrivées et non annulées).
  int get pendingTotal => _orders
      .where((o) =>
          o.status != ChinaOrderStatus.arrivee &&
          o.status != ChinaOrderStatus.annulee)
      .fold(0, (s, o) => s + o.totalFcfa);
}
