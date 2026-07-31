import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/datasources/remote/auth_token_storage.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/places_api.dart';
import 'package:w0001/data/datasources/remote/worker_announcements_remote_api.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/notification_settings_model.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/navigation/app_router.dart';
import 'package:w0001/navigation/pending_post_auth_navigation.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/notification_settings_providers.dart';
import 'package:w0001/util/clear_user_providers.dart';
import 'package:w0001/util/fcm/fcm_pending_schedule_link.dart';
import 'package:w0001/util/worker_dashboard_refresh.dart';

int? _parseInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is String) return int.tryParse(v.trim());
  return null;
}

String? _parseString(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? _firstIntIn(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = _parseInt(m[k]);
    if (v != null) return v;
  }
  return null;
}

String? _firstStringIn(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = _parseString(m[k]);
    if (v != null) return v;
  }
  return null;
}

/// FCM·알림함 payload에서 분기용 `type` (snake_case).
String? fcmResolvedPushType(Map<String, dynamic> data) =>
    _resolvedPushType(data);

/// 서버·게이트웨이마다 `type` 키 이름이 다를 수 있어 후보를 순서대로 본다.
String? _resolvedPushType(Map<String, dynamic> data) {
  const keyOrder = <String>[
    'type',
    'push_type',
    'pushType',
    'message_type',
    'messageType',
    'event_type',
    'eventType',
    'notification_type',
    'notificationType',
    'event',
  ];
  for (final k in keyOrder) {
    final raw = _parseString(data[k]);
    if (raw == null) continue;
    return _normalizePushTypeWire(raw);
  }
  return null;
}

/// 서버가 camelCase 등으로 보내는 경우 앱 내부 분기용 snake로 맞춘다.
///
/// 계정 알림 타입: `account_signup_approved`, `account_signup_rejected`,
/// `account_suspended`, `account_reactivated` (정지 해제·비활성→활성),
/// `account_permissions_updated`. 레거시 `account_unsuspended` 등은
/// `account_reactivated` 로 통일한다.
String _normalizePushTypeWire(String raw) {
  switch (raw) {
    case 'workerPlacePhoto':
    case 'worker-place-photo':
    case 'WORKER_PLACE_PHOTO':
      return 'worker_place_photo';
    case 'workerAnnouncementGlobal':
      return 'worker_announcement_global';
    case 'workerAnnouncementPlace':
      return 'worker_announcement_place';
    case 'placeworkdayAssignment':
      return 'placeworkday_assignment';
    case 'placeworkdayInstruction':
      return 'placeworkday_instruction';
    case 'accountSignupApproved':
    case 'account_signup_approved':
      return 'account_signup_approved';
    case 'accountSignupRejected':
    case 'account_signup_rejected':
      return 'account_signup_rejected';
    case 'accountSuspended':
    case 'account_suspended':
      return 'account_suspended';
    case 'accountReactivated':
    case 'accountUnsuspended':
    case 'accountSuspensionLifted':
    case 'account_unsuspended':
      return 'account_reactivated';
    case 'accountPermissionsUpdated':
      return 'account_permissions_updated';
    case 'placeAccessRevoked':
    case 'place_access_revoked':
    case 'place-access-revoked':
      return 'place_access_revoked';
    case 'signupPending':
    case 'signup_pending':
      return 'signup_pending';
    case 'placeEndDateReminder':
    case 'place_end_date_reminder':
      return 'place_end_date_reminder';
    case 'placeMemberInvited':
    case 'place_member_invited':
    case 'place_member_invite':
      return 'place_member_invited';
    case 'placeMemberAdded':
    case 'place_member_added':
      return 'place_member_added';
    default:
      return raw;
  }
}

bool _isAccountPushType(String type) {
  return type == 'account_signup_approved' ||
      type == 'account_signup_rejected' ||
      type == 'account_suspended' ||
      type == 'account_reactivated' ||
      type == 'account_permissions_updated';
}

bool fcmIsAccountPushType(String type) => _isAccountPushType(type);

/// 서버 `notify_user_account_event` 타입과 동일한지 (포그라운드 자동 처리용).
bool fcmAccountPushShouldAutoOpen(Map<String, dynamic> data) {
  final t = _resolvedPushType(data);
  return t == 'account_suspended' ||
      t == 'account_signup_rejected' ||
      t == 'account_signup_approved' ||
      t == 'account_reactivated';
}

