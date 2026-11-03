import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/client.dart';

class ClientProvider extends ChangeNotifier {
  ClientProvider(this.db);
  final AppDatabase db;

  List<Client> _clients = [];
  List<Client> get clients => _clients;

  Future<void> load() async {
    _clients = await db.clients();
    notifyListeners();
  }

  List<Client> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _clients;
    return _clients
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')) ||
            c.address.toLowerCase().contains(q))
        .toList();
  }

  Future<Client> save(Client c) async {
    final id = await db.saveClient(c);
    await load();
    return c.copyWith(id: id);
  }

  Future<void> delete(Client c) async {
    if (c.id == null) return;
    await db.deleteClient(c.id!);
    await load();
  }
}
