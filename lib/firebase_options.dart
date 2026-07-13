// ─────────────────────────────────────────────────────────────────────────────
// firebase_options.dart — إعدادات Firebase
//
// ⚠️  استبدل قيم PLACEHOLDER بالقيم الحقيقية من Firebase Console:
//     console.firebase.google.com → مشروعك → ⚙️ إعدادات → تطبيقاتك (Web)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // ── إعدادات Firebase الحقيقية لمشروع terabi-app ──
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyAW8Iee-YDMxnflBns98amIKHzHY9CY1pg',
    authDomain:        'terabi-app.firebaseapp.com',
    projectId:         'terabi-app',
    storageBucket:     'terabi-app.firebasestorage.app',
    messagingSenderId: '158320246342',
    appId:             '1:158320246342:web:7eb87cead5725080b69447',
    measurementId:     'G-VPM41CDTD7',
  );

  // نفس القيم للـ Android (اختياري لاحقاً)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyAW8Iee-YDMxnflBns98amIKHzHY9CY1pg',
    appId:             'REPLACE_WITH_YOUR_android_appId',
    messagingSenderId: '158320246342',
    projectId:         'terabi-app',
    storageBucket:     'terabi-app.firebasestorage.app',
  );

  // نفس القيم للـ iOS (اختياري لاحقاً)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyAW8Iee-YDMxnflBns98amIKHzHY9CY1pg',
    appId:             'REPLACE_WITH_YOUR_ios_appId',
    messagingSenderId: '158320246342',
    projectId:         'terabi-app',
    storageBucket:     'terabi-app.firebasestorage.app',
    iosBundleId:       'com.terabi.app',
  );
}
