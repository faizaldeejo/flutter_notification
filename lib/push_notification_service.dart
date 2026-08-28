import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  initFCM() async{
    await _firebaseMessaging.requestPermission();
    final  fcmToken = await _firebaseMessaging.getToken();
    print('FCM Token: $fcmToken');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Message title: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
    });


  }
}