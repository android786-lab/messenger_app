import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/app_constants.dart';

/// Top-level background handler (required by FCM).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('FCM background: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'New message notifications',
    importance: Importance.high,
  );

  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    if (_initialized) return;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final androidPlugin =
        _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);

    _initialized = true;
  }

  Future<void> syncTokenForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken == null) return;

      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set(
        {
          'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _messaging.onTokenRefresh.listen((token) async {
        _fcmToken = token;
        await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .set(
          {
            'fcmTokens': FieldValue.arrayUnion([token]),
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      developer.log('FCM token sync error: $e');
    }
  }

  Future<void> removeTokenForUser(String uid) async {
    if (_fcmToken == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'fcmTokens': FieldValue.arrayRemove([_fcmToken]),
      });
    } catch (e) {
      developer.log('FCM token remove error: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['chatId'] as String?,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  void _handleMessageOpen(RemoteMessage message) {
    final chatId = message.data['chatId'] as String?;
    _handlePayload(chatId);
  }

  void Function(String? chatId)? onNavigateToChat;

  void _handlePayload(String? chatId) {
    if (chatId != null && chatId.isNotEmpty) {
      onNavigateToChat?.call(chatId);
    }
  }
}
