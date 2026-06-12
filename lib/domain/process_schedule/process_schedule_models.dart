/// 서버 `task.id`와 매핑. 로컬 전용 행은 `null`.
final class ProcessScheduleTask {
  ProcessScheduleTask({
    this.serverId,
    required this.name,
    required List<int> scheduledDayIndices,
    required this.paletteIndex,
  }) : scheduledDayIndices =
            List.unmodifiable(_dedupeSort(scheduledDayIndices));

  final String? serverId;
  final String name;

  /// 그리드 열 인덱스 `0 … dayCount-1` (현장 기준 시작일 + offset).
  final List<int> scheduledDayIndices;

  /// UI 팔레트 인덱스. 서버에 저장할지는 정책에 따름(클라에서만 계산해도 됨).
  final int paletteIndex;

  static List<int> _dedupeSort(Iterable<int> raw) {
    final s = raw.toSet().toList()..sort();
    return s;
  }

  ProcessScheduleTask copyWith({
    String? serverId,
    String? name,
    List<int>? scheduledDayIndices,
    int? paletteIndex,
  }) {
    return ProcessScheduleTask(
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      scheduledDayIndices: scheduledDayIndices ?? this.scheduledDayIndices,
      paletteIndex: paletteIndex ?? this.paletteIndex,
    );
  }
}

/// 공정표 한 장(현장 1곳 · 그리드 한 범위).
final class ProcessScheduleData {
  const ProcessScheduleData({
    this.remoteScheduleId,
    this.scheduleVersion,
    required this.gridStart,
    required this.dayCount,
    required this.tasks,
  });

  /// 서버 `place_process_schedules.id` 등.
  final String? remoteScheduleId;

  /// 낙관적 잠금용. GET `version` · PUT 시 `expected_version`으로 전송.
  final int? scheduleVersion;

  /// 열 0이 되는 날짜(일 단위, 시간 무시).
  final DateTime gridStart;
  final int dayCount;
  final List<ProcessScheduleTask> tasks;

  ProcessScheduleData copyWith({
    String? remoteScheduleId,
    int? scheduleVersion,
    bool clearScheduleVersion = false,
    DateTime? gridStart,
    int? dayCount,
    List<ProcessScheduleTask>? tasks,
  }) {
    return ProcessScheduleData(
      remoteScheduleId: remoteScheduleId ?? this.remoteScheduleId,
      scheduleVersion: clearScheduleVersion
          ? null
          : (scheduleVersion ?? this.scheduleVersion),
      gridStart: gridStart ?? this.gridStart,
      dayCount: dayCount ?? this.dayCount,
      tasks: tasks ?? this.tasks,
    );
  }
}
