import 'package:shared_preferences/shared_preferences.dart';

/// 동일 uid·FCM 토큰이면 `PUT /users/me/fcm-device` 생략.
abstract final class FcmTokenRegistrationCache {
  static String _key(String uid) => 'fcm_device_registered_v1_$uid';

  static Future<bool> isAlreadyRegistered(String uid, String token) async {
    final t = token.trim();
    if (uid.isEmpty || t.isEmpty) return false;
    final p = await SharedPreferences.getInstance();
    return p.getString(_key(uid)) == t;
  }

  static Future<void> markRegistered(String uid, String token) async {
    final t = token.trim();
    if (uid.isEmpty || t.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(uid), t);
  }

  static Future<void> clearForUser(String uid) async {
    if (uid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(uid));
  }
}
