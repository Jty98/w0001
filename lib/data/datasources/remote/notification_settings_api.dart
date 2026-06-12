import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/notification_settings_model.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 알림 설정 API
class NotificationSettingsApi {
  final AppHttpClient _http;

  NotificationSettingsApi(this._http);

  /// 알림 설정 조회
  Future<NotificationSettings> getSettings() async {
    final res = await _http.get<dynamic>(
      ApiEndpoint.usersMeNotificationSettings,
    );
    
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('알림 설정 응답 형식이 올바르지 않습니다.');
    }

    return NotificationSettings.fromApiJson(data);
  }

  /// 알림 설정 업데이트 (전체)
  Future<NotificationSettings> updateSettings(
    NotificationSettings settings,
  ) async {
    final res = await _http.put<dynamic>(
      ApiEndpoint.usersMeNotificationSettings,
      data: settings.toApiJson(),
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('알림 설정 응답 형식이 올바르지 않습니다.');
    }

    return NotificationSettings.fromApiJson(data);
  }

  /// 특정 알림 타입만 업데이트 (부분 업데이트)
  Future<void> updateSetting(NotificationType type, bool enabled) async {
    await _http.patch<dynamic>(
      ApiEndpoint.usersMeNotificationSettings,
      data: {
        type.key: enabled,
      },
    );
  }
}
