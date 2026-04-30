import 'package:w0001/domain/process_schedule/process_schedule_models.dart';

/// 그리드 편집 순수 로직(Flutter 무관). 서버 DTO ↔ [ProcessScheduleData] 변환은 data 레이어에서.
class ProcessScheduleEditor {
  ProcessScheduleEditor._();

  static List<DateTime> columnDates(ProcessScheduleData d) {
    return List.generate(
      d.dayCount,
      (i) => DateTime(d.gridStart.year, d.gridStart.month, d.gridStart.day + i),
    );
  }

  static ProcessScheduleData toggleDay(
    ProcessScheduleData d,
    int taskIndex,
    int dayIndex, {
    bool sortRows = true,
  }) {
    if (taskIndex < 0 || taskIndex >= d.tasks.length) return d;
    if (dayIndex < 0 || dayIndex >= d.dayCount) return d;
    final t = d.tasks[taskIndex];
    final next = t.scheduledDayIndices.toSet();
    if (next.contains(dayIndex)) {
      next.remove(dayIndex);
    } else {
      next.add(dayIndex);
    }
    final list = next.toList()..sort();
    final tasks = [...d.tasks];
    if (list.isEmpty) {
      tasks.removeAt(taskIndex);
    } else {
      tasks[taskIndex] = t.copyWith(scheduledDayIndices: list);
    }
    var out = d.copyWith(tasks: tasks);
    if (sortRows) {
      out = sortByEarliestStart(out);
    }
    return out;
  }

  /// 특정 칸을 켜거나 끕니다. 드래그 채우기용.
  static ProcessScheduleData setDayState(
    ProcessScheduleData d,
    int taskIndex,
    int dayIndex,
    bool value, {
    bool sortRows = true,
  }) {
    if (taskIndex < 0 || taskIndex >= d.tasks.length) return d;
    if (dayIndex < 0 || dayIndex >= d.dayCount) return d;
    final t = d.tasks[taskIndex];
    final next = t.scheduledDayIndices.toSet();
    final had = next.contains(dayIndex);
    if (value && had || !value && !had) return d;
    if (value) {
      next.add(dayIndex);
    } else {
      next.remove(dayIndex);
    }
    final list = next.toList()..sort();
    final tasks = [...d.tasks];
    if (list.isEmpty) {
      tasks.removeAt(taskIndex);
    } else {
      tasks[taskIndex] = t.copyWith(scheduledDayIndices: list);
    }
    var out = d.copyWith(tasks: tasks);
    if (sortRows) {
      out = sortByEarliestStart(out);
    }
    return out;
  }

  static ProcessScheduleData addTaskRange(
    ProcessScheduleData d,
    String name,
    int startIdx,
    int endIdx, {
    bool sortRows = true,
  }) {
    final lo = startIdx.clamp(0, d.dayCount - 1);
    var hi = endIdx.clamp(0, d.dayCount - 1);
    if (hi < lo) hi = lo;
    final span = [for (var i = lo; i <= hi; i++) i];
    final tasks = [
      ...d.tasks,
      ProcessScheduleTask(
        serverId: null,
        name: name,
        scheduledDayIndices: span,
        paletteIndex: 0,
      ),
    ];
    var out = d.copyWith(tasks: tasks);
    if (sortRows) {
      out = sortByEarliestStart(out);
    }
    return out;
  }

  /// 공사 시작(최소 일 인덱스)이 빠른 순. 일정 없음은 맨 아래.
  static ProcessScheduleData sortByEarliestStart(ProcessScheduleData d) {
    final n = d.tasks.length;
    if (n <= 1) return d;

    int minDay(int i) {
      final s = d.tasks[i].scheduledDayIndices;
      if (s.isEmpty) return 1 << 30;
      return s.first;
    }

    int maxDay(int i) {
      final s = d.tasks[i].scheduledDayIndices;
      if (s.isEmpty) return -1;
      return s.last;
    }

    final order = List.generate(n, (i) => i);
    order.sort((a, b) {
      final c = minDay(a).compareTo(minDay(b));
      if (c != 0) return c;
      final c2 = maxDay(a).compareTo(maxDay(b));
      if (c2 != 0) return c2;
      return d.tasks[a].name.compareTo(d.tasks[b].name);
    });

    var identity = true;
    for (var i = 0; i < n; i++) {
      if (order[i] != i) {
        identity = false;
        break;
      }
    }
    if (identity) return d;

    return d.copyWith(
      tasks: [for (final i in order) d.tasks[i]],
    );
  }

