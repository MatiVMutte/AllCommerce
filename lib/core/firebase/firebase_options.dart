import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Minimal Firebase options read from environment variables.
/// If the required keys are missing Firebase is not initialized and push
/// notifications fall back to in-app realtime alerts.
class DefaultFirebaseOptions {
  static bool get hasConfig {
    return dotenv.env['FIREBASE_API_KEY']?.trim().isNotEmpty == true &&
        dotenv.env['FIREBASE_APP_ID']?.trim().isNotEmpty == true &&
        dotenv.env['FIREBASE_PROJECT_ID']?.trim().isNotEmpty == true;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Push notifications are not supported here.');
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _env('FIREBASE_API_KEY'),
        appId: _env('FIREBASE_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'],
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'],
        measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID'],
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _env('FIREBASE_API_KEY'),
        appId: _env('FIREBASE_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'],
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _env('FIREBASE_API_KEY'),
        appId: _env('FIREBASE_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'],
        iosBundleId: dotenv.env['FIREBASE_IOS_BUNDLE_ID'],
      );

  static String _env(String key) {
    final String? value = dotenv.env[key];
    if (value == null || value.trim().isEmpty) {
      throw StateError('Missing Firebase config: $key');
    }
    return value;
  }
}