(String, String) _accountDefaultBanner(String type) {
  return switch (type) {
    'account_signup_approved' => ('가입 승인', '회원가입이 승인되었습니다.'),
    'account_signup_rejected' => ('가입 거절', '회원가입이 거절되었습니다.'),
    'account_suspended' => ('계정 정지', '계정이 정지되었습니다.'),
    'account_reactivated' => ('계정 활성화', '계정 정지가 해제되었습니다.'),
    'account_permissions_updated' => ('권한 변경', '계정 권한이 변경되었습니다.'),
    _ => ('알림', ''),
  };
}

String _accountAdminNote(Map<String, dynamic> data) {
  return _firstStringIn(data, ['message', 'note', 'reason']) ?? '';
}

String _accountDialogTitle(String type, Map<String, dynamic> data) {
  final fromServer = _firstStringIn(data, ['title']);
  if (fromServer != null && fromServer.isNotEmpty) return fromServer;
  return _accountDefaultBanner(type).$1;
}

String _accountDialogBody(String type, Map<String, dynamic> data) {
  final fromServer = _firstStringIn(data, ['body']);
  final base = (fromServer != null && fromServer.isNotEmpty)
      ? fromServer
      : _accountDefaultBanner(type).$2;
  final note = _accountAdminNote(data);
  if (note.isEmpty) return base;
  return '$base\n\n$note';
}

String? _accountRoleLabel(Map<String, dynamic> data) {
  final r = _firstStringIn(data, ['role', 'new_role', 'newRole']);
  if (r == null || r.isEmpty) return null;
  try {
    return UserRole.parse(r).labelKo;
  } catch (_) {
    return r;
  }
}

Future<void> _showAccountDialogFromPush(
    String type, Map<String, dynamic> data) async {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  final title = _accountDialogTitle(type, data);
  final body = _accountDialogBody(type, data);
  final role =
      type == 'account_permissions_updated' ? _accountRoleLabel(data) : null;
  final content =
      role != null && role.isNotEmpty ? '적용 역할: $role\n\n$body' : body;
  await showDialog<void>(
    context: ctx,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Text(content),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

/// 정지·거절 푸시 수신 시 **로컬 세션만** 정리한다.
///
/// `POST /auth/logout` 을 호출하면 서버가 `user_device.is_active=false` 로
/// 바꿔 재활성화(`account_reactivated`) 푸시가 더 이상 가지 않는다.
/// 관리자 정지는 `app_user.is_active` 만 바꾸므로 FCM 디바이스는 유지해야 한다.
Future<void> _forceLocalSignOut(ProviderContainer container) async {
  await AuthTokenStorage.I.clear();
  await PendingPostAuthNavigation.clear();
  clearAllUserProviders(container);
  container.read(authSessionProvider.notifier).clearSession();
}

Future<void> _handleAccountPushEvent(
  ProviderContainer container,
  String type,
  Map<String, dynamic> data,
  UserRead? user,
) async {
  final router = appBoundGoRouter;
  final pushUid = _firstStringIn(data, ['uid', 'user_id', 'userId']);
  if (user != null &&
      pushUid != null &&
      pushUid.isNotEmpty &&
      pushUid != user.uid) {
    debugPrint(
      'FCM account event: uid mismatch (push=$pushUid session=${user.uid})',
    );
    return;
  }

  if (user == null) {
    await PendingPostAuthNavigation.stash(data);
    router?.go('/login');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showAccountDialogFromPush(type, data));
    });
    return;
  }

  switch (type) {
    case 'account_suspended':
    case 'account_signup_rejected':
      await _forceLocalSignOut(container);
      router?.go('/login');
      router?.refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_showAccountDialogFromPush(type, data));
      });
      return;
    case 'account_signup_approved':
    case 'account_reactivated':
      await container.read(authSessionProvider.notifier).loadCurrentUser();
      if (!_isMountedContext()) return;
      router?.go('/dashboard');
      router?.refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_showAccountDialogFromPush(type, data));
      });
      return;
    case 'account_permissions_updated':
      await container.read(authSessionProvider.notifier).loadCurrentUser();
      if (!_isMountedContext()) return;
      router?.go('/dashboard');
      router?.refresh();
      final roleLabel = _accountRoleLabel(data);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        final buf = StringBuffer();
        if (roleLabel != null && roleLabel.isNotEmpty) {
          buf.writeln('적용 역할: $roleLabel');
        }
        buf.write(_accountDialogBody(type, data));
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(content: Text(buf.toString(), maxLines: 8)),
        );
      });
      return;
    default:
      return;
  }
}

