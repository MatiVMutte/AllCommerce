import 'package:all_commerce/core/firebase/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level background message handler required by firebase_messaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _showLocalNotification(message.notification, message.data);
}

const String _channelId = 'order_notifications';
const String _channelName = 'Pedidos';
const String _channelDescription = 'Avisos cuando entra un pedido nuevo';

/// Initializes Firebase and local notifications. Safe to call when the .env
/// does not contain Firebase config: in that case push notifications are
/// simply disabled and the app relies on in-app realtime alerts.
class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._();

  static FirebaseMessagingService get instance => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Returns true when Firebase could be initialized from .env values.
  bool get isAvailable => DefaultFirebaseOptions.hasConfig;

  /// One-time setup. Should be called after `Supabase.initialize()` so the
  /// current user can be read when saving the device token.
  Future<void> initialize() async {
    if (_initialized || !isAvailable) return;
    _initialized = true;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission (iOS and Android 13+). On older Android it is granted.
    final NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Foreground messages.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background / terminated messages.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Local notifications for foreground display.
    await _initLocalNotifications();

    // Save token and keep it updated.
    await _updateToken(await messaging.getToken());
    messaging.onTokenRefresh.listen(_updateToken);
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );
  }

  Future<void> _updateToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final SupabaseClient client = Supabase.instance.client;
    final String? userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await client.from('user_devices').upsert(<String, dynamic>{
        'user_id': userId,
        'fcm_token': token,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _showLocalNotification(message.notification, message.data);
  }
}

Future<void> _showLocalNotification(
  RemoteNotification? notification,
  Map<String, dynamic> data,
) async {
  final String title = notification?.title ?? data['title']?.toString() ?? 'AllCommerce';
  final String body = notification?.body ?? data['body']?.toString() ?? '';

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );
  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  await FlutterLocalNotificationsPlugin().show(
    id: 0,
    title: title,
    body: body,
    notificationDetails: details,
    payload: data['order_id']?.toString(),
  );
}
