import 'package:cloud_firestore/cloud_firestore.dart';

/// Montant en francs CFA : 125 000 FCFA
String fcfa(num v) {
  final digits = v.abs().round().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(' ');
    b.write(digits[i]);
  }
  return '$b FCFA';
}

DateTime _date(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();

/// Article publié par MCS Facture.
class ShopProduct {
  final String id;
  final String name;
  final String description;
  final String category;
  final String unit;
  final int price;
  final String? thumb; // petite photo (base64)
  final bool hasPhoto;
  final int sort;

  const ShopProduct({
    required this.id,
    required this.name,
    this.description = '',
    this.category = '',
    this.unit = 'pièce',
    this.price = 0,
    this.thumb,
    this.hasPhoto = false,
    this.sort = 0,
  });

  factory ShopProduct.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return ShopProduct(
      id: d.id,
      name: (m['name'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      category: (m['category'] as String?) ?? '',
      unit: (m['unit'] as String?) ?? 'pièce',
      price: (m['price'] as num?)?.toInt() ?? 0,
      thumb: m['thumb'] as String?,
      hasPhoto: (m['hasPhoto'] as bool?) ?? false,
      sort: (m['sort'] as num?)?.toInt() ?? 0,
    );
  }

  /// Services (installation, main-d'œuvre) : on propose un devis.
  bool get isService {
    final c = category.toLowerCase();
    return c.contains('installation') || c.contains('main');
  }
}

/// Numéro Mobile Money affiché au client.
class MomoAccount {
  final String operator; // ex. MTN Mobile Money
  final String number;
  final String holder;

  const MomoAccount(this.operator, this.number, this.holder);

  factory MomoAccount.fromMap(Map m) => MomoAccount(
        (m['operator'] as String?) ?? 'Mobile Money',
        (m['number'] as String?) ?? '',
        (m['name'] as String?) ?? '',
      );
}

/// Coordonnées de la boutique (écrites par MCS Facture).
class ShopInfo {
  final String name;
  final String slogan;
  final String phones;
  final String whatsapp; // chiffres uniquement, ex. 242069981616
  final List<MomoAccount> momo;

  const ShopInfo({
    this.name = 'MCS VISION',
    this.slogan = 'Informatique • Caméras • Installation',
    this.phones = '+242 069 981 616',
    this.whatsapp = '242069981616',
    this.momo = const [],
  });

  factory ShopInfo.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ShopInfo();
    const d = ShopInfo();
    String s(String k, String def) {
      final v = (m[k] as String?)?.trim() ?? '';
      return v.isEmpty ? def : v;
    }

    return ShopInfo(
      name: s('name', d.name),
      slogan: s('slogan', d.slogan),
      phones: s('phones', d.phones),
      whatsapp: s('whatsapp', d.whatsapp).replaceAll(RegExp(r'\D'), ''),
      momo: [
        for (final e in (m['momo'] as List?) ?? const [])
          if (e is Map) MomoAccount.fromMap(e)
      ],
    );
  }
}

/// Moyens de paiement.
enum Payment {
  momo('Mobile Money'),
  cash('Paiement à la réception'),
  alipay('Alipay');

  const Payment(this.label);
  final String label;

  static Payment parse(String? v) =>
      Payment.values.firstWhere((p) => p.name == v, orElse: () => Payment.cash);
}

/// Étapes d'une commande.
enum OrderStatus {
  attente('En attente de confirmation'),
  confirmee('Confirmée'),
  livree('Livrée'),
  annulee('Annulée');

  const OrderStatus(this.label);
  final String label;

  static OrderStatus parse(String? v) => OrderStatus.values
      .firstWhere((s) => s.name == v, orElse: () => OrderStatus.attente);
}

class OrderLine {
  final String pid;
  final String name;
  final int price;
  final int qty;
  final String unit;

  /// Prix négocié : offre acceptée et prix affiché d'origine.
  final String? offerId;
  final int? listPrice;

  const OrderLine(
      {required this.pid,
      required this.name,
      required this.price,
      required this.qty,
      this.unit = 'pièce',
      this.offerId,
      this.listPrice});

  int get total => price * qty;
  bool get negotiated => offerId != null;

  Map<String, Object?> toMap() => {
        'pid': pid,
        'name': name,
        'price': price,
        'qty': qty,
        'unit': unit,
        if (offerId != null) 'offerId': offerId,
        if (listPrice != null) 'listPrice': listPrice,
      };

  factory OrderLine.fromMap(Map m) => OrderLine(
        pid: (m['pid'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        price: (m['price'] as num?)?.toInt() ?? 0,
        qty: (m['qty'] as num?)?.toInt() ?? 1,
        unit: (m['unit'] as String?) ?? 'pièce',
        offerId: m['offerId'] as String?,
        listPrice: (m['listPrice'] as num?)?.toInt(),
      );
}

/// Étapes d'une proposition de prix.
enum OfferStatus {
  attente('En attente de réponse'),
  contre('Contre-offre de MCS VISION'),
  acceptee('Acceptée'),
  refusee('Refusée'),
  annulee('Annulée'),
  utilisee('Commandée');

  const OfferStatus(this.label);
  final String label;

  static OfferStatus parse(String? v) => OfferStatus.values
      .firstWhere((s) => s.name == v, orElse: () => OfferStatus.attente);
}

/// Prix proposé par un client pour un article (discussion de prix).
class PriceOffer {
  final String id;
  final String uid;
  final String pid;
  final String productName;
  final int listPrice; // prix affiché
  final int price; // prix proposé par le client (ou contre-offre acceptée)
  final int? counter; // contre-offre de MCS VISION
  final int qty;
  final String unit;
  final OfferStatus status;
  final DateTime createdAt;

  const PriceOffer({
    required this.id,
    required this.uid,
    required this.pid,
    required this.productName,
    required this.listPrice,
    required this.price,
    this.counter,
    this.qty = 1,
    this.unit = 'pièce',
    this.status = OfferStatus.attente,
    required this.createdAt,
  });

  /// Offre encore en cours (ni refusée, ni annulée, ni commandée).
  bool get open =>
      status == OfferStatus.attente ||
      status == OfferStatus.contre ||
      status == OfferStatus.acceptee;

  /// Réduction obtenue par rapport au prix affiché, en %.
  int get discountPercent => listPrice <= 0
      ? 0
      : ((listPrice - price) * 100 / listPrice).round().clamp(0, 100);

  factory PriceOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return PriceOffer(
      id: d.id,
      uid: (m['uid'] as String?) ?? '',
      pid: (m['pid'] as String?) ?? '',
      productName: (m['productName'] as String?) ?? '',
      listPrice: (m['listPrice'] as num?)?.toInt() ?? 0,
      price: (m['price'] as num?)?.toInt() ?? 0,
      counter: (m['counter'] as num?)?.toInt(),
      qty: (m['qty'] as num?)?.toInt() ?? 1,
      unit: (m['unit'] as String?) ?? 'pièce',
      status: OfferStatus.parse(m['status'] as String?),
      createdAt: _date(m['createdAt']),
    );
  }
}

class ShopOrder {
  final String id;
  final String uid;
  final String clientName;
  final String phone;
  final String address;
  final String note;
  final List<OrderLine> items;
  final int total;
  final Payment payment;
  final OrderStatus status;
  final String? proof; // capture du paiement (base64)
  final DateTime createdAt;

  const ShopOrder({
    required this.id,
    required this.uid,
    required this.clientName,
    required this.phone,
    required this.address,
    required this.note,
    required this.items,
    required this.total,
    required this.payment,
    required this.status,
    this.proof,
    required this.createdAt,
  });

  String get shortId => id.length > 6 ? id.substring(0, 6).toUpperCase() : id;

  bool get needsProof =>
      payment == Payment.momo &&
      status == OrderStatus.attente &&
      (proof == null || proof!.isEmpty);

  factory ShopOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return ShopOrder(
      id: d.id,
      uid: (m['uid'] as String?) ?? '',
      clientName: (m['clientName'] as String?) ?? '',
      phone: (m['phone'] as String?) ?? '',
      address: (m['address'] as String?) ?? '',
      note: (m['note'] as String?) ?? '',
      items: [
        for (final e in (m['items'] as List?) ?? const [])
          if (e is Map) OrderLine.fromMap(e)
      ],
      total: (m['total'] as num?)?.toInt() ?? 0,
      payment: Payment.parse(m['payment'] as String?),
      status: OrderStatus.parse(m['status'] as String?),
      proof: m['proof'] as String?,
      createdAt: _date(m['createdAt']),
    );
  }
}

class ChatMessage {
  final String id;
  final bool fromClient;
  final String text;
  final String? productName;
  final int? productPrice;
  final int? offerPrice; // prix proposé (discussion de prix)
  final String? image;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.fromClient,
    required this.text,
    this.productName,
    this.productPrice,
    this.offerPrice,
    this.image,
    required this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return ChatMessage(
      id: d.id,
      fromClient: m['from'] != 'owner',
      text: (m['text'] as String?) ?? '',
      productName: m['productName'] as String?,
      productPrice: (m['productPrice'] as num?)?.toInt(),
      offerPrice: (m['offerPrice'] as num?)?.toInt(),
      image: m['image'] as String?,
      createdAt: _date(m['createdAt']),
    );
  }
}
