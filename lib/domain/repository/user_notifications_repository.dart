import 'package:w0001/data/model/user_notification_models.dart';

abstract interface class UserNotificationsRepository {
  Future<List<UserNotificationItem>> list();

  Future<int> unreadCount();

  Future<void> markRead(String id, {required bool isLocalOnly});

  Future<void> deleteOne(String id, {required bool isLocalOnly});

  Future<void> deleteAll();

  /// FCM 수신 시 로컬·(서버 있으면) 동기화용.
  Future<void> recordFromFcm({
    required String type,
    required Map<String, dynamic> payload,
    String? title,
    String? body,
  });
}
