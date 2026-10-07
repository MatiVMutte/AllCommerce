import 'dart:async';

import 'package:all_commerce/core/firebase/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Required by firebase_messaging. Android already displays messages that
/// carry a `notification` payload while the app is in background, so there
/// is nothing else to do here.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

const AndroidNotificationChannel _ordersChannel = AndroidNotificationChannel(
  'order_notifications',
  'Pedidos',
  description: 'Avisos cuando entra un pedido nuevo',
  importance: Importance.max,
);

/// Push notifications for store owners (Android/iOS only). Disabled when the
/// .env has no Firebase config, so the app keeps working without it.
class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _token;

  bool get isAvailable => !kIsWeb && DefaultFirebaseOptions.hasConfig;

  /// Call after `Supabase.initialize()`.
  Future<void> initialize() async {
    if (_initialized || !isAvailable) return;
    _initialized = true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final NotificationSettings settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await _initLocalNotifications();
      FirebaseMessaging.onMessage.listen(_showForeground);

      _token = await messaging.getToken();
      messaging.onTokenRefresh.listen((String token) {
        _token = token;
        unawaited(_saveToken());
      });

      // Save now if already logged in, and again on every sign-in.
      await _saveToken();
      Supabase.instance.client.auth.onAuthStateChange.listen((AuthState s) {
        if (s.event == AuthChangeEvent.signedIn) unawaited(_saveToken());
      });
    } catch (e) {
      debugPrint('Push notifications disabled: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_ordersChannel);
  }

  Future<void> _saveToken() async {
    final String? token = _token;
    final SupabaseClient client = Supabase.instance.client;
    final String? userId = client.auth.currentUser?.id;
    if (token == null || token.isEmpty || userId == null) return;
    try {
      await client.rpc<void>('register_device', params: <String, dynamic>{
        'p_token': token,
        'p_platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null) return;
    await _local.show(
      id: message.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _ordersChannel.id,
          _ordersChannel.name,
          channelDescription: _ordersChannel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['order_id']?.toString(),
    );
  }
}
