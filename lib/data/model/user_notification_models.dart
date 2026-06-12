import 'package:w0001/data/model/remote/super_admin_json.dart';

/// 서버·로컬 공통 알림함 항목.
class UserNotificationItem {
  const UserNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.createdAt,
    this.readAt,
    this.isLocalOnly = false,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isLocalOnly;

  bool get isRead => readAt != null;

  UserNotificationItem copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? readAt,
    bool clearReadAt = false,
    bool? isLocalOnly,
  }) {
    return UserNotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }

  factory UserNotificationItem.fromJson(Map<String, dynamic> m) {
    final idRaw = saString(m['id']) ?? saString(m['notification_id']);
    final created = _parseDateTime(
      m['created_at'] ?? m['createdAt'] ?? m['created_at_ms'],
    );
    final read = _parseDateTime(m['read_at'] ?? m['readAt']);
    return UserNotificationItem(
      id: idRaw ?? '',
      type: (saString(m['type']) ?? '').trim(),
      title: (saString(m['title']) ?? '').trim(),
      body: (saString(m['body']) ?? '').trim(),
      payload: saMap(m['payload'] ?? m['data']),
      createdAt: created ?? DateTime.now(),
      readAt: read,
      isLocalOnly: saBool(m['is_local_only']) ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        if (readAt != null) 'read_at': readAt!.toIso8601String(),
        'is_local_only': isLocalOnly,
      };

  static UserNotificationItem localFromFcm({
    required String type,
    required Map<String, dynamic> payload,
    String? title,
    String? body,
  }) {
    final now = DateTime.now();
    final id = 'local_${now.millisecondsSinceEpoch}';
    final t = title?.trim();
    final b = body?.trim();
    return UserNotificationItem(
      id: id,
      type: type,
      title: (t != null && t.isNotEmpty)
          ? t
          : defaultTitleForType(type),
      body: (b != null && b.isNotEmpty)
          ? b
          : defaultBodyForType(type, payload),
      payload: Map<String, dynamic>.from(payload),
      createdAt: now,
      isLocalOnly: true,
    );
  }

  static String defaultTitleForType(String type) {
    return switch (type) {
      'signup_pending' => '가입 승인 대기',
      'worker_announcement_global' => '전체 공지',
      'worker_announcement_place' => '현장 공지',
      'placeworkday_assignment' => '일정 배정',
      'placeworkday_instruction' => '작업 지시',
      'worker_place_photo' => '현장 사진',
      'place_access_revoked' => '현장 접근 해제',
      'place_end_date_reminder' => '공사 종료일 안내',
      'account_signup_approved' => '가입 승인',
      'account_signup_rejected' => '가입 거절',
      'account_suspended' => '계정 정지',
      'account_reactivated' => '계정 활성화',
      'account_permissions_updated' => '권한 변경',
      _ => '알림',
    };
  }

  static String defaultBodyForType(
    String type,
    Map<String, dynamic> payload,
  ) {
    final placeName =
        saString(payload['place_name']) ?? saString(payload['placeName']);
    final uname = saString(payload['uname']) ?? saString(payload['pending_uname']);
    return switch (type) {
      'signup_pending' =>
        uname != null ? '$uname 님 가입 요청' : '새 가입 요청이 있습니다.',
      'worker_place_photo' => placeName != null
          ? '[$placeName] 작업자가 사진을 등록했습니다.'
          : '작업자가 현장 사진을 등록했습니다.',
      'place_end_date_reminder' => placeName != null
          ? '[$placeName] 공사 종료일을 확인해 주세요.'
          : '공사 종료일을 확인해 주세요.',
      'place_access_revoked' => placeName != null
          ? '[$placeName] 접근 권한이 해제되었습니다.'
          : '현장 접근 권한이 해제되었습니다.',
      _ => '탭하여 자세히 보기',
    };
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is int) {
      if (raw > 1e12) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw > 1e9) return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is num) return _parseDateTime(raw.toInt());
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

List<UserNotificationItem> parseUserNotificationList(dynamic data) {
  if (data is List) {
    final out = <UserNotificationItem>[];
    for (final e in data) {
      if (e is! Map) continue;
      final item = UserNotificationItem.fromJson(Map<String, dynamic>.from(e));
      if (item.id.isNotEmpty && item.type.isNotEmpty) out.add(item);
    }
    return out;
  }
  if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    final inner = m['items'] ?? m['data'] ?? m['notifications'] ?? m['results'];
    if (inner != null) return parseUserNotificationList(inner);
    final count = saInt(m['unread_count'] ?? m['unreadCount']);
    if (count != null && m.containsKey('items')) {
      return parseUserNotificationList(m['items']);
    }
  }
  return const [];
}
