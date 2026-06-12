/// 상황판 일정·메모 (`ScheduleMemo` 테이블).
class ScheduleMemoModel {
  const ScheduleMemoModel({
    this.sid,
    required this.taskDate,
    required this.taskTime,
    required this.title,
    required this.memo,
    required this.done,
    required this.alarmEnabled,
    required this.alarmOffsetMinutes,
    required this.sortOrder,
    required this.createdAtMs,
  });

  final int? sid;

  /// yyyy-MM-dd
  final String taskDate;

  /// HH:mm (24-hour) or empty string when no time is set.
  final String taskTime;
  final String title;
  final String memo;
  final bool done;

  /// True when pre-alarm should ring before schedule time.
  final bool alarmEnabled;

  /// Alarm lead time in minutes (for example 60 = 1 hour before).
  final int alarmOffsetMinutes;
  final int sortOrder;
  final int createdAtMs;

  ScheduleMemoModel copyWith({
    int? sid,
    String? taskDate,
    String? taskTime,
    String? title,
    String? memo,
    bool? done,
    bool? alarmEnabled,
    int? alarmOffsetMinutes,
    int? sortOrder,
    int? createdAtMs,
  }) {
    return ScheduleMemoModel(
      sid: sid ?? this.sid,
      taskDate: taskDate ?? this.taskDate,
      taskTime: taskTime ?? this.taskTime,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      done: done ?? this.done,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmOffsetMinutes: alarmOffsetMinutes ?? this.alarmOffsetMinutes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (sid != null) 'sid': sid,
      'taskDate': taskDate,
      'taskTime': taskTime,
      'title': title,
      'memo': memo,
      'done': done ? 1 : 0,
      'alarmEnabled': alarmEnabled ? 1 : 0,
      'alarmOffsetMinutes': alarmOffsetMinutes,
      'sortOrder': sortOrder,
      'createdAtMs': createdAtMs,
    };
  }

  static ScheduleMemoModel fromMap(Map<String, Object?> m) {
    return ScheduleMemoModel(
      sid: m['sid'] as int?,
      taskDate: (m['taskDate'] as String?) ?? '',
      taskTime: (m['taskTime'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      memo: (m['memo'] as String?) ?? '',
      done: ((m['done'] as int?) ?? 0) != 0,
      alarmEnabled: ((m['alarmEnabled'] as int?) ?? 0) != 0,
      alarmOffsetMinutes: (m['alarmOffsetMinutes'] as int?) ?? 0,
      sortOrder: (m['sortOrder'] as int?) ?? 0,
      createdAtMs: (m['createdAtMs'] as int?) ?? 0,
    );
  }
}
