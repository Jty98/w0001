import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/user_notifications_providers.dart';
import 'package:w0001/util/fcm/fcm_message_payload.dart';
import 'package:w0001/util/fcm/fcm_push_router.dart';
import 'package:w0001/util/worker_dashboard_refresh.dart'
    show
        scheduleWorkerGlobalAnnouncementPreviewReload,
        scheduleWorkerPlaceWorkDayRefresh;

bool _shouldRefreshWorkerDashboard(String type) {
  return type == 'placeworkday_assignment' ||
      type == 'placeworkday_instruction' ||
      type == 'place_access_revoked';
}

bool _shouldRefreshWorkerGlobalAnnouncement(String type) {
  return type == 'worker_announcement_global';
}

/// 알림함 저장 여부와 무관하게 캘린더·대시보드 등 부수 효과만 적용한다.
void applyFcmRefreshSideEffects(
  ProviderContainer container,
  Map<String, dynamic> data,
) {
  final type = fcmResolvedPushType(data);
  if (type == null || type.isEmpty) return;
  if (_shouldRefreshWorkerDashboard(type)) {
    scheduleWorkerPlaceWorkDayRefresh(container);
  }
  if (_shouldRefreshWorkerGlobalAnnouncement(type)) {
    scheduleWorkerGlobalAnnouncementPreviewReload(container);
  }
}

/// FCM 수신 시 알림함(로컬·서버) 갱신.
Future<void> syncFcmToNotificationInbox(
  ProviderContainer container,
  RemoteMessage message,
) async {
  final data = fcmNavigationPayloadFromMessage(message);
  final type = fcmResolvedPushType(data);
  if (type == null || type.isEmpty) return;

  final n = message.notification;
  final title = n?.title?.trim();
  final body = n?.body?.trim();

  try {
    await container.read(userNotificationsUseCaseProvider).recordFromFcm(
          type: type,
          payload: data,
          title: title,
          body: body,
        );
    refreshUserNotificationInbox(container);
    if (_shouldRefreshWorkerDashboard(type)) {
      scheduleWorkerPlaceWorkDayRefresh(container);
    }
    if (_shouldRefreshWorkerGlobalAnnouncement(type)) {
      scheduleWorkerGlobalAnnouncementPreviewReload(container);
    }
  } catch (e, st) {
    debugPrint('syncFcmToNotificationInbox: $e\n$st');
  }
}
