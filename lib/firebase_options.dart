import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Projet Firebase « mcs-vision » (partagé avec MCS Boutique).
class DefaultFirebaseOptions {
  static const _apiKey = 'AIzaSyBDICPs-6pJj5r9wWXiD8YKNlcqWwziBo4';
  static const _project = 'mcs-vision';
  static const _sender = '937926536001';

  /// null : Firebase n'est pas configuré pour cette plateforme (iPhone
  /// natif) ; la boutique en ligne y est simplement désactivée.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    return null;
  }

  static const web = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:937926536001:web:9431252345a141dcb84fc0',
    messagingSenderId: _sender,
    projectId: _project,
    authDomain: 'mcs-vision.firebaseapp.com',
    storageBucket: 'mcs-vision.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:937926536001:android:b44732db8a8a9199b84fc0',
    messagingSenderId: _sender,
    projectId: _project,
    storageBucket: 'mcs-vision.firebasestorage.app',
  );
}
