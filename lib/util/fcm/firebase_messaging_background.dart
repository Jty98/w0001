import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:w0001/firebase_options.dart';

/// 백그라운드·종료 상태 수신 전용 isolate 진입점.
///
/// [main]에서 [Firebase.initializeApp] 직후,
/// [FirebaseMessaging.onBackgroundMessage]에 등록해야 한다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