  static ProcessScheduleData applyPaletteIndices(
    ProcessScheduleData d,
    List<int> indices,
  ) {
    assert(indices.length == d.tasks.length);
    return d.copyWith(
      tasks: [
        for (var i = 0; i < d.tasks.length; i++)
          d.tasks[i].copyWith(paletteIndex: indices[i]),
      ],
    );
  }

  static DateTime _calendarDay(DateTime any) =>
      DateTime(any.year, any.month, any.day);

  /// [columnDates]와 동일한 규칙으로 열 인덱스 → 그 날짜.
  static DateTime dayAtGridIndex(ProcessScheduleData d, int idx) {
    final g = _calendarDay(d.gridStart);
    return DateTime(g.year, g.month, g.day + idx);
  }

  /// 그리드 안에서만 매핑; 범위 밖 날짜는 해당 칸에서 제외.
  static int? gridIndexForCalendarDay(
    ProcessScheduleData d,
    DateTime absoluteDay,
  ) {
    final g = _calendarDay(d.gridStart);
    final a = _calendarDay(absoluteDay);
    final off = a.difference(g).inDays;
    if (off < 0 || off >= d.dayCount) return null;
    return off;
  }

  /// 새 시작일·열 개수로 바꾸면서, 각 공정의 선택 칸을 **달력 날짜** 기준으로 옮김.
  /// 공사 기간 변경 등에 사용.
  static ProcessScheduleData remapToNewGrid(
    ProcessScheduleData d,
    DateTime newGridStart,
    int newDayCount, {
    bool sortRows = true,
  }) {
    final ng = _calendarDay(newGridStart);
    if (newDayCount < 1) return d;

    final tmp = ProcessScheduleData(
      remoteScheduleId: d.remoteScheduleId,
      scheduleVersion: d.scheduleVersion,
      gridStart: ng,
      dayCount: newDayCount,
      tasks: const [],
    );

    final mappedTasks = <ProcessScheduleTask>[
      for (final t in d.tasks)
        () {
          final nextIdx = <int>{};
          for (final idx in t.scheduledDayIndices) {
            if (idx < 0 || idx >= d.dayCount) continue;
            final dt = dayAtGridIndex(d, idx);
            final mapped = gridIndexForCalendarDay(tmp, dt);
            if (mapped != null) nextIdx.add(mapped);
          }
          final sorted = nextIdx.toList()..sort();
          return t.copyWith(scheduledDayIndices: sorted);
        }(),
    ];

    /// 그리드 밖으로 빠져 일정이 없어진 행은 공정 자체를 제거.
    final tasks = [
      for (final t in mappedTasks)
        if (t.scheduledDayIndices.isNotEmpty) t,
    ];

    var out = ProcessScheduleData(
      remoteScheduleId: d.remoteScheduleId,
      scheduleVersion: d.scheduleVersion,
      gridStart: ng,
      dayCount: newDayCount,
      tasks: tasks,
    );
    if (sortRows) {
      out = sortByEarliestStart(out);
    }
    return out;
  }

  /// 연속 구간마다 라벨을 둘 중앙 열 인덱스.
  static Set<int> labelCenterDayIndices(ProcessScheduleTask task) {
    final days = task.scheduledDayIndices;
    if (days.isEmpty) return {};

    final out = <int>{};
    var segLo = days.first;
    var segHi = days.first;

    void flush() => out.add((segLo + segHi) ~/ 2);

    for (var i = 1; i < days.length; i++) {
      if (days[i] == segHi + 1) {
        segHi = days[i];
      } else {
        flush();
        segLo = segHi = days[i];
      }
    }
    flush();
    return out;
  }
}
