import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/util/app_toast.dart';
import 'package:w0001/util/fcm/fcm_message_payload.dart';
import 'package:w0001/util/fcm/fcm_push_router.dart';
import 'package:w0001/util/fcm/fcm_message_payload.dart';
import 'package:w0001/util/fcm/fcm_push_router.dart';
import 'package:w0001/util/fetch_data.dart';

/// FCM 스낵바·시스템 알림 탭 — 해당 화면으로 이동.
void openFcmNotificationPayload(
  ProviderContainer container,
  Map<String, dynamic> data,
) {
  AppToast.clear();
  final payload = Map<String, dynamic>.from(data);
  if (!fcmPayloadCanNavigate(payload)) {
    AppToast.show(
      '이 알림은 상세 이동 정보가 없습니다. 알림함에서 확인해 주세요.',
    );
    return;
  }
  scheduleFcmNavigationAfterRouterReady(container, payload);
}

/// [rootProviderContainer] 우선, 없으면 [fallback] 사용.
ProviderContainer? resolveFcmProviderContainer(ProviderContainer fallback) {
  return rootProviderContainer ?? fallback;
}
