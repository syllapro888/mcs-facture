import 'dart:convert';

/// Étapes d'une commande passée en Chine.
enum ChinaOrderStatus {
  commandee('Commandée'),
  payee('Payée'),
  expediee('Expédiée'),
  arrivee('Arrivée'),
  annulee('Annulée');

  const ChinaOrderStatus(this.label);
  final String label;

  static ChinaOrderStatus parse(String? v) => ChinaOrderStatus.values
      .firstWhere((s) => s.name == v, orElse: () => ChinaOrderStatus.commandee);
}

/// Un article acheté en Chine (prix en yuan).
class ChinaItem {
  final String name;
  final double quantity;
  final double unitYuan;

  const ChinaItem({required this.name, this.quantity = 1, this.unitYuan = 0});

  double get totalYuan => quantity * unitYuan;

  Map<String, Object?> toJson() =>
      {'name': name, 'qty': quantity, 'yuan': unitYuan};

  factory ChinaItem.fromJson(Map<String, Object?> m) => ChinaItem(
        name: (m['name'] as String?) ?? '',
        quantity: (m['qty'] as num?)?.toDouble() ?? 1,
        unitYuan: (m['yuan'] as num?)?.toDouble() ?? 0,
      );
}

/// Commande fournisseur en Chine : prix en yuan, conversion en FCFA,
/// frais de transport, captures (paiement Alipay, discussions…).
class ChinaOrder {
  final int? id;
  final String reference; // n° de commande fournisseur
  final String supplier;
  final DateTime date;
  final ChinaOrderStatus status;
  final double rate; // FCFA pour 1 yuan
  final int shipping; // transport en FCFA
  final int otherFees; // douane, frais Alipay… en FCFA
  final String tracking; // transporteur / n° de suivi
  final String notes;
  final List<ChinaItem> items;
  final List<String> photos; // captures (chemins relatifs)
  final DateTime createdAt;

  const ChinaOrder({
    this.id,
    this.reference = '',
    this.supplier = '',
    required this.date,
    this.status = ChinaOrderStatus.commandee,
    this.rate = 0,
    this.shipping = 0,
    this.otherFees = 0,
    this.tracking = '',
    this.notes = '',
    this.items = const [],
    this.photos = const [],
    required this.createdAt,
  });

  double get totalYuan => items.fold(0, (s, i) => s + i.totalYuan);

  /// Marchandise convertie en FCFA.
  int get goodsFcfa => (totalYuan * rate).round();

  /// Coût total : marchandise + transport + autres frais.
  int get totalFcfa => goodsFcfa + shipping + otherFees;

  double get totalQuantity => items.fold(0, (s, i) => s + i.quantity);

  /// Prix de revient d'une unité de [item] : son prix converti, plus sa part
  /// des frais (répartis selon la valeur de chaque article).
  int unitCost(ChinaItem item) {
    if (item.quantity <= 0) return 0;
    final itemFcfa = item.totalYuan * rate;
    final fees = shipping + otherFees;
    double share;
    if (totalYuan > 0) {
      share = fees * item.totalYuan / totalYuan;
    } else if (totalQuantity > 0) {
      share = fees * item.quantity / totalQuantity;
    } else {
      share = 0;
    }
    return ((itemFcfa + share) / item.quantity).round();
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'reference': reference,
        'supplier': supplier,
        'date': date.toIso8601String(),
        'status': status.name,
        'rate': rate,
        'shipping': shipping,
        'other_fees': otherFees,
        'tracking': tracking,
        'notes': notes,
        'items': jsonEncode([for (final i in items) i.toJson()]),
        'photos': jsonEncode(photos),
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  static List<Object?> _list(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final v = jsonDecode(raw);
      return v is List ? v : const [];
    } catch (_) {
      return const [];
    }
  }

  factory ChinaOrder.fromMap(Map<String, Object?> m) => ChinaOrder(
        id: m['id'] as int?,
        reference: (m['reference'] as String?) ?? '',
        supplier: (m['supplier'] as String?) ?? '',
        date: DateTime.tryParse((m['date'] as String?) ?? '') ?? DateTime.now(),
        status: ChinaOrderStatus.parse(m['status'] as String?),
        rate: (m['rate'] as num?)?.toDouble() ?? 0,
        shipping: (m['shipping'] as num?)?.toInt() ?? 0,
        otherFees: (m['other_fees'] as num?)?.toInt() ?? 0,
        tracking: (m['tracking'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
        items: [
          for (final e in _list(m['items']))
            if (e is Map) ChinaItem.fromJson(e.cast<String, Object?>())
        ],
        photos: [
          for (final e in _list(m['photos']))
            if (e is String) e
        ],
        createdAt: DateTime.tryParse((m['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );
}
