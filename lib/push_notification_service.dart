import 'dart:convert';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;

class PushNotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  late String _deviceToken;

  initFCM() async {
    final request = await _firebaseMessaging.requestPermission();
    if (request.authorizationStatus == AuthorizationStatus.denied) {
      print('Notification permission denied');
      return;
    }
    final fcmToken = await _firebaseMessaging.getToken();
    _deviceToken = fcmToken!;
    print('FCM Token: $fcmToken');

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received a foreground message: ${message.messageId}');
      //showLocalNotification(message);
      RemoteNotification? notification = message.notification;
      AndroidNotification? androidNotification = message.notification?.android;

      if (notification != null && androidNotification != null) {
        const AndroidNotificationDetails
        androidDetails = AndroidNotificationDetails(
          'high_importance_channel', // id
          'High Importance Notifications', // title
          channelDescription:
              'This channel is used for important notifications.', // description
          importance: Importance.high,
          priority: Priority.high,
        );

        const NotificationDetails platformDetails = NotificationDetails(
          android: androidDetails,
        );

        _notifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: platformDetails,
          payload: 'notification_details', // You can pass any payload here
        );
      }
    });

    // Listen for messages when the app is opened from a terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
    });

    await _notifications.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await createLocalNotificationChannel();
  }

  Future<void> createLocalNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // Future<void> showLocalNotification(RemoteMessage message) async {
  //   RemoteNotification? notification = message.notification;
  //   AndroidNotification? androidNotification = message.notification?.android;

  //   if (notification != null && androidNotification != null) {
  //     const AndroidNotificationDetails androidDetails =
  //         AndroidNotificationDetails(
  //       'high_importance_channel', // id
  //       'High Importance Notifications', // title
  //       channelDescription:
  //           'This channel is used for important notifications.', // description
  //       importance: Importance.high,
  //       priority: Priority.high,
  //     );

  //     const NotificationDetails platformDetails =
  //         NotificationDetails(android: androidDetails);

  //     await _notifications.show(
  //       id: notification.hashCode,
  //       title: notification.title,
  //       body: notification.body,
  //       notificationDetails: platformDetails,
  //       payload: 'notification_details', // You can pass any payload here
  //     );
  //   }
  // }

  void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');

    if (response.payload == 'notification_details') {
      // Navigate to the notification details screen
      // You can use a navigator key or any other method to navigate
      // For example:
      // navigatorKey.currentState?.pushNamed('/notificationDetails');
      //Get.to(const NotificationDetailPage());
    }
  }

  Future<AccessCredentials> _getAccessToken() async {
    final serviceAccountPath = dotenv.env['PATH_TO_SECRETS'];

    String serviceAccountJson = await rootBundle.loadString(
      serviceAccountPath!,
    );

    // log("json: $serviceAccountJson");
    final serviceAccount = ServiceAccountCredentials.fromJson(
      serviceAccountJson,
    );

    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

    final client = await clientViaServiceAccount(serviceAccount, scopes);
    return client.credentials;
  }

  Future<bool> sendPushNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_deviceToken.isEmpty) return false;

    final credentials = await _getAccessToken();
    final accessToken = credentials.accessToken.data;
    final projectId = dotenv.env['PROJECT_ID'];

    log("accessToken: $dotenv.env['PROJECT_ID']");

    final url = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
    );

    final message = {
      'message': {
        'token': _deviceToken,
        'notification': {'title': title, 'body': body},
        'data': data ?? {},
      },
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully.');
      return true;
    } else {
      print('Failed to send notification: ${response.body}');
      return false;
    }
  }
}