bool _isMountedContext() => rootNavigatorKey.currentContext?.mounted ?? false;

/// 하단 탭 **상황판(홈)** 을 연 뒤 한 단계만 쌓아, 뒤로가기 한 번으로 홈으로 돌아오게 한다.
void _goDashboardThen(void Function(GoRouter router) navigate) {
  final router = appBoundGoRouter;
  if (router == null) return;
  router.go('/dashboard');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 160), () {
        final r = appBoundGoRouter;
        if (r == null || !_isMountedContext()) return;
        navigate(r);
      });
    });
  });
}

/// 라우터·쉘 준비 후 딥링크 실행 (알림 탭·콜드 스타트).
void scheduleFcmNavigationAfterRouterReady(
  ProviderContainer container,
  Map<String, dynamic> data,
) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 160), () {
        unawaited(handleFcmNavigationFromData(container, data));
      });
    });
  });
}

/// 로그인 성공 직후: 보관된 FCM `data`가 있으면 해당 화면으로 보낸다.
Future<void> tryConsumePendingPostAuthFcmNavigation(
  ProviderContainer container,
) async {
  final pending = await PendingPostAuthNavigation.take();
  if (pending == null || pending.isEmpty) return;
  scheduleFcmNavigationAfterRouterReady(container, pending);
}

