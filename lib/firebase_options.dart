import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAN9RakVkOYgHwFnu3puocmPkwxjrsoh4I',
    appId: '1:609040380574:web:mezanya-web',
    messagingSenderId: '609040380574',
    projectId: 'mezanya-app',
    authDomain: 'mezanya-app.firebaseapp.com',
    storageBucket: 'mezanya-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAN9RakVkOYgHwFnu3puocmPkwxjrsoh4I',
    appId: '1:609040380574:android:5f010e2ff0598c7a99418f',
    messagingSenderId: '609040380574',
    projectId: 'mezanya-app',
    storageBucket: 'mezanya-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAN9RakVkOYgHwFnu3puocmPkwxjrsoh4I',
    appId: '1:609040380574:ios:mezanya-ios',
    messagingSenderId: '609040380574',
    projectId: 'mezanya-app',
    storageBucket: 'mezanya-app.firebasestorage.app',
    iosClientId:
        '609040380574-gttc94otebsgd89lfvjdepidfaumeggr.apps.googleusercontent.com',
    iosBundleId: 'com.mezanya.app',
  );
}
