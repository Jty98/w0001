import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/remote/super_admin_json.dart';
import 'package:w0001/data/model/user_notification_models.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 사용자 알림함 REST API (서버 준비 시 즉시 연동).
final class UserNotificationsRemoteApi {
  UserNotificationsRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<UserNotificationItem>> list({int limit = 100}) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.usersMeNotifications,
      queryParameters: <String, dynamic>{'limit': limit},
    );
    return parseUserNotificationList(r.data);
  }

  Future<int> unreadCount() async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.usersMeNotificationsUnreadCount,
    );
    final data = r.data;
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final c = saInt(m['unread_count'] ?? m['unreadCount'] ?? m['count']);
      if (c != null) return c;
    }
    if (data is int) return data;
    if (data is num) return data.toInt();
    return 0;
  }

  Future<void> markRead(String id) async {
    await _http.patch<dynamic>(ApiEndpoint.usersMeNotificationRead(id));
  }

  Future<void> deleteOne(String id) async {
    await _http.delete<dynamic>(ApiEndpoint.usersMeNotificationId(id));
  }

  Future<void> deleteAll() async {
    await _http.delete<dynamic>(ApiEndpoint.usersMeNotifications);
  }
}
