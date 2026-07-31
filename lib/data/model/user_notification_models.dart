import 'package:w0001/data/model/remote/super_admin_json.dart';
import 'package:w0001/util/funtions.dart';

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
    var item = UserNotificationItem(
      id: idRaw ?? '',
      type: (saString(m['type']) ?? '').trim(),
      title: (saString(m['title']) ?? '').trim(),
      body: (saString(m['body']) ?? '').trim(),
      payload: saMap(m['payload'] ?? m['data']),
      createdAt: created ?? DateTime.now(),
      readAt: read,
      isLocalOnly: saBool(m['is_local_only']) ?? false,
    );
    if (item.type.isNotEmpty) {
      final pw = placeWorkDayDisplayCopy(item.type, item.payload);
      if (pw != null) {
        item = item.copyWith(title: pw.title, body: pw.body);
      }
    }
    return item;
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
    final pw = placeWorkDayDisplayCopy(type, payload);
    return UserNotificationItem(
      id: id,
      type: type,
      title: pw?.title ??
          ((t != null && t.isNotEmpty) ? t : defaultTitleForType(type)),
      body: pw?.body ??
          ((b != null && b.isNotEmpty) ? b : defaultBodyForType(type, payload)),
      payload: Map<String, dynamic>.from(payload),
      createdAt: now,
      isLocalOnly: true,
    );
  }

  /// `placeworkday_*` FCM — type 기준 표시 문구 (신규 투입 vs 지시 변경 구분).
  static ({String title, String body})? placeWorkDayDisplayCopy(
    String type,
    Map<String, dynamic> payload,
  ) {
    final placeName = _placeNameFromPayload(payload);
    final workDateLabel = _workDateLabelFromPayload(payload);
    return switch (type) {
      'placeworkday_assignment' => (
          title: '작업 배정',
          body: _placeWorkDayBody(
            workDateLabel: workDateLabel,
            placeName: placeName,
            suffix: '에 투입되었습니다.',
            fallback: '새 현장에 투입되었습니다.',
          ),
        ),
      'placeworkday_instruction' => (
          title: '작업 지시',
          body: _placeWorkDayBody(
            workDateLabel: workDateLabel,
            placeName: placeName,
            suffix: ' 작업지시가 변경되었습니다.',
            fallback: '작업지시가 변경되었습니다.',
          ),
        ),
      _ => null,
    };
  }

  static String _placeWorkDayBody({
    required String? workDateLabel,
    required String? placeName,
    required String suffix,
    required String fallback,
  }) {
    final hasDate = workDateLabel != null && workDateLabel.isNotEmpty;
    final hasPlace = placeName != null && placeName.isNotEmpty;
    if (hasDate && hasPlace) {
      return '$workDateLabel · $placeName$suffix';
    }
    if (hasDate) return '$workDateLabel$suffix';
    if (hasPlace) return '$placeName$suffix';
    return fallback;
  }

  static String? _workDateLabelFromPayload(Map<String, dynamic> payload) {
    final start = _parsePayloadCalendarDate(
          payload,
          const [
            'workdate',
            'work_date',
            'taskdate',
            'startDate',
            'start_date',
          ],
        ) ??
        _parseNestedRangeDate(payload, isStart: true);
    if (start == null) return null;

    final end = _parsePayloadCalendarDate(
          payload,
          const [
            'endDate',
            'end_date',
            'workdate_end',
            'workdateEnd',
            'endWorkdate',
            'taskdate_end',
          ],
        ) ??
        _parseNestedRangeDate(payload, isStart: false);

    if (end != null && end.isAfter(start)) {
      return _formatWorkDateRangeLabel(start, end);
    }
    return formatDateTimeWeekDayToString(start);
  }

  static DateTime? _parsePayloadCalendarDate(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = saString(payload[key]);
      if (raw == null || raw.trim().isEmpty) continue;
      final iso = normalizeToIsoDateString(raw);
      final dt = DateTime.tryParse(iso);
      if (dt != null) {
        return DateTime(dt.year, dt.month, dt.day);
      }
    }
    return null;
  }

  static DateTime? _parseNestedRangeDate(
    Map<String, dynamic> payload, {
    required bool isStart,
  }) {
    final raw = payload['date_range'] ?? payload['dateRange'];
    if (raw is! Map) return null;
    final nested = Map<String, dynamic>.from(raw);
    return _parsePayloadCalendarDate(
      nested,
      isStart
          ? const ['start', 'start_date', 'startDate']
          : const ['end', 'end_date', 'endDate'],
    );
  }

  /// 기간 투입 알림 — `7월 16일 ~ 7월 18일` 형식.
  static String _formatWorkDateRangeLabel(DateTime start, DateTime end) {
    if (start.year == end.year) {
      return '${start.month}월 ${start.day}일 ~ ${end.month}월 ${end.day}일';
    }
    return '${start.year}년 ${start.month}월 ${start.day}일 ~ '
        '${end.year}년 ${end.month}월 ${end.day}일';
  }

  static String? _placeNameFromPayload(Map<String, dynamic> payload) {
    return saString(payload['place_name']) ??
        saString(payload['placeName']) ??
        saString(payload['pname']);
  }

  static String defaultTitleForType(String type) {
    return switch (type) {
      'signup_pending' => '가입 승인 대기',
      'worker_announcement_global' => '전체 공지',
      'worker_announcement_place' => '현장 공지',
      'placeworkday_assignment' => '작업 배정',
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
    final placeName = _placeNameFromPayload(payload);
    final uname =
        saString(payload['uname']) ?? saString(payload['pending_uname']);
    return switch (type) {
      'signup_pending' => uname != null ? '$uname 님 가입 요청' : '새 가입 요청이 있습니다.',
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
