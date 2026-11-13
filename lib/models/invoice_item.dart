/// Une ligne de facture : fourniture ou prestation de main-d'œuvre.
///
/// Les informations (désignation, prix, photo) sont COPIÉES depuis le
/// catalogue : modifier le catalogue ne change pas une facture existante.
class InvoiceItem {
  final int? id;
  final bool isLabor;
  final String name;
  final String description;
  final double quantity;
  final String unit;

  /// Prix unitaire en FCFA. Null = « À préciser » (main-d'œuvre inconnue).
  final int? unitPrice;
  final int discount;
  final String? photoPath;
  final int? productId;

  const InvoiceItem({
    this.id,
    this.isLabor = false,
    required this.name,
    this.description = '',
    this.quantity = 1,
    this.unit = 'pièce',
    this.unitPrice,
    this.discount = 0,
    this.photoPath,
    this.productId,
  });

  /// Montant de la ligne = quantité × prix unitaire − remise.
  /// Null si le prix n'est pas encore connu.
  int? get lineTotal {
    final price = unitPrice;
    if (price == null) return null;
    final total = (quantity * price).round() - discount;
    return total < 0 ? 0 : total;
  }

  InvoiceItem copyWith({
    bool? isLabor,
    String? name,
    String? description,
    double? quantity,
    String? unit,
    int? unitPrice,
    bool clearPrice = false,
    int? discount,
    String? photoPath,
    bool clearPhoto = false,
    int? productId,
  }) =>
      InvoiceItem(
        id: null,
        isLabor: isLabor ?? this.isLabor,
        name: name ?? this.name,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        unitPrice: clearPrice ? null : (unitPrice ?? this.unitPrice),
        discount: discount ?? this.discount,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        productId: productId ?? this.productId,
      );

  Map<String, Object?> toMap(int invoiceId, int position) => {
        'invoice_id': invoiceId,
        'position': position,
        'is_labor': isLabor ? 1 : 0,
        'name': name,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'discount': discount,
        'photo_path': photoPath,
        'product_id': productId,
      };

  factory InvoiceItem.fromMap(Map<String, Object?> m) => InvoiceItem(
        id: m['id'] as int?,
        isLabor: (m['is_labor'] as int? ?? 0) == 1,
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
        unit: (m['unit'] as String?) ?? 'pièce',
        unitPrice: (m['unit_price'] as num?)?.toInt(),
        discount: (m['discount'] as num?)?.toInt() ?? 0,
        photoPath: m['photo_path'] as String?,
        productId: m['product_id'] as int?,
      );

  /// Trie les lignes par montant total, du plus élevé au plus bas.
  /// Les lignes « À préciser » (sans prix) vont à la fin.
  /// Tri stable : à montant égal, l'ordre d'origine est conservé.
  static List<InvoiceItem> sortByTotalDesc(Iterable<InvoiceItem> items) {
    final indexed = items.toList().asMap().entries.toList();
    indexed.sort((a, b) {
      final ta = a.value.lineTotal;
      final tb = b.value.lineTotal;
      if (ta == null && tb != null) return 1;
      if (ta != null && tb == null) return -1;
      if (ta != null && tb != null && ta != tb) return tb.compareTo(ta);
      return a.key.compareTo(b.key);
    });
    return [for (final e in indexed) e.value];
  }

  /// Vrai si les lignes sont déjà dans l'ordre de [sortByTotalDesc].
  static bool isSortedByTotalDesc(List<InvoiceItem> items) {
    final sorted = sortByTotalDesc(items);
    for (var i = 0; i < items.length; i++) {
      if (!identical(sorted[i], items[i])) return false;
    }
    return true;
  }
}
