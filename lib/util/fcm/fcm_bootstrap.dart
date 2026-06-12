import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/auth/users_api.dart';
import 'package:w0001/data/datasources/remote/auth_token_storage.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/navigation/app_router.dart';
import 'package:w0001/navigation/app_scaffold_messenger.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/util/fcm/fcm_inbox_sync.dart';
import 'package:w0001/util/fcm/fcm_message_payload.dart';
import 'package:w0001/util/fcm/fcm_push_router.dart';
import 'package:w0001/util/notifications/notification_inbox_role_filter.dart';
import 'package:w0001/util/fcm/fcm_token_registration_cache.dart';
import 'package:w0001/util/fcm/open_fcm_notification.dart';

String _fcmPlatformWire() {
  if (kIsWeb) return 'web';
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return Platform.operatingSystem;
}

Future<void> _upsertFcmTokenOnServer(String token) async {
  try {
    await UsersRemoteApi(AppHttpClient.I).putMyFcmDevice(
      fcmToken: token,
      platform: _fcmPlatformWire(),
      deviceId: '',
    );
  } catch (e, st) {
    debugPrint('PUT /users/me/fcm-device failed: $e\n$st');
  }
}

Future<void> _registerFcmTokenIfLoggedIn(
  ProviderContainer container,
  String fcmToken, {
  bool force = false,
}) async {
  if (kIsWeb) return;
  final t = fcmToken.trim();
  if (t.isEmpty) return;
  final user = container.read(authSessionProvider).asData?.value;
  if (user == null) return;
  final at = await AuthTokenStorage.I.readAccess();
  final rt = await AuthTokenStorage.I.readRefresh();
  final hasCred =
      (at != null && at.isNotEmpty) || (rt != null && rt.isNotEmpty);
  if (!hasCred) return;
  if (!force &&
      await FcmTokenRegistrationCache.isAlreadyRegistered(user.uid, t)) {
    return;
  }
  await _upsertFcmTokenOnServer(t);
  await FcmTokenRegistrationCache.markRegistered(user.uid, t);
}

/// iOS·Android 공통: 포그라운드 표시 옵션, 알림 권한 요청, 로그인 시 토큰 서버 등록.
Future<void> _runFcmMobileSetup(ProviderContainer container) async {
  if (kIsWeb) return;

  final messaging = FirebaseMessaging.instance;

  try {
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e, st) {
    debugPrint('FCM foreground presentation: $e\n$st');
  }

  try {
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('FCM requestPermission status: ${settings.authorizationStatus}');
  } catch (e, st) {
    debugPrint('FCM requestPermission: $e\n$st');
  }

  await _registerFcmTokenIfLoggedIn(
    container,
    (await FirebaseMessaging.instance.getToken()) ?? '',
  );
}

/// 현재 FCM 디바이스 토큰을 읽어, 로그인·JWT 가 있을 때만 서버에 등록한다.
Future<void> _registerCurrentTokenToServerIfLoggedIn(
  ProviderContainer container,
) async {
  if (kIsWeb) return;
  final token = await FirebaseMessaging.instance.getToken();
  await _registerFcmTokenIfLoggedIn(container, token ?? '');
}

