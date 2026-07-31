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

  /// 이름·일정 없는 빈 행 — 구분 열에서 이름을 직접 입력한다.
  static ProcessScheduleData addEmptyTask(
    ProcessScheduleData d, {
    bool sortRows = false,
  }) {
    if (d.dayCount < 1) return d;
    final tasks = [
      ...d.tasks,
      ProcessScheduleTask(
        serverId: null,
        name: '',
        scheduledDayIndices: const [],
        paletteIndex: 0,
      ),
    ];
    var out = d.copyWith(tasks: tasks);
    if (sortRows) {
      out = sortByEarliestStart(out);
    }
    return out;
  }

  static ProcessScheduleData setTaskName(
    ProcessScheduleData d,
    int taskIndex,
    String name, {
    bool sortRows = false,
  }) {
    if (taskIndex < 0 || taskIndex >= d.tasks.length) return d;
    final tasks = [...d.tasks];
    tasks[taskIndex] = tasks[taskIndex].copyWith(name: name.trim());
    var out = d.copyWith(tasks: tasks);
    if (sortRows) {
      out = sortByEarliestStart(out);
    }
    return out;
  }

  /// 저장 전 — 이름이 비어 있는 행은 제외한다.
  static ProcessScheduleData withoutUnnamedTasks(ProcessScheduleData d) {
    final tasks =
        d.tasks.where((t) => t.name.trim().isNotEmpty).toList(growable: false);
    if (tasks.length == d.tasks.length) return d;
    return d.copyWith(tasks: tasks);
  }

  /// UI 기본값으로만 쓰이던 플레이스홀더 — 실제 공정으로 저장하지 않는다.
  static const placeholderProcessTaskName = '추가 공정';

  static ProcessScheduleData withoutPlaceholderTasks(ProcessScheduleData d) {
    final tasks = d.tasks
        .where((t) => t.name.trim() != placeholderProcessTaskName)
        .toList(growable: false);
    if (tasks.length == d.tasks.length) return d;
    return d.copyWith(tasks: tasks);
  }

  /// 같은 이름 공정이 있으면 일정만 합치고, 없을 때만 새 행을 추가한다.
  static ProcessScheduleData upsertTaskRange(
    ProcessScheduleData d,
    String name,
    int startIdx,
    int endIdx, {
    bool sortRows = true,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || d.dayCount < 1) return d;

    final lo = startIdx.clamp(0, d.dayCount - 1);
    var hi = endIdx.clamp(0, d.dayCount - 1);
    if (hi < lo) hi = lo;
    final span = {for (var i = lo; i <= hi; i++) i};

    for (var ti = 0; ti < d.tasks.length; ti++) {
      if (d.tasks[ti].name.trim() != trimmed) continue;
      final t = d.tasks[ti];
      final next = t.scheduledDayIndices.toSet()..addAll(span);
      final tasks = [...d.tasks];
      tasks[ti] = t.copyWith(
        scheduledDayIndices: (next.toList()..sort()),
      );
      var out = d.copyWith(tasks: tasks);
      if (sortRows) {
        out = sortByEarliestStart(out);
      }
      return out;
    }

    return addTaskRange(d, trimmed, lo, hi, sortRows: sortRows);
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

  /// [calendarDay]가 현재 열 범위에 들어오도록 [gridStart]·[dayCount]를 키운 뒤,
  /// 기존 공정은 [remapToNewGrid]로 날짜 기준 유지.
  static ProcessScheduleData expandGridToIncludeCalendarDay(
    ProcessScheduleData d,
    DateTime calendarDay,
  ) {
    final target = _calendarDay(calendarDay);
    final g0 = _calendarDay(d.gridStart);
    final lastIdx = d.dayCount - 1;
    final g1 = lastIdx < 0
        ? g0
        : _calendarDay(
            DateTime(g0.year, g0.month, g0.day + lastIdx),
          );

    var newStart = g0;
    var newEnd = g1;
    if (target.isBefore(newStart)) newStart = target;
    if (target.isAfter(newEnd)) newEnd = target;

    var newDayCount = newEnd.difference(newStart).inDays + 1;
    newDayCount = newDayCount.clamp(1, 731);
    if (newStart == g0 && newDayCount == d.dayCount) return d;
    return remapToNewGrid(d, newStart, newDayCount, sortRows: true);
  }

  /// 선택 공정의 [scheduledDayIndices]를 [rangeStart]~[rangeEndInclusive] 달력 구간까지 확장.
  static ProcessScheduleData extendTaskToCoverCalendarRange(
    ProcessScheduleData d,
    int taskIndex,
    DateTime rangeStart,
    DateTime rangeEndInclusive, {
    bool sortRows = true,
  }) {
    if (taskIndex < 0 || taskIndex >= d.tasks.length) return d;
    var s = _calendarDay(rangeStart);
    var e = _calendarDay(rangeEndInclusive);
    if (e.isBefore(s)) {
      final t = s;
      s = e;
      e = t;
    }

    var data = expandGridToIncludeCalendarDay(d, s);
    data = expandGridToIncludeCalendarDay(data, e);

    final task = data.tasks[taskIndex];
    final next = task.scheduledDayIndices.toSet();
    var cur = s;
    while (!cur.isAfter(e)) {
      final idx = gridIndexForCalendarDay(data, cur);
      if (idx != null) next.add(idx);
      cur = DateTime(cur.year, cur.month, cur.day + 1);
    }

    final tasks = [...data.tasks];
    tasks[taskIndex] = task.copyWith(
      scheduledDayIndices: (next.toList()..sort()),
    );
    var out = data.copyWith(tasks: tasks);
    if (sortRows) {
      out = sortByEarliestStart(out);
    }
    return out;
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
