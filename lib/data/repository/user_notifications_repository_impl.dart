import 'dart:async';

import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/user_notifications_remote_api.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/user_notification_models.dart';
import 'package:w0001/domain/repository/user_notifications_repository.dart';
import 'package:w0001/util/notifications/local_notification_inbox_store.dart';
import 'package:w0001/util/notifications/notification_inbox_role_filter.dart';

final class UserNotificationsRepositoryImpl implements UserNotificationsRepository {
  UserNotificationsRepositoryImpl({
    required UserNotificationsRemoteApi api,
    required UserRead? Function() currentUser,
  })  : _api = api,
        _currentUser = currentUser;

  final UserNotificationsRemoteApi _api;
  final UserRead? Function() _currentUser;

  String? get _uid => _currentUser()?.uid;

  static bool _isNotificationsApiUnavailable(HttpStatusException e) {
    final c = e.statusCode;
    return c == 404 || c == 501 || c == 405;
  }

  Future<List<UserNotificationItem>> _loadLocalFiltered(String uid) async {
    final user = _currentUser();
    final local = await LocalNotificationInboxStore.list(uid);
    return NotificationInboxRoleFilter.filterForUser(user, local);
  }

  @override
  Future<List<UserNotificationItem>> list() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const [];
    final user = _currentUser();
    try {
      final remote = await _api
          .list()
          .timeout(const Duration(seconds: 10));
      final filtered =
          NotificationInboxRoleFilter.filterForUser(user, remote);
      if (filtered.isNotEmpty) return filtered;
      // 서버 API는 있으나 목록만 비어 있음 → 기기에 쌓인 FCM 로컬 항목 병합
      final local = await _loadLocalFiltered(uid);
      if (local.isNotEmpty) return local;
      return filtered;
    } on HttpStatusException catch (e) {
      if (!_isNotificationsApiUnavailable(e)) rethrow;
    } on Exception {
      // 타임아웃·연결 오류 등 — 로컬 폴백
    }
    return _loadLocalFiltered(uid);
  }

  @override
  Future<int> unreadCount() async {
    final items = await list();
    return items.where((e) => !e.isRead).length;
  }

  @override
  Future<void> markRead(String id, {required bool isLocalOnly}) async {
    final uid = _uid;
    if (uid == null) return;
    if (isLocalOnly) {
      await LocalNotificationInboxStore.markReadLocal(uid, id);
      return;
    }
    try {
      await _api.markRead(id);
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 501) {
        await LocalNotificationInboxStore.markReadLocal(uid, id);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteOne(String id, {required bool isLocalOnly}) async {
    final uid = _uid;
    if (uid == null) return;
    if (isLocalOnly) {
      await LocalNotificationInboxStore.deleteLocal(uid, id);
      return;
    }
    try {
      await _api.deleteOne(id);
    } on HttpStatusException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 501) {
        await LocalNotificationInboxStore.deleteLocal(uid, id);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteAll() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _api.deleteAll();
    } on HttpStatusException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 501) rethrow;
    }
    await LocalNotificationInboxStore.deleteAllLocal(uid);
  }

  @override
  Future<void> recordFromFcm({
    required String type,
    required Map<String, dynamic> payload,
    String? title,
    String? body,
  }) async {
    final uid = _uid;
    final user = _currentUser();
    if (uid == null || user == null) return;
    if (!NotificationInboxRoleFilter.shouldStoreFcmForUser(user, type, payload)) {
      return;
    }

    final mergedPayload = Map<String, dynamic>.from(payload);
    mergedPayload['type'] = type;
    final item = UserNotificationItem.localFromFcm(
      type: type,
      payload: mergedPayload,
      title: title,
      body: body,
    );
    final dedupe = LocalNotificationInboxStore.dedupeKeyForFcm(type, payload);
    await LocalNotificationInboxStore.appendIfNew(
      uid: uid,
      item: item,
      dedupeKey: dedupe,
    );
  }
}
