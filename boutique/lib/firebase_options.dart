import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Projet Firebase « mcs-vision » (partagé avec MCS Facture).
/// Ces valeurs ne sont pas secrètes : la sécurité vient des règles
/// Firestore (fichier firestore.rules à la racine du dépôt).
class DefaultFirebaseOptions {
  static const _apiKey = 'AIzaSyBDICPs-6pJj5r9wWXiD8YKNlcqWwziBo4';
  static const _project = 'mcs-vision';
  static const _sender = '937926536001';
  static const _webAppId = '1:937926536001:web:9431252345a141dcb84fc0';

  /// Application Android com.mcsvision.mcs_boutique (à remplacer par son
  /// identifiant dès qu'elle est déclarée dans Firebase).
  static const _androidAppId = _webAppId;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return android;
  }

  static const web = FirebaseOptions(
    apiKey: _apiKey,
    appId: _webAppId,
    messagingSenderId: _sender,
    projectId: _project,
    authDomain: 'mcs-vision.firebaseapp.com',
    storageBucket: 'mcs-vision.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: _apiKey,
    appId: _androidAppId,
    messagingSenderId: _sender,
    projectId: _project,
    storageBucket: 'mcs-vision.firebasestorage.app',
  );
}
