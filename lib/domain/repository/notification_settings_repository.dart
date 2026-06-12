import 'package:w0001/data/model/notification_settings_model.dart';

/// 알림 설정 Repository 인터페이스
abstract class NotificationSettingsRepository {
  /// 알림 설정 조회 (로컬 캐시 우선, 없으면 서버)
  Future<NotificationSettings> getSettings();

  /// 알림 설정 업데이트 (로컬 + 서버)
  Future<NotificationSettings> updateSettings(NotificationSettings settings);

  /// 특정 알림 타입 토글 (로컬 + 서버)
  Future<NotificationSettings> toggleSetting(NotificationType type);

  /// 서버와 동기화 (서버 → 로컬)
  Future<NotificationSettings> syncWithServer();

  /// 로컬 설정 삭제 (로그아웃 시)
  Future<void> clearLocal();
}
