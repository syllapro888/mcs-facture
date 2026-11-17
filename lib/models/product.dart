class ProductCategories {
  static const List<String> all = [
    'Panneaux solaires',
    'Onduleurs',
    'Batteries',
    'Câbles électriques',
    'Connecteurs MC4',
    'Rails et fixations',
    'Coffrets de protection',
    'Caméras CCTV',
    'Installation caméras',
    'Ordinateurs',
    'Accessoires informatiques',
    'Réseau et Wi-Fi',
    'Main-d’œuvre',
    'Autres fournitures',
  ];
}

class Units {
  static const List<String> all = [
    'pièce',
    'mètre',
    'lot',
    'rouleau',
    'forfait',
    'jour',
    'heure',
    'kit',
  ];
}

class Product {
  final int? id;
  final String name;
  final String description;
  final String category;
  final String unit;
  final int price; // FCFA
  final String? photoPath; // chemin relatif
  final bool published; // visible dans MCS Boutique
  /// Catalogue boutique : n'apparaît pas au choix des articles d'une
  /// facture / d'un devis (sauf bouton « Catalogue boutique »).
  final bool shopOnly;
  final DateTime createdAt;

  const Product({
    this.id,
    required this.name,
    this.description = '',
    this.category = 'Autres fournitures',
    this.unit = 'pièce',
    this.price = 0,
    this.photoPath,
    this.published = false,
    this.shopOnly = false,
    required this.createdAt,
  });

  Product copyWith({
    int? id,
    String? name,
    String? description,
    String? category,
    String? unit,
    int? price,
    String? photoPath,
    bool clearPhoto = false,
    bool? published,
    bool? shopOnly,
    DateTime? createdAt,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        price: price ?? this.price,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        published: published ?? this.published,
        shopOnly: shopOnly ?? this.shopOnly,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'unit': unit,
        'price': price,
        'photo_path': photoPath,
        'published': published ? 1 : 0,
        'shop_only': shopOnly ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as int?,
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'Autres fournitures',
        unit: (m['unit'] as String?) ?? 'pièce',
        price: (m['price'] as num?)?.toInt() ?? 0,
        photoPath: m['photo_path'] as String?,
        published: ((m['published'] as num?) ?? 0) != 0,
        shopOnly: ((m['shop_only'] as num?) ?? 0) != 0,
        createdAt: DateTime.tryParse((m['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );
}
