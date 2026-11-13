import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC62BTggWK-M7-FImn3v4YRVHSdWSgRTZE',
    appId: '1:138730719673:android:504706dcad2251e0164e68',
    messagingSenderId: '138730719673',
    projectId: 'naxchat-27309',
    storageBucket: 'naxchat-27309.firebasestorage.app',
  );
}