/// FCM 권한·토큰 서버 등록·리스너 연결. [MyApp]에서 한 번 호출한다.
///
/// 반환값은 로그인 세션 구독이므로 [dispose]에서 [ProviderSubscription.close] 할 것.
ProviderSubscription<AsyncValue<UserRead?>> attachFirebaseMessaging(
  ProviderContainer container,
) {
  if (kIsWeb) {
    return container.listen<AsyncValue<UserRead?>>(
      authSessionProvider,
      (_, __) {},
      fireImmediately: false,
    );
  }

  final messaging = FirebaseMessaging.instance;

  void startMobileSetup() {
    Future<void> run() => _runFcmMobileSetup(container);
    // 안드로이드: 첫 레이아웃 직후 바로 시스템 권한을 띄우면 Activity 가 멈춘 것처럼 보일 수 있어
    // 한 박자 늦춘다 (알람 초기화와도 시간을 어느 정도 어긋낸다).
    if (!kIsWeb && Platform.isAndroid) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        unawaited(run());
      });
    } else {
      unawaited(run());
    }
  }

  // Android도 첫 프레임 이후에 권한·토큰 초기화를 돌린다. initState 직후에는
  // Activity/FlutterView 가 완전히 붙기 전이라 시스템 권한 UI가 뜨면 터치가 먹지 않는
  // 현상이 나올 수 있다.
  WidgetsBinding.instance.addPostFrameCallback((_) => startMobileSetup());

  messaging.onTokenRefresh.listen((t) {
    unawaited(_registerFcmTokenIfLoggedIn(container, t, force: true));
  });

  void onRemoteMessage(RemoteMessage m, {required bool showForegroundBanner}) {
    final c = resolveFcmProviderContainer(container);
    if (c == null) return;
    final data = fcmNavigationPayloadFromMessage(m);
    final type = fcmResolvedPushType(data);
    final user = c.read(authSessionProvider).asData?.value;
    final deliverToInbox = user == null ||
        type == null ||
        type.isEmpty ||
        NotificationInboxRoleFilter.shouldStoreFcmForUser(user, type, data);

    if (deliverToInbox) {
      unawaited(syncFcmToNotificationInbox(c, m));
    }
    if (!showForegroundBanner) {
      openFcmNotificationPayload(c, data);
      return;
    }
    if (!deliverToInbox) return;
    final n = m.notification;
    final parts = <String>[];
    final title = n?.title?.trim();
    if (title != null && title.isNotEmpty) parts.add(title);
    final body = n?.body?.trim();
    if (body != null && body.isNotEmpty) parts.add(body);
    final text =
        parts.isEmpty ? '새 알림이 도착했습니다.' : parts.join('\n');
    final canOpen = fcmPayloadCanNavigate(data);
    appScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canOpen ? () => openFcmNotificationPayload(c, data) : null,
          child: Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
        ),
        action: canOpen
            ? SnackBarAction(
                label: '열기',
                onPressed: () => openFcmNotificationPayload(c, data),
              )
            : SnackBarAction(
                label: '목록',
                onPressed: () {
                  final ctx = rootNavigatorKey.currentContext;
                  if (ctx == null || !ctx.mounted) return;
                  GoRouter.of(ctx).push('/dashboard/notifications');
                },
              ),
      ),
    );
    if (fcmAccountPushShouldAutoOpen(data)) {
      openFcmNotificationPayload(c, data);
    }
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage m) {
    onRemoteMessage(m, showForegroundBanner: true);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
    final data = fcmNavigationPayloadFromMessage(m);
    if (data.isEmpty) {
      debugPrint(
        'FCM onMessageOpenedApp: data 가 비어 있습니다. notification=${m.notification}',
      );
    }
    final c = resolveFcmProviderContainer(container);
    if (c == null) return;
    unawaited(syncFcmToNotificationInbox(c, m));
    openFcmNotificationPayload(c, data);
  });

  messaging.getInitialMessage().then((RemoteMessage? m) {
    if (m == null) return;
    final data = fcmNavigationPayloadFromMessage(m);
    if (data.isEmpty) {
      debugPrint(
        'FCM getInitialMessage: data 가 비어 있습니다. notification=${m.notification}',
      );
    }
    final c = resolveFcmProviderContainer(container);
    if (c == null) return;
    unawaited(syncFcmToNotificationInbox(c, m));
    openFcmNotificationPayload(c, data);
  });

  return container.listen<AsyncValue<UserRead?>>(
    authSessionProvider,
    (prev, next) {
      final prevUid = prev?.asData?.value?.uid;
      final nextUid = next.asData?.value?.uid;
      if (nextUid == null) return;
      // 동일 계정 재조회(loadCurrentUser)마다 PUT 하지 않음
      if (prevUid == nextUid && prev?.asData?.value != null) return;
      unawaited(_registerCurrentTokenToServerIfLoggedIn(container));
    },
    fireImmediately: true,
  );
}
