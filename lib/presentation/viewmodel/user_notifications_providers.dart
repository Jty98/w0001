import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/user_notifications_remote_api.dart';
import 'package:w0001/data/model/user_notification_models.dart';
import 'package:w0001/data/repository/user_notifications_repository_impl.dart';
import 'package:w0001/domain/repository/user_notifications_repository.dart';
import 'package:w0001/domain/use_case/user_notifications_use_case.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';

final userNotificationsRemoteApiProvider = Provider<UserNotificationsRemoteApi>(
  (ref) => UserNotificationsRemoteApi(AppHttpClient.I),
);

final userNotificationsRepositoryProvider =
    Provider<UserNotificationsRepository>(
  (ref) => UserNotificationsRepositoryImpl(
    api: ref.watch(userNotificationsRemoteApiProvider),
    currentUser: () => ref.read(authSessionProvider).asData?.value,
  ),
);

final userNotificationsUseCaseProvider = Provider<UserNotificationsUseCase>(
  (ref) => UserNotificationsUseCase(
    ref.watch(userNotificationsRepositoryProvider),
  ),
);

final userNotificationInboxProvider =
    AsyncNotifierProvider<UserNotificationInboxNotifier, List<UserNotificationItem>>(
  UserNotificationInboxNotifier.new,
);

final userNotificationUnreadCountProvider = Provider<int>((ref) {
  final async = ref.watch(userNotificationInboxProvider);
  return async.maybeWhen(
    data: (items) => items.where((e) => !e.isRead).length,
    orElse: () => 0,
  );
});

final class UserNotificationInboxNotifier
    extends AsyncNotifier<List<UserNotificationItem>> {
  @override
  Future<List<UserNotificationItem>> build() async {
    ref.listen<AsyncValue<dynamic>>(authSessionProvider, (prev, next) {
      final prevUid = prev?.asData?.value?.uid;
      final nextUid = next.asData?.value?.uid;
      if (prevUid != nextUid) {
        ref.invalidateSelf();
      }
    });
    final u = ref.read(authSessionProvider).asData?.value;
    if (u == null) return const [];
    return ref.read(userNotificationsUseCaseProvider).list();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(userNotificationsUseCaseProvider).list(),
    );
  }

  Future<void> markRead(UserNotificationItem item) async {
    await ref.read(userNotificationsUseCaseProvider).markRead(item);
    await reload();
  }

  Future<void> deleteOne(UserNotificationItem item) async {
    await ref.read(userNotificationsUseCaseProvider).deleteOne(item);
    await reload();
  }

  Future<void> deleteAll() async {
    await ref.read(userNotificationsUseCaseProvider).deleteAll();
    await reload();
  }
}

/// FCM·알림함 갱신 (전역 [ProviderContainer]에서 호출).
void refreshUserNotificationInbox(ProviderContainer container) {
  container.invalidate(userNotificationInboxProvider);
}
