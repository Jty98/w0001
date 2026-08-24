import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:w0001/data/model/user_notification_models.dart';
import 'package:w0001/data/model/remote/super_admin_json.dart';

/// 서버 알림함 API 미구현 시 FCM으로 수신한 항목을 기기에 보관한다.
final class LocalNotificationInboxStore {
  LocalNotificationInboxStore._();

  static String _prefsKey(String uid) => 'local_notification_inbox_v1_$uid';

  static Future<List<UserNotificationItem>> list(String uid) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey(uid));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <UserNotificationItem>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        out.add(UserNotificationItem.fromJson(Map<String, dynamic>.from(e)));
      }
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveAll(
    String uid,
    List<UserNotificationItem> items,
  ) async {
    final p = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await p.setString(_prefsKey(uid), encoded);
  }

  static Future<void> clear(String uid) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsKey(uid));
  }

  /// 동일 [dedupeKey] 가 24시간 이내 있으면 추가하지 않는다.
  static Future<UserNotificationItem?> appendIfNew({
    required String uid,
    required UserNotificationItem item,
    required String dedupeKey,
  }) async {
    if (dedupeKey.isEmpty) return null;
    final existing = await list(uid);
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    for (final e in existing) {
      if (e.createdAt.isBefore(cutoff)) continue;
      final key = _dedupeKeyForItem(e);
      if (key == dedupeKey) return null;
    }
    final next = [item, ...existing];
    await saveAll(uid, next);
    return item;
  }

  static String dedupeKeyForFcm(String type, Map<String, dynamic> payload) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = saString(payload[k]);
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    switch (type) {
      case 'signup_pending':
        return 'signup:${pick(['pending_uid', 'uid', 'user_id'])}';
      case 'worker_announcement_global':
      case 'worker_announcement_place':
        return 'wa:${pick(['wa_id', 'waId', 'announcement_id'])}';
      case 'placeworkday_assignment':
      case 'placeworkday_instruction':
        return 'pwd:${pick(['pwdid', 'pwd_id', 'place_work_day_id'])}:'
            '${pick([
              'workdate',
              'work_date',
              'taskdate',
              'startDate',
              'start_date'
            ])}:'
            '${pick(['endDate', 'end_date', 'workdate_end', 'workdateEnd'])}';
      case 'worker_place_photo':
        return 'photo:${pick([
              'pid',
              'place_id',
              'placeId'
            ])}:${pick(['phid', 'photo_id'])}';
      case 'place_end_date_reminder':
        final pid = pick(['pid', 'place_id', 'placeId']);
        final reminder = pick(['pend', 'reminder_date', 'reminderDate']) ?? '';
        final placeNameRaw = pick(['place_name', 'placeName', 'pname']) ?? '';
        final placeName =
            placeNameRaw.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final notificationId = pick(
          ['notification_id', 'id', 'fcm_message_id', 'message_id'],
        );
        if (pid != null && pid.isNotEmpty) {
          return 'pend:$pid:$reminder';
        }
        if (placeName.isNotEmpty) {
          return 'pend-name:$placeName:$reminder';
        }
        if (notificationId != null && notificationId.isNotEmpty) {
          return 'pend-id:$notificationId';
        }
        // pid/현장명 없는 레거시 payload는 항목 소실보다 중복 허용이 낫다.
        return 'pend-fallback:${payload.toString().hashCode}';
      case 'place_access_revoked':
        return 'revoke:${pick(['pid', 'place_id'])}';
      default:
        if (type.startsWith('account_')) {
          return '$type:${pick(['uid', 'user_id'])}';
        }
        return '$type:${pick(['notification_id', 'id'])}';
    }
  }

  static String _dedupeKeyForItem(UserNotificationItem item) {
    return dedupeKeyForFcm(item.type, item.payload);
  }

  static Future<void> markReadLocal(String uid, String id) async {
    final items = await list(uid);
    final i = items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final updated = items[i].copyWith(readAt: DateTime.now());
    final next = [...items]..[i] = updated;
    await saveAll(uid, next);
  }

  static Future<void> deleteLocal(String uid, String id) async {
    final items = await list(uid);
    await saveAll(uid, items.where((e) => e.id != id).toList());
  }

  static Future<void> deleteAllLocal(String uid) async {
    await clear(uid);
  }
}
