import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w0001/data/model/notification_settings_model.dart';

/// 알림 설정 로컬 저장소
class NotificationSettingsStorage {
  static const _key = 'notification_settings_v1';

  /// 설정 저장
  Future<void> save(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(settings.toJson());
    await prefs.setString(_key, json);
  }

  /// 설정 로드
  Future<NotificationSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      
      if (json == null) {
        // 저장된 데이터 없음 - 기본값 반환
        return NotificationSettings.initial();
      }

      final data = jsonDecode(json) as Map<String, dynamic>;
      return NotificationSettings.fromJson(data);
    } catch (e) {
      // 파싱 오류 시 기본값 반환
      return NotificationSettings.initial();
    }
  }

  /// 설정 삭제 (로그아웃 시 사용)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
