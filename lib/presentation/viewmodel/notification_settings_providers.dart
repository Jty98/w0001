import 'package:firebase_messaging/firebase_messaging.dart' as fcm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/local/notification_settings_storage.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/notification_settings_api.dart';
import 'package:w0001/data/model/notification_settings_model.dart';
import 'package:w0001/data/repository/notification_settings_repository_impl.dart';
import 'package:w0001/domain/repository/notification_settings_repository.dart';

/// 알림 설정 Repository Provider
final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
  final api = NotificationSettingsApi(AppHttpClient.I);
  final storage = NotificationSettingsStorage();
  final fcmInstance = fcm.FirebaseMessaging.instance;

  return NotificationSettingsRepositoryImpl(api, storage, fcmInstance);
});

/// 알림 설정 Notifier
class NotificationSettingsNotifier extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() async {
    final repo = ref.watch(notificationSettingsRepositoryProvider);
    return await repo.getSettings();
  }

  /// 특정 알림 타입 토글
  Future<void> toggle(NotificationType type) async {
    if (!type.isUserConfigurable) return;
    // 낙관적 업데이트 (즉시 UI 반영)
    state = AsyncValue.data(
      state.value?.toggle(type) ?? NotificationSettings.initial().toggle(type),
    );

    try {
      final repo = ref.read(notificationSettingsRepositoryProvider);
      final updated = await repo.toggleSetting(type);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      // 에러 발생 시 이전 상태로 복구
      state = AsyncError(e, st);

      // 로컬 캐시 다시 로드
      await refresh();
    }
  }

  /// 서버와 동기화
  Future<void> sync() async {
    try {
      final repo = ref.read(notificationSettingsRepositoryProvider);
      final synced = await repo.syncWithServer();
      state = AsyncValue.data(synced);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// 새로고침
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(notificationSettingsRepositoryProvider);
      return await repo.getSettings();
    });
  }

  /// 로그아웃 시 로컬 설정 삭제
  Future<void> clearLocal() async {
    final repo = ref.read(notificationSettingsRepositoryProvider);
    await repo.clearLocal();
    state = AsyncValue.data(NotificationSettings.initial());
  }
}

/// 알림 설정 Provider
final notificationSettingsNotifierProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
        NotificationSettingsNotifier.new);
