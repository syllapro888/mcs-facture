import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/client.dart';
import '../models/company_settings.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/product.dart';

/// Base SQLite locale. Les mises à jour du schéma ajoutent des colonnes
/// sans jamais supprimer les factures ni les photos.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _version = 2;
  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    String path;
    if (kIsWeb) {
      // Navigateur : base SQLite conservée dans le stockage de Safari/Chrome.
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      path = 'mcs_facture.db';
    } else {
      path = p.join(await getDatabasesPath(), 'mcs_facture.db');
    }
    final opened = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) => _create(db),
      onUpgrade: (db, oldV, newV) async {
        // Migrations : on ajoute, on ne supprime jamais.
        if (oldV < 2) await _createFiles(db);
      },
    );
    _db = opened;
    return opened;
  }

  static Future<void> _create(Database db) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT,
        unit TEXT,
        price INTEGER NOT NULL DEFAULT 0,
        photo_path TEXT,
        created_at TEXT
      )''');
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        email TEXT,
        notes TEXT
      )''');
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        number TEXT NOT NULL UNIQUE,
        year INTEGER NOT NULL,
        seq INTEGER NOT NULL,
        date TEXT NOT NULL,
        client_id INTEGER,
        client_name TEXT,
        client_phone TEXT,
        client_address TEXT,
        notes TEXT,
        payment_terms TEXT,
        status TEXT NOT NULL,
        vat_enabled INTEGER NOT NULL DEFAULT 0,
        vat_rate REAL NOT NULL DEFAULT 0,
        global_discount INTEGER NOT NULL DEFAULT 0,
        amount_paid INTEGER NOT NULL DEFAULT 0,
        total INTEGER,
        created_at TEXT,
        updated_at TEXT
      )''');
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        is_labor INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        description TEXT,
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT,
        unit_price INTEGER,
        discount INTEGER NOT NULL DEFAULT 0,
        photo_path TEXT,
        product_id INTEGER
      )''');
    await db.execute(
        'CREATE INDEX idx_items_invoice ON invoice_items(invoice_id)');
    await _createFiles(db);
  }

  /// Photos de la version web (sur téléphone, ce sont des fichiers).
  static Future<void> _createFiles(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS files (
        path TEXT PRIMARY KEY,
        data BLOB NOT NULL
      )''');

  Future<void> writeFile(String path, Uint8List bytes) async {
    await (await db).insert('files', {'path': path, 'data': bytes},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Uint8List?> readFile(String path) async {
    final rows = await (await db)
        .query('files', where: 'path = ?', whereArgs: [path], limit: 1);
    if (rows.isEmpty) return null;
    final data = rows.first['data'];
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    return null;
  }

  Future<Map<String, Uint8List>> allFiles() async {
    final rows = await (await db).query('files');
    return {
      for (final r in rows)
        if (r['data'] is List<int>)
          r['path'] as String: Uint8List.fromList(r['data'] as List<int>)
    };
  }

  /// Contrôle de la version web : compte les ouvertures (doit augmenter
  /// d'une ouverture à l'autre si les données sont bien conservées).
  Future<int> countOpening() async {
    final d = await db;
    final rows =
        await d.query('settings', where: 'key = ?', whereArgs: ['web_opens']);
    final n = (rows.isEmpty ? 0 : int.tryParse('${rows.first['value']}') ?? 0) + 1;
    await d.insert('settings', {'key': 'web_opens', 'value': '$n'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return n;
  }

  // ---------- Paramètres ----------

  Future<CompanySettings> loadSettings() async {
    final rows = await (await db)
        .query('settings', where: 'key = ?', whereArgs: ['company']);
    return CompanySettings.decode(
        rows.isEmpty ? null : rows.first['value'] as String?);
  }

  Future<void> saveSettings(CompanySettings s) async {
    await (await db).insert('settings', {'key': 'company', 'value': s.encode()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- Produits ----------

  Future<List<Product>> products() async {
    final rows = await (await db)
        .query('products', orderBy: 'category COLLATE NOCASE, name COLLATE NOCASE');
    return rows.map(Product.fromMap).toList();
  }

  Future<int> saveProduct(Product prod) async {
    final d = await db;
    final map = prod.toMap()..remove('id');
    if (prod.id == null) return d.insert('products', map);
    await d.update('products', map, where: 'id = ?', whereArgs: [prod.id]);
    return prod.id!;
  }

  Future<void> deleteProduct(int id) async =>
      (await db).delete('products', where: 'id = ?', whereArgs: [id]);

  // ---------- Clients ----------

  Future<List<Client>> clients() async {
    final rows =
        await (await db).query('clients', orderBy: 'name COLLATE NOCASE');
    return rows.map(Client.fromMap).toList();
  }

  Future<int> saveClient(Client c) async {
    final d = await db;
    final map = c.toMap()..remove('id');
    if (c.id == null) return d.insert('clients', map);
    await d.update('clients', map, where: 'id = ?', whereArgs: [c.id]);
    return c.id!;
  }

  Future<void> deleteClient(int id) async =>
      (await db).delete('clients', where: 'id = ?', whereArgs: [id]);

  // ---------- Factures ----------

  /// Liste sans les lignes (rapide). Les lignes sont chargées à l'ouverture.
  Future<List<Invoice>> invoiceHeaders() async {
    final rows = await (await db)
        .query('invoices', orderBy: 'date DESC, seq DESC');
    return rows.map((m) => Invoice.fromMap(m)).toList();
  }

  /// Totaux mémorisés (id -> total, null = à préciser).
  Future<Map<int, int?>> storedTotals() async {
    final rows = await (await db).query('invoices', columns: ['id', 'total']);
    return {
      for (final r in rows) r['id'] as int: (r['total'] as num?)?.toInt()
    };
  }

  Future<Invoice?> invoice(int id) async {
    final d = await db;
    final rows = await d.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final items = await d.query('invoice_items',
        where: 'invoice_id = ?', whereArgs: [id], orderBy: 'position');
    return Invoice.fromMap(rows.first, items.map(InvoiceItem.fromMap).toList());
  }

  Future<int> maxSeq(DocumentType type, int year) async {
    final rows = await (await db).rawQuery(
        'SELECT MAX(seq) AS m FROM invoices WHERE type = ? AND year = ?',
        [type.name, year]);
    return (rows.first['m'] as num?)?.toInt() ?? 0;
  }

  Future<bool> numberExists(String number, {int? exceptId}) async {
    final rows = await (await db).query('invoices',
        columns: ['id'], where: 'number = ?', whereArgs: [number]);
    return rows.any((r) => r['id'] != exceptId);
  }

  Future<int> saveInvoice(Invoice inv) async {
    final d = await db;
    return d.transaction((txn) async {
      final map = inv.toMap()..remove('id');
      int id;
      if (inv.id == null) {
        id = await txn.insert('invoices', map);
      } else {
        id = inv.id!;
        await txn.update('invoices', map, where: 'id = ?', whereArgs: [id]);
        await txn
            .delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      }
      for (var i = 0; i < inv.items.length; i++) {
        await txn.insert('invoice_items', inv.items[i].toMap(id, i));
      }
      return id;
    });
  }

  Future<void> updateStatus(int id, InvoiceStatus status, int amountPaid) async {
    await (await db).update(
      'invoices',
      {
        'status': status.name,
        'amount_paid': amountPaid,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteInvoice(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      await txn.delete('invoices', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------- Sauvegarde ----------

  static const backupTables = [
    'settings',
    'products',
    'clients',
    'invoices',
    'invoice_items'
  ];

  Future<Map<String, List<Map<String, Object?>>>> dumpAll() async {
    final d = await db;
    return {for (final t in backupTables) t: await d.query(t)};
  }

  /// Remplace toutes les données par celles de la sauvegarde (transaction :
  /// en cas d'erreur, rien n'est modifié).
  Future<void> restoreAll(Map<String, List<Map<String, Object?>>> data) async {
    final d = await db;
    await d.transaction((txn) async {
      for (final t in backupTables.reversed) {
        await txn.delete(t);
      }
      for (final t in backupTables) {
        for (final row in data[t] ?? const <Map<String, Object?>>[]) {
          await txn.insert(t, row);
        }
      }
    });
  }
}
