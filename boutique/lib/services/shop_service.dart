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
    await ref.set({
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
    return ref.id;
  }

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

/// Panier.
class Cart extends ChangeNotifier {
  final Map<String, (ShopProduct, int)> _lines = {};

  List<(ShopProduct, int)> get lines => _lines.values.toList();
  int get count => _lines.values.fold(0, (s, l) => s + l.$2);
  int get total => _lines.values.fold(0, (s, l) => s + l.$1.price * l.$2);
  bool get isEmpty => _lines.isEmpty;

  void add(ShopProduct p, [int qty = 1]) {
    final cur = _lines[p.id]?.$2 ?? 0;
    _lines[p.id] = (p, cur + qty);
    notifyListeners();
  }

  void setQty(ShopProduct p, int qty) {
    if (qty <= 0) {
      _lines.remove(p.id);
    } else {
      _lines[p.id] = (p, qty);
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  List<OrderLine> toOrderLines() => [
        for (final (p, q) in _lines.values)
          OrderLine(pid: p.id, name: p.name, price: p.price, qty: q, unit: p.unit)
      ];
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
