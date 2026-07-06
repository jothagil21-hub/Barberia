import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../notifications/notification_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _firebaseReady = false;
  bool _listenersBound = false;
  ApiClient? _api;

  void Function(String route)? onNavigate;
  void Function()? onPendingRequest;

  Future<void> initialize() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (error) {
      debugPrint('Firebase no disponible: $error');
      return;
    }

    await _requestPermission();
    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
  }

  Future<void> _requestPermission() async {
    if (!_firebaseReady) return;
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void bindListeners() {
    if (!_firebaseReady || _listenersBound) return;
    _listenersBound = true;

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessage(message);
      }
    });
  }

  Future<void> registerWithApi(ApiClient api) async {
    if (!_firebaseReady) return;
    _api = api;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _registerToken(token);
    }
  }

  Future<void> _registerToken(String token) async {
    final api = _api;
    if (api == null || !_firebaseReady) return;

    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await api.post('/api/app/device-token', {
        'fcmToken': token,
        'platform': platform,
      });
    } catch (error) {
      debugPrint('No se pudo registrar token FCM: $error');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    onPendingRequest?.call();
    final notification = message.notification;
    if (notification == null) return;

    NotificationService.instance.showPushAlert(
      title: notification.title ?? 'Nueva solicitud',
      body: notification.body ?? '',
    );
  }

  void _handleMessage(RemoteMessage message) {
    onPendingRequest?.call();
    final type = message.data['type'];
    if (type == 'pending_request') {
      onNavigate?.call('/pending');
    }
  }
}
