import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/user_notification_models.dart';
import 'package:w0001/util/fcm/fcm_push_router.dart' show fcmResolvedPushType;

/// 역할·이벤트별 알림함 노출 규칙 (서버 INSERT 규칙과 맞추는 것이 이상적).
abstract final class NotificationInboxRoleFilter {
  static List<UserNotificationItem> filterForUser(
    UserRead? user,
    List<UserNotificationItem> items,
  ) {
    if (user == null) return const [];
    return items
        .where((e) => shouldStoreFcmForUser(user, e.type, e.payload))
        .toList();
  }

  static bool shouldStoreFcmForUser(
    UserRead user,
    String type,
    Map<String, dynamic> payload,
  ) {
    final t = fcmResolvedPushType(payload) ?? type;
    if (t.isEmpty) return false;

    if (user.isWorker) {
      if (t == 'worker_place_photo' || t == 'signup_pending') return false;
      // 작업지시 등록(push)과 일정 배정(push)이 동시에 오면 중복 — 배정만 노출.
      // (시스템 트레이 중복은 서버에서 작업자에게 instruction FCM 미발송이 이상적)
      if (t == 'placeworkday_instruction') return false;
      return true;
    }

    // 관리자·슈퍼관리자
    if (t == 'signup_pending') {
      return user.role.canManageMemberAccounts;
    }
    if (t.startsWith('account_')) {
      return user.role.canManageMemberAccounts;
    }
    if (t == 'worker_place_photo') return true;
    if (t == 'placeworkday_assignment' || t == 'placeworkday_instruction') {
      return true;
    }
    if (t == 'worker_announcement_global' ||
        t == 'worker_announcement_place' ||
        t == 'place_end_date_reminder' ||
        t == 'place_access_revoked') {
      return true;
    }
    return true;
  }
}
