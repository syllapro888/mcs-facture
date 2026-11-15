import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../database/app_database.dart';
import '../firebase_options.dart';
import '../models/company_settings.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_paths.dart';

/// Réduit une photo en JPEG (en arrière-plan) : (octets, largeur max, qualité).
Uint8List? _resize((Uint8List, int, int) a) {
  final (bytes, maxSide, quality) = a;
  final im = img.decodeImage(bytes);
  if (im == null) return null;
  final big = im.width > im.height ? im.width : im.height;
  final out = big > maxSide
      ? (im.width >= im.height
          ? img.copyResize(im, width: maxSide)
          : img.copyResize(im, height: maxSide))
      : im;
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}

/// Lien avec MCS Boutique (base Firebase « mcs-vision ») :
/// - envoie les articles publiés et les coordonnées de l'entreprise ;
/// - reçoit les commandes et les messages des clients.
class ShopCloud extends ChangeNotifier {
  ShopCloud._();
  static final instance = ShopCloud._();

  /// false : pas de Firebase (iPhone natif, ou erreur au démarrage).
  static bool available = false;

  static Future<void> init() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) return;
    try {
      await Firebase.initializeApp(options: options)
          .timeout(const Duration(seconds: 15));
      available = true;
      instance._listenAuth();
    } catch (e) {
      debugPrint('Firebase indisponible : $e');
    }
  }

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? user;
  String? ownerUid;
  bool checking = false;
  String? error;

  bool get signedIn => user != null;
  bool get isOwner => user != null && ownerUid == user!.uid;

  /// Commandes en attente et discussions non lues (pastilles).
  int pendingOrders = 0;
  int unreadChats = 0;

  // Synchronisation du catalogue.
  bool syncing = false;
  int syncDone = 0;
  int syncTotal = 0;
  DateTime? lastSync;
  String? syncError;

  final List<StreamSubscription> _subs = [];
  Timer? _debounce;
  bool _again = false;
  ProductProvider? _products;
  SettingsProvider? _settings;

  void _listenAuth() {
    FirebaseAuth.instance.authStateChanges().listen((u) async {
      user = u;
      await _checkOwner();
      _startCounters();
      notifyListeners();
      if (isOwner) {
        _pushInfo();
        _scheduleSync(immediate: true);
      }
    });
  }

  /// Le premier compte connecté devient le propriétaire de la boutique.
  Future<void> _checkOwner() async {
    error = null;
    if (user == null) {
      ownerUid = null;
      return;
    }
    checking = true;
    notifyListeners();
    try {
      final ref = _db.collection('config').doc('owner');
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'uid': user!.uid,
          'email': user!.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        ownerUid = user!.uid;
      } else {
        ownerUid = snap.data()?['uid'] as String?;
      }
    } catch (e) {
      error = 'Impossible de vérifier le compte : $e';
    } finally {
      checking = false;
    }
  }

  void _startCounters() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    pendingOrders = 0;
    unreadChats = 0;
    if (!isOwner) return;
    _subs.add(_db
        .collection('orders')
        .where('status', isEqualTo: 'attente')
        .snapshots()
        .listen((s) {
      pendingOrders = s.size;
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(_db
        .collection('chats')
        .where('unreadOwner', isGreaterThan: 0)
        .snapshots()
        .listen((s) {
      unreadChats = s.size;
      notifyListeners();
    }, onError: (_) {}));
  }

  // ---------- Compte ----------

  Future<void> login(String email, String password) => FirebaseAuth.instance
      .signInWithEmailAndPassword(email: email, password: password);

  Future<void> register(String email, String password) => FirebaseAuth
      .instance
      .createUserWithEmailAndPassword(email: email, password: password);

  Future<void> resetPassword(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email);

  Future<void> logout() => FirebaseAuth.instance.signOut();

  // ---------- Liens avec l'application ----------

  /// Synchronise automatiquement quand le catalogue ou les paramètres changent.
  void attach(ProductProvider products, SettingsProvider settings) {
    if (!available || _products != null) return;
    _products = products;
    _settings = settings;
    products.addListener(_scheduleSync);
    settings.addListener(_pushInfo);
  }

  void _scheduleSync({bool immediate = false}) {
    if (!isOwner || _products == null) return;
    _debounce?.cancel();
    _debounce = Timer(Duration(seconds: immediate ? 1 : 3),
        () => syncProducts(_products!.products));
  }

  Future<void> _pushInfo() async {
    final s = _settings?.settings;
    if (!isOwner || s == null) return;
    try {
      await _db.collection('shop').doc('info').set(_infoFrom(s),
          SetOptions(merge: true));
    } catch (_) {}
  }

  static Map<String, Object?> _infoFrom(CompanySettings s) {
    final firstPhone = s.phones.split(RegExp(r'[\n,;/]')).first;
    return {
      'name': s.name,
      'slogan': s.slogan,
      'phones': s.phones.replaceAll('\n', ' • '),
      'email': s.email,
      'address': s.address,
      'whatsapp': firstPhone.replaceAll(RegExp(r'\D'), ''),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ---------- Catalogue ----------

  static const _stateKey = 'shop_sync';

  static String _signature(Product p) => [
        p.name,
        p.description,
        p.category,
        p.unit,
        p.price,
        p.photoPath ?? '',
      ].join('|');

  /// Envoie les articles publiés (seulement ceux qui ont changé) et retire
  /// de la boutique ceux qui ne sont plus publiés.
  Future<void> syncProducts(List<Product> all, {bool force = false}) async {
    if (!isOwner) return;
    if (syncing) {
      _again = true;
      return;
    }
    syncing = true;
    syncError = null;
    notifyListeners();
    final db = AppDatabase.instance;
    try {
      Map<String, String> state = {};
      if (!force) {
        try {
          final raw = jsonDecode(await db.getValue(_stateKey) ?? '{}');
          if (raw is Map) state = raw.map((k, v) => MapEntry('$k', '$v'));
        } catch (_) {}
      }
      final published = {
        for (final p in all)
          if (p.published && p.id != null) 'p${p.id}': p
      };
      final toSend = [
        for (final e in published.entries)
          if (state[e.key] != _signature(e.value)) e
      ];
      final toRemove = [
        for (final k in state.keys)
          if (!published.containsKey(k)) k
      ];
      syncTotal = toSend.length + toRemove.length;
      syncDone = 0;
      notifyListeners();

      for (final e in toSend) {
        await _sendProduct(e.key, e.value);
        state[e.key] = _signature(e.value);
        syncDone++;
        await db.setValue(_stateKey, jsonEncode(state));
        notifyListeners();
      }
      for (final pid in toRemove) {
        await _db.collection('products').doc(pid).delete();
        await _db.collection('photos').doc(pid).delete();
        state.remove(pid);
        syncDone++;
        await db.setValue(_stateKey, jsonEncode(state));
        notifyListeners();
      }
      lastSync = DateTime.now();
    } catch (e) {
      syncError = '$e';
    } finally {
      syncing = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      _scheduleSync();
    }
  }

  Future<void> _sendProduct(String pid, Product p) async {
    String? thumb;
    String? full;
    final bytes = await AppPaths.readPhoto(p.photoPath);
    if (bytes != null && bytes.isNotEmpty) {
      final t = await compute(_resize, (bytes, 360, 65));
      final f = await compute(_resize, (bytes, 1000, 72));
      if (t != null) thumb = base64Encode(t);
      if (f != null) full = base64Encode(f);
    }
    await _db.collection('products').doc(pid).set({
      'name': p.name,
      'description': p.description,
      'category': p.category,
      'unit': p.unit,
      'price': p.price,
      'thumb': thumb,
      'hasPhoto': full != null,
      'sort': p.createdAt.millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final photoRef = _db.collection('photos').doc(pid);
    if (full != null) {
      await photoRef.set({'data': full});
    } else {
      await photoRef.delete();
    }
  }

  // ---------- Coordonnées / Mobile Money ----------

  Stream<Map<String, dynamic>> info() => _db
      .collection('shop')
      .doc('info')
      .snapshots()
      .map((d) => d.data() ?? const {});

  Future<void> saveMomo(List<Map<String, String>> accounts) =>
      _db.collection('shop').doc('info').set(
          {'momo': accounts, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));

  // ---------- Commandes ----------

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> orders() => _db
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs);

  Future<void> setOrderStatus(String id, String status) =>
      _db.collection('orders').doc(id).update({
        'status': status,
        'ownerSeen': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ---------- Discussions ----------

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> chats() => _db
      .collection('chats')
      .orderBy('lastAt', descending: true)
      .limit(300)
      .snapshots()
      .map((s) => s.docs);

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> messages(String uid) =>
      _db
          .collection('chats')
          .doc(uid)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs);

  Future<void> markChatRead(String uid) => _db
      .collection('chats')
      .doc(uid)
      .set({'unreadOwner': 0}, SetOptions(merge: true));

  Future<void> sendMessage(String uid, {String text = '', String? image}) {
    final chat = _db.collection('chats').doc(uid);
    final batch = _db.batch();
    batch.set(chat.collection('messages').doc(), {
      'from': 'owner',
      'text': text,
      if (image != null) 'image': image,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
        chat,
        {
          'lastText': text.isNotEmpty ? text : '📷 Photo',
          'lastFrom': 'owner',
          'lastAt': FieldValue.serverTimestamp(),
          'unreadClient': FieldValue.increment(1),
          'unreadOwner': 0,
        },
        SetOptions(merge: true));
    return batch.commit();
  }
}

/// Message d'erreur de connexion compréhensible.
String cloudAuthError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'email-already-in-use':
        return 'Ce compte existe déjà : choisissez « Se connecter ».';
      case 'weak-password':
        return 'Mot de passe trop court (6 caractères minimum).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      case 'network-request-failed':
        return 'Pas de connexion Internet.';
      case 'operation-not-allowed':
        return 'Activez « E-mail/Mot de passe » dans Firebase > Authentication.';
    }
    return e.message ?? e.code;
  }
  return '$e';
}
