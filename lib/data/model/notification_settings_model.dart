import 'package:flutter/foundation.dart';

/// 알림 타입
enum NotificationType {
  /// 작업 배정 (현장 작업일 배정)
  workAssignment('work_assignment', '작업 배정', 'placeworkday_assignment'),

  /// 전체 공지사항
  announcementGlobal(
      'announcement_global', '전체 공지사항', 'worker_announcement_global'),

  /// 현장 공지사항
  announcementPlace(
      'announcement_place', '현장 공지사항', 'worker_announcement_place'),

  /// 사진 업로드 요청
  photoUpload('photo_upload', '사진 업로드', 'worker_place_photo'),

  /// 작업 지시사항
  workInstruction('work_instruction', '작업 지시사항', 'placeworkday_instruction'),

  /// 계정 업데이트 (승인, 정지 등) — 사용자 설정 불가, 항상 수신.
  accountUpdate('account_update', '계정 알림', 'account_');

  const NotificationType(this.key, this.displayName, this.fcmPrefix);

  /// API/로컬 저장용 키
  final String key;

  /// 사용자에게 보여질 이름
  final String displayName;

  /// FCM 메시지 타입 prefix
  final String fcmPrefix;

  /// 알림 설정 화면에서 토글 가능한 타입 (계정 알림 제외).
  static const List<NotificationType> userConfigurableTypes = [
    workAssignment,
    announcementGlobal,
    announcementPlace,
    photoUpload,
    workInstruction,
  ];

  bool get isUserConfigurable => this != NotificationType.accountUpdate;

  /// FCM Topic 이름 (전체 알림에만 사용)
  String? get topicName {
    switch (this) {
      case NotificationType.announcementGlobal:
        return 'announcements_global';
      case NotificationType.announcementPlace:
        return 'announcements_place';
      default:
        return null; // 개인 알림은 Topic 사용 안 함
    }
  }

  /// FCM 메시지 타입으로부터 NotificationType 찾기
  static NotificationType? fromFcmType(String? fcmType) {
    if (fcmType == null) return null;

    for (final type in NotificationType.values) {
      if (fcmType.startsWith(type.fcmPrefix)) {
        return type;
      }
    }
    return null;
  }
}

/// 알림 설정
@immutable
class NotificationSettings {
  final Map<NotificationType, bool> settings;
  final DateTime? lastSyncedAt;

  const NotificationSettings({
    this.settings = const {},
    this.lastSyncedAt,
  });

  /// 기본값으로 초기화 (모두 켜짐)
  factory NotificationSettings.initial() {
    return NotificationSettings(
      settings: {
        for (var type in NotificationType.values) type: true,
      },
    );
  }

  /// 특정 알림 타입이 활성화되어 있는지
  bool isEnabled(NotificationType type) {
    if (type == NotificationType.accountUpdate) return true;
    return settings[type] ?? true; // 기본값은 true (켜짐)
  }

  /// 특정 알림 타입 토글
  NotificationSettings toggle(NotificationType type) {
    if (!type.isUserConfigurable) return this;
    final newSettings = Map<NotificationType, bool>.from(settings);
    newSettings[type] = !isEnabled(type);
    return NotificationSettings(
      settings: newSettings,
      lastSyncedAt: lastSyncedAt,
    );
  }

  /// 특정 알림 타입 설정
  NotificationSettings set(NotificationType type, bool enabled) {
    if (type == NotificationType.accountUpdate) {
      return copyWithAccountAlwaysEnabled();
    }
    final newSettings = Map<NotificationType, bool>.from(settings);
    newSettings[type] = enabled;
    return NotificationSettings(
      settings: newSettings,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// 서버 동기화 완료 표시
  NotificationSettings markSynced() {
    return NotificationSettings(
      settings: settings,
      lastSyncedAt: DateTime.now(),
    );
  }

  /// JSON 직렬화 (로컬 저장용)
  Map<String, dynamic> toJson() {
    return {
      'settings': {
        for (var entry in settings.entries) entry.key.key: entry.value,
      },
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
  }

  /// JSON 역직렬화 (로컬 로드용)
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final settingsMap = <NotificationType, bool>{};
    final settingsData = json['settings'] as Map<String, dynamic>?;

    if (settingsData != null) {
      for (var type in NotificationType.values) {
        settingsMap[type] = settingsData[type.key] as bool? ?? true;
      }
    } else {
      // 데이터가 없으면 기본값 사용
      for (var type in NotificationType.values) {
        settingsMap[type] = true;
      }
    }
    settingsMap[NotificationType.accountUpdate] = true;

    final lastSyncedStr = json['last_synced_at'] as String?;
    final lastSynced =
        lastSyncedStr != null ? DateTime.tryParse(lastSyncedStr) : null;

    return NotificationSettings(
      settings: settingsMap,
      lastSyncedAt: lastSynced,
    );
  }

  /// 서버 API용 JSON (snake_case) — 계정 알림은 항상 true.
  Map<String, dynamic> toApiJson() {
    return {
      for (final type in NotificationType.values)
        type.key:
            type == NotificationType.accountUpdate ? true : isEnabled(type),
    };
  }

  NotificationSettings copyWithAccountAlwaysEnabled() {
    final next = Map<NotificationType, bool>.from(settings);
    next[NotificationType.accountUpdate] = true;
    return NotificationSettings(
      settings: next,
      lastSyncedAt: lastSyncedAt,
    );
  }

  /// 서버 응답 파싱
  factory NotificationSettings.fromApiJson(Map<String, dynamic> json) {
    final settingsMap = <NotificationType, bool>{};

    for (var type in NotificationType.values) {
      settingsMap[type] = json[type.key] as bool? ?? true;
    }
    settingsMap[NotificationType.accountUpdate] = true;

    return NotificationSettings(
      settings: settingsMap,
      lastSyncedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        mapEquals(other.settings, settings) &&
        other.lastSyncedAt == lastSyncedAt;
  }

  @override
  int get hashCode => Object.hash(settings, lastSyncedAt);
}
