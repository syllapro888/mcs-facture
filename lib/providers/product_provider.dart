import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/product.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider(this.db);
  final AppDatabase db;

  List<Product> _products = [];
  List<Product> get products => _products;
  bool loading = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      _products = await db.products();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<Product> search(String query, {String? category}) {
    final q = query.trim().toLowerCase();
    return _products.where((p) {
      if (category != null && p.category != category) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> save(Product p) async {
    await db.saveProduct(p);
    await load();
  }

  /// Ajout rapide : plusieurs produits enregistrés en une fois.
  Future<void> saveAll(List<Product> list) async {
    if (list.isEmpty) return;
    await db.insertProducts(list);
    await load();
  }

  /// Publie ou retire de MCS Boutique.
  Future<void> setPublished(Iterable<Product> list, bool published) async {
    await db.setPublished(
        [for (final p in list) if (p.id != null) p.id!], published);
    await load();
  }

  int get publishedCount => _products.where((p) => p.published).length;

  Future<void> delete(Product p) async {
    if (p.id == null) return;
    await db.deleteProduct(p.id!);
    await load();
  }
}
