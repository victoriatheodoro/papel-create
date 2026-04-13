import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError('Plataforma não suportada.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBEiKqfncjntWlIuF4Ovy58zUUoisK880o',
    authDomain: 'papel-e-create.firebaseapp.com',
    projectId: 'papel-e-create',
    storageBucket: 'papel-e-create.firebasestorage.app',
    messagingSenderId: '135145417758',
    appId: '1:135145417758:web:f478fb162ccfb187e7520f',
    measurementId: 'G-Z990K24Q8M',
  );
}