/// 서버 [data]의 `type`에 따라 화면으로 보낸다.
///
/// [ProviderContainer]는 API 호출·역할 판별에 사용한다.
Future<void> handleFcmNavigationFromData(
  ProviderContainer container,
  Map<String, dynamic> data,
) async {
  final type = _resolvedPushType(data);
  if (type == null) {
    if (data.isNotEmpty) {
      debugPrint(
        'FCM navigation: 알 수 없는 페이로드(type 없음) keys=${data.keys.toList()}',
      );
    }
    return;
  }

  // 알림 설정 확인 (필터링)
  if (!_isAccountPushType(type)) {
    final notificationType = NotificationType.fromFcmType(type);
    if (notificationType != null) {
      try {
        final settingsAsync = await container.read(
          notificationSettingsNotifierProvider.future,
        );
        if (!settingsAsync.isEnabled(notificationType)) {
          debugPrint(
            'FCM: 알림 차단됨 (사용자 설정) type=$type category=${notificationType.displayName}',
          );
          return;
        }
      } catch (e) {
        // 설정 로드 실패 시에는 알림 허용 (기본 동작)
        debugPrint('FCM: 알림 설정 로드 실패, 기본 허용 처리 $e');
      }
    }
  }

  if (_isAccountPushType(type)) {
    final session = container.read(authSessionProvider);
    final u = session.asData?.value;
    await _handleAccountPushEvent(container, type, data, u);
    return;
  }

  final session = container.read(authSessionProvider);
  final user = session.asData?.value;
  if (user == null) {
    await PendingPostAuthNavigation.stash(data);
    appBoundGoRouter?.go('/login');
    return;
  }

  final router = appBoundGoRouter;
  if (router == null) {
    debugPrint('FCM navigation: appBoundGoRouter 가 바인딩되지 않았습니다.');
    return;
  }

  switch (type) {
    case 'place_access_revoked':
      // 접근 권한은 PlaceWorkerMember 단일 기준. 제거 알림 수신 시
      // 현장/공지/대시보드 등 사용자별 캐시를 즉시 무효화한다.
      clearAllUserProviders(container);
      router.refresh();

      final pid = _firstIntIn(data, ['pid', 'place_id', 'placeId']);
      final placeName = _firstStringIn(data, ['place_name', 'placeName']);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        final line = placeName != null && placeName.trim().isNotEmpty
            ? '[${placeName.trim()}] 현장 접근 권한이 해제되었습니다.'
            : (pid != null ? '현장 #$pid 접근 권한이 해제되었습니다.' : '현장 접근 권한이 해제되었습니다.');
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(content: Text(line, maxLines: 2)),
        );
      });

      // 현재 보고 있는 화면이 무엇이든, "현장 관리" 탭으로 돌려서
      // 더 이상 접근 불가한 화면에 머무르지 않게 한다.
      router.go('/place');
      return;
    case 'worker_announcement_global':
    case 'worker_announcement_place':
      final waId = _firstIntIn(data, ['wa_id', 'waId', 'announcement_id']);
      if (waId == null) return;
      final fallbackInboxFilter =
          type == 'worker_announcement_place' ? 'place' : 'global';
      try {
        final api = WorkerAnnouncementsRemoteApi(AppHttpClient.I);
        final item = await api.getById(waId);
        if (!_isMountedContext()) return;
        if (item.scope == WorkerAnnouncementScope.global) {
          _goDashboardThen(
            (r) => r.push('/announcements/view', extra: item),
          );
        } else {
          final pid =
              item.pid ?? _firstIntIn(data, ['pid', 'place_id', 'placeId']);
          if (pid == null) {
            _goDashboardThen(
              (r) => r.push('/announcements/inbox?filter=place'),
            );
            return;
          }
          final place = await PlacesRemoteApi(AppHttpClient.I).get(pid);
          final info = placeReadToPlaceInfoSummaryZeros(place);
          if (!_isMountedContext()) return;
          _goDashboardThen(
            (r) => r.push('/place/detail/announcements', extra: info),
          );
        }
      } catch (e, st) {
        debugPrint('FCM announcement open failed: $e\n$st');
        if (!_isMountedContext()) return;
        _goDashboardThen(
          (r) => r.push('/announcements/inbox?filter=$fallbackInboxFilter'),
        );
      }
      return;
    case 'placeworkday_assignment':
    case 'placeworkday_instruction':
      final workdate =
          _firstStringIn(data, ['workdate', 'work_date', 'taskdate']);
      final pwdid =
          _firstIntIn(data, ['pwdid', 'pwd_id', 'place_work_day_id']) ?? 0;
      if (workdate == null) return;
      if (!user.isWorker) {
        if (!_isMountedContext()) return;
        fcmClearPendingScheduleLink();
        router.push('/dashboard/schedule-full');
        return;
      }
      fcmSetPendingScheduleLink(
        FcmPendingScheduleLink(workdate: workdate, pwdid: pwdid),
      );
      scheduleWorkerPlaceWorkDayRefresh(container);
      if (!_isMountedContext()) return;
      router.go('/calendar');
      return;
    case 'worker_place_photo':
      if (user.isWorker) return;
      final pid = _firstIntIn(data, ['pid', 'place_id', 'placeId']);
      if (pid == null) return;
      try {
        final place = await PlacesRemoteApi(AppHttpClient.I).get(pid);
        final info = placeReadToPlaceInfoSummaryZeros(place);
        if (!_isMountedContext()) return;
        _goDashboardThen(
          (r) => r.push('/place/detail/images', extra: info),
        );
      } catch (e, st) {
        debugPrint('FCM place photo open failed: $e\n$st');
      }
      return;
    case 'signup_pending':
      if (!user.role.canManageMemberAccounts) return;
      _goDashboardThen((r) => r.push('/dashboard/member-queue'));
      return;
    case 'place_end_date_reminder':
      final pendPid = _firstIntIn(data, ['pid', 'place_id', 'placeId']);
      if (pendPid == null) {
        if (!_isMountedContext()) return;
        router.go('/place');
        return;
      }
      try {
        final place = await PlacesRemoteApi(AppHttpClient.I).get(pendPid);
        final info = placeReadToPlaceInfoSummaryZeros(place);
        if (!_isMountedContext()) return;
        if (user.isWorker) {
          _goDashboardThen((r) => r.push('/place/detail', extra: info));
        } else {
          _goDashboardThen((r) => r.push('/place/detail', extra: info));
        }
      } catch (e, st) {
        debugPrint('FCM place end date open failed: $e\n$st');
        if (!_isMountedContext()) return;
        router.go('/place');
      }
      return;
    default:
      debugPrint('FCM navigation: 미처리 type="$type" data=$data');
      return;
  }
}
