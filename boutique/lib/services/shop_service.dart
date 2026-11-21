import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';

final _db = FirebaseFirestore.instance;

/// Lecture / écriture dans la base Firebase partagée avec MCS Facture.
class ShopService {
  ShopService._();

  static Stream<List<ShopProduct>> products() => _db
      .collection('products')
      .snapshots()
      .map((s) => s.docs.map(ShopProduct.fromDoc).toList()
        ..sort((a, b) => b.sort.compareTo(a.sort)));

  static Stream<ShopInfo> info() => _db
      .collection('shop')
      .doc('info')
      .snapshots()
      .map((d) => ShopInfo.fromMap(d.data()));

  /// Grande photo d'un article (null si absente).
  static Future<String?> photo(String pid) async {
    try {
      final d = await _db.collection('photos').doc(pid).get();
      return d.data()?['data'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ---------- Commandes ----------

  static Stream<List<ShopOrder>> myOrders(String uid) => _db
      .collection('orders')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(ShopOrder.fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  static Future<String> placeOrder({
    required String uid,
    required String clientName,
    required String phone,
    required String email,
    required String address,
    required String note,
    required List<OrderLine> items,
    required Payment payment,
    String? proof,
  }) async {
    final ref = _db.collection('orders').doc();
    final batch = _db.batch();
    batch.set(ref, {
      'uid': uid,
      'clientName': clientName,
      'phone': phone,
      'email': email,
      'address': address,
      'note': note,
      'items': [for (final i in items) i.toMap()],
      'total': items.fold<int>(0, (s, i) => s + i.total),
      'payment': payment.name,
      'status': OrderStatus.attente.name,
      'proof': proof,
      'ownerSeen': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Un prix négocié ne sert qu'une fois.
    for (final i in items) {
      if (i.offerId != null) {
        batch.update(_db.collection('offers').doc(i.offerId), {
          'status': OfferStatus.utilisee.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
    return ref.id;
  }

  // ---------- Discussion de prix ----------

  static Stream<List<PriceOffer>> myOffers(String uid) => _db
      .collection('offers')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(PriceOffer.fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// Le client propose un prix : l'offre est enregistrée et apparaît aussi
  /// dans la discussion pour prévenir MCS VISION.
  static Future<void> proposePrice({
    required String uid,
    required String clientName,
    required String phone,
    required ShopProduct product,
    required int price,
    required int qty,
    String note = '',
  }) async {
    final offer = _db.collection('offers').doc();
    final chat = _db.collection('chats').doc(uid);
    final text = 'Je propose ${fcfa(price)} au lieu de ${fcfa(product.price)}'
        '${qty > 1 ? ' (× $qty ${product.unit})' : ''}.'
        '${note.isNotEmpty ? '\n$note' : ''}';
    final batch = _db.batch();
    batch.set(offer, {
      'uid': uid,
      'clientName': clientName,
      'phone': phone,
      'pid': product.id,
      'productName': product.name,
      'listPrice': product.price,
      'price': price,
      'qty': qty,
      'unit': product.unit,
      'note': note,
      'status': OfferStatus.attente.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(chat.collection('messages').doc(), {
      'from': 'client',
      'text': text,
      'pid': product.id,
      'productName': product.name,
      'productPrice': product.price,
      'offerId': offer.id,
      'offerPrice': price,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
        chat,
        {
          'uid': uid,
          'clientName': clientName,
          'phone': phone,
          'lastText': '💰 Offre : ${fcfa(price)} • ${product.name}',
          'lastFrom': 'client',
          'lastAt': FieldValue.serverTimestamp(),
          'unreadOwner': FieldValue.increment(1),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> cancelOffer(PriceOffer o) =>
      _db.collection('offers').doc(o.id).update({
        'status': OfferStatus.annulee.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Réponse du client à une contre-offre de MCS VISION.
  static Future<void> answerCounter(PriceOffer o, {required bool accept}) =>
      _db.collection('offers').doc(o.id).update({
        'status': (accept ? OfferStatus.acceptee : OfferStatus.refusee).name,
        if (accept && o.counter != null) 'price': o.counter,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> addProof(String orderId, String proof) =>
      _db.collection('orders').doc(orderId).update({
        'proof': proof,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> cancelOrder(String orderId) =>
      _db.collection('orders').doc(orderId).update({
        'status': OrderStatus.annulee.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ---------- Discussion ----------

  static Stream<List<ChatMessage>> messages(String uid) => _db
      .collection('chats')
      .doc(uid)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  /// Nombre de messages de MCS VISION non lus.
  static Stream<int> unread(String uid) => _db
      .collection('chats')
      .doc(uid)
      .snapshots()
      .map((d) => (d.data()?['unreadClient'] as num?)?.toInt() ?? 0);

  static Future<void> markRead(String uid) => _db
      .collection('chats')
      .doc(uid)
      .set({'unreadClient': 0}, SetOptions(merge: true));

  static Future<void> send({
    required String uid,
    required String clientName,
    required String phone,
    String text = '',
    ShopProduct? product,
    String? image,
  }) async {
    final chat = _db.collection('chats').doc(uid);
    final batch = _db.batch();
    batch.set(chat.collection('messages').doc(), {
      'from': 'client',
      'text': text,
      if (product != null) 'pid': product.id,
      if (product != null) 'productName': product.name,
      if (product != null) 'productPrice': product.price,
      if (image != null) 'image': image,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
        chat,
        {
          'uid': uid,
          'clientName': clientName,
          'phone': phone,
          'lastText': text.isNotEmpty
              ? text
              : (image != null ? '📷 Photo' : '🛒 ${product?.name ?? ''}'),
          'lastFrom': 'client',
          'lastAt': FieldValue.serverTimestamp(),
          'unreadOwner': FieldValue.increment(1),
        },
        SetOptions(merge: true));
    await batch.commit();
  }
}

/// Client connecté et son profil (nom, téléphone, adresse).
class Session extends ChangeNotifier {
  Session() {
    _sub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  late final StreamSubscription<User?> _sub;
  User? user;
  String name = '';
  String phone = '';
  String address = '';
  bool ready = false;

  bool get signedIn => user != null;
  String get uid => user?.uid ?? '';
  String get email => user?.email ?? '';

  Future<void> _onUser(User? u) async {
    user = u;
    if (u != null) {
      try {
        final d = await _db.collection('users').doc(u.uid).get();
        final m = d.data() ?? const {};
        name = (m['name'] as String?) ?? u.displayName ?? '';
        phone = (m['phone'] as String?) ?? '';
        address = (m['address'] as String?) ?? '';
      } catch (_) {
        name = u.displayName ?? '';
      }
    } else {
      name = phone = address = '';
    }
    ready = true;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final u = cred.user!;
    await u.updateDisplayName(name);
    await _db.collection('users').doc(u.uid).set({
      'name': name,
      'phone': phone,
      'email': email,
      'address': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _onUser(u);
  }

  Future<void> login(String email, String password) => FirebaseAuth.instance
      .signInWithEmailAndPassword(email: email, password: password);

  Future<void> resetPassword(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email);

  Future<void> logout() => FirebaseAuth.instance.signOut();

  Future<void> saveProfile(
      {required String name,
      required String phone,
      required String address}) async {
    if (user == null) return;
    await _db.collection('users').doc(uid).set({
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
    }, SetOptions(merge: true));
    this.name = name;
    this.phone = phone;
    this.address = address;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Ligne du panier. Un article au prix négocié a sa propre ligne,
/// avec la quantité fixée par l'offre acceptée.
class CartLine {
  final ShopProduct product;
  final int qty;
  final PriceOffer? offer;

  const CartLine(this.product, this.qty, [this.offer]);

  String get key => offer == null ? product.id : 'offer:${offer!.id}';
  int get unitPrice => offer?.price ?? product.price;
  int get total => unitPrice * qty;
  bool get negotiated => offer != null;

  OrderLine toOrderLine() => OrderLine(
        pid: product.id,
        name: product.name,
        price: unitPrice,
        qty: qty,
        unit: product.unit,
        offerId: offer?.id,
        listPrice: offer == null ? null : product.price,
      );
}

/// Panier.
class Cart extends ChangeNotifier {
  final Map<String, CartLine> _lines = {};

  List<CartLine> get lines => _lines.values.toList();
  int get count => _lines.values.fold(0, (s, l) => s + l.qty);
  int get total => _lines.values.fold(0, (s, l) => s + l.total);
  bool get isEmpty => _lines.isEmpty;

  void add(ShopProduct p, [int qty = 1]) {
    final cur = _lines[p.id]?.qty ?? 0;
    _lines[p.id] = CartLine(p, cur + qty);
    notifyListeners();
  }

  /// Ajoute un article au prix accepté par MCS VISION.
  void addOffer(ShopProduct p, PriceOffer o) {
    final line = CartLine(p, o.qty, o);
    _lines[line.key] = line;
    notifyListeners();
  }

  bool hasOffer(String offerId) => _lines.containsKey('offer:$offerId');

  void setQty(CartLine line, int qty) {
    if (qty <= 0) {
      _lines.remove(line.key);
    } else if (!line.negotiated) {
      _lines[line.key] = CartLine(line.product, qty);
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  List<OrderLine> toOrderLines() =>
      [for (final l in _lines.values) l.toOrderLine()];
}

/// Message d'erreur Firebase compréhensible.
String authError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet e-mail. Connectez-vous.';
      case 'weak-password':
        return 'Mot de passe trop court (6 caractères minimum).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      case 'network-request-failed':
        return 'Pas de connexion Internet.';
      case 'too-many-requests':
        return 'Trop d’essais. Réessayez dans quelques minutes.';
    }
    return e.message ?? e.code;
  }
  return '$e';
}
