import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart' as fcm;
import 'package:w0001/data/datasources/local/notification_settings_storage.dart';
import 'package:w0001/data/datasources/remote/notification_settings_api.dart';
import 'package:w0001/data/model/notification_settings_model.dart';
import 'package:w0001/domain/repository/notification_settings_repository.dart';

/// 알림 설정 Repository 구현
class NotificationSettingsRepositoryImpl implements NotificationSettingsRepository {
  final NotificationSettingsApi _api;
  final NotificationSettingsStorage _storage;
  final fcm.FirebaseMessaging _fcm;

  NotificationSettingsRepositoryImpl(
    this._api,
    this._storage,
    this._fcm,
  );

  @override
  Future<NotificationSettings> getSettings() async {
    // 1. 로컬 캐시 먼저 확인
    final local = await _storage.load();
    
    // 2. 서버에서 최신 데이터 가져오기 (백그라운드)
    unawaited(_syncInBackground());
    
    return local;
  }

  @override
  Future<NotificationSettings> updateSettings(NotificationSettings settings) async {
    // 1. 로컬 먼저 저장 (즉시 UI 반영)
    await _storage.save(settings);
    
    try {
      // 2. 서버에 업데이트
      final updated = await _api.updateSettings(settings);
      
      // 3. FCM Topics 구독 상태 업데이트
      await _updateFcmTopics(updated);
      
      // 4. 동기화 완료 표시
      final synced = updated.markSynced();
      await _storage.save(synced);
      
      return synced;
    } catch (e) {
      // 서버 실패해도 로컬은 저장됨 (다음 동기화 시 재시도)
      rethrow;
    }
  }

  @override
  Future<NotificationSettings> toggleSetting(NotificationType type) async {
    // 1. 현재 설정 로드
    final current = await _storage.load();
    
    // 2. 토글
    final toggled = current.toggle(type);
    
    // 3. 로컬 먼저 저장
    await _storage.save(toggled);
    
    try {
      // 4. 서버에 부분 업데이트
      await _api.updateSetting(type, toggled.isEnabled(type));
      
      // 5. FCM Topics 구독 상태 업데이트 (전체 공지만 해당)
      await _updateFcmTopics(toggled);
      
      // 6. 동기화 완료 표시
      final synced = toggled.markSynced();
      await _storage.save(synced);
      
      return synced;
    } catch (e) {
      // 서버 실패해도 로컬은 저장됨
      rethrow;
    }
  }

  @override
  Future<NotificationSettings> syncWithServer() async {
    try {
      // 서버에서 최신 설정 가져오기
      final serverSettings = await _api.getSettings();
      
      // 로컬에 저장
      await _storage.save(serverSettings);
      
      // FCM Topics 구독 상태 동기화
      await _updateFcmTopics(serverSettings);
      
      return serverSettings;
    } catch (e) {
      // 동기화 실패 시 로컬 캐시 반환
      return await _storage.load();
    }
  }

  @override
  Future<void> clearLocal() async {
    await _storage.clear();
  }

  /// 백그라운드 동기화 (에러 무시)
  Future<void> _syncInBackground() async {
    try {
      await syncWithServer();
    } catch (e) {
      // 백그라운드 동기화 실패는 무시
    }
  }

  /// FCM Topics 구독 상태 업데이트
  Future<void> _updateFcmTopics(NotificationSettings settings) async {
    for (final type in NotificationType.values) {
      final topicName = type.topicName;
      if (topicName == null) continue; // 개인 알림은 Topic 사용 안 함
      
      try {
        if (settings.isEnabled(type)) {
          await _fcm.subscribeToTopic(topicName);
        } else {
          await _fcm.unsubscribeFromTopic(topicName);
        }
      } catch (e) {
        // Topic 구독/해제 실패는 무시 (다음 동기화 시 재시도)
      }
    }
  }
}
