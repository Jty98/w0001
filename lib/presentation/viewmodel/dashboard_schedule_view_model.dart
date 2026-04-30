import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/util/widget_data_manager.dart';

DateTime scheduleDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String scheduleDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime scheduleStartOfWeekMonday(DateTime d) {
  final day = scheduleDateOnly(d);
  final fromMon = day.weekday - DateTime.monday;
  return day.subtract(Duration(days: fromMon));
}

DateTime scheduleDateFromTaskKey(String k) {
  final p = k.split('-');
  if (p.length != 3) return DateTime.now();
  return DateTime(
    int.tryParse(p[0]) ?? 0,
    int.tryParse(p[1]) ?? 1,
    int.tryParse(p[2]) ?? 1,
  );
}

class DashboardScheduleState {
  const DashboardScheduleState({
    required this.weekStart,
    required this.selectedDay,
    required this.weekMemos,
    required this.weekMemosByWeekKey,
    required this.isWeekLoading,
    required this.fullMemos,
    required this.isFullLoading,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final List<ScheduleMemoModel> weekMemos;

  /// yyyy-MM-dd of Monday → memos for that week (for horizontal 주 스와이프 캐시).
  final Map<String, List<ScheduleMemoModel>> weekMemosByWeekKey;

  final bool isWeekLoading;

  /// Loaded when user opens "전체보기"; null until first load.
  final List<ScheduleMemoModel>? fullMemos;
  final bool isFullLoading;

  factory DashboardScheduleState.initial() {
    final now = DateTime.now();
    final today = scheduleDateOnly(now);
    final mon = scheduleStartOfWeekMonday(today);
    return DashboardScheduleState(
      weekStart: mon,
      selectedDay: today,
      weekMemos: const [],
      weekMemosByWeekKey: const {},
      isWeekLoading: true,
      fullMemos: null,
      isFullLoading: false,
    );
  }

  List<ScheduleMemoModel> memosForWeekMondayCached(DateTime weekMonday) {
    final mon = scheduleDateOnly(scheduleStartOfWeekMonday(weekMonday));
    final key = scheduleDateKey(mon);
    return weekMemosByWeekKey[key] ?? const [];
  }

  List<ScheduleMemoModel> memosForSelectedDay() {
    final key = scheduleDateKey(selectedDay);
    return weekMemos.where((m) => m.taskDate == key).toList();
  }

  /// Mondays (date-only) that have at least one memo in [fullMemos], ascending.
  List<DateTime> weekMondaysWithMemosSorted() {
    if (fullMemos == null || fullMemos!.isEmpty) return [];
    final map = <String, DateTime>{};
    for (final m in fullMemos!) {
      final d = scheduleDateOnly(scheduleDateFromTaskKey(m.taskDate));
      final mon = scheduleStartOfWeekMonday(d);
      map[scheduleDateKey(mon)] = mon;
    }
    final out = map.values.toList()..sort();
    return out;
  }

  List<ScheduleMemoModel> memosOnFullListForWeekMonday(DateTime weekMonday) {
    if (fullMemos == null) return const [];
    final mon = scheduleDateOnly(weekMonday);
    final fromKey = scheduleDateKey(mon);
    final toKey = scheduleDateKey(mon.add(const Duration(days: 6)));
    final list = fullMemos!
        .where(
          (m) =>
              m.taskDate.compareTo(fromKey) >= 0 && m.taskDate.compareTo(toKey) <= 0,
        )
        .toList();
    list.sort((a, b) {
      final c = a.taskDate.compareTo(b.taskDate);
      if (c != 0) return c;
      return a.taskTime.compareTo(b.taskTime);
    });
    return list;
  }

  DashboardScheduleState copyWith({
    DateTime? weekStart,
    DateTime? selectedDay,
    List<ScheduleMemoModel>? weekMemos,
    Map<String, List<ScheduleMemoModel>>? weekMemosByWeekKey,
    bool? isWeekLoading,
    List<ScheduleMemoModel>? fullMemos,
    bool? isFullLoading,
    bool clearFullMemos = false,
  }) {
    return DashboardScheduleState(
      weekStart: weekStart ?? this.weekStart,
      selectedDay: selectedDay ?? this.selectedDay,
      weekMemos: weekMemos ?? this.weekMemos,
      weekMemosByWeekKey: weekMemosByWeekKey ?? this.weekMemosByWeekKey,
      isWeekLoading: isWeekLoading ?? this.isWeekLoading,
      fullMemos: clearFullMemos ? null : (fullMemos ?? this.fullMemos),
      isFullLoading: isFullLoading ?? this.isFullLoading,
    );
  }
}

class DashboardScheduleViewModel extends Notifier<DashboardScheduleState> {
  static const _alarmNotification = NotificationSettings(
    title: '일정 알람',
    body: '등록한 일정 시간입니다.',
    stopButton: '중지',
  );

  static const _rangeHalfDays = 371;

  /// 좌우 주 스와이프: 과거 52주 + 미래 52주 + 이번 주 기준 한 칸 = 105페이지.
  static const int weekPagePastCount = 52;
  static const int weekPageFutureCount = 52;
  static const int weekPageCount =
      weekPagePastCount + weekPageFutureCount + 1;

  Future<List<ScheduleMemoModel>> _memosBetween(String from, String to) async {
    final r = ref.read(superAdminRemoteRepositoryProvider);
    final all = await r.scheduleMemosList();
    final filtered = all
        .where(
          (m) =>
              m.taskdate.compareTo(from) >= 0 && m.taskdate.compareTo(to) <= 0,
        )
        .toList();
    filtered.sort((a, b) {
      final c = a.taskdate.compareTo(b.taskdate);
      if (c != 0) return c;
      final s = a.sortorder.compareTo(b.sortorder);
      if (s != 0) return s;
      return a.sid.compareTo(b.sid);
    });
    return filtered.map(scheduleMemoReadToModel).toList();
  }

  Future<int> _nextSortOrder(String taskDate) async {
    final r = ref.read(superAdminRemoteRepositoryProvider);
    final all = await r.scheduleMemosList();
    final same = all.where((x) => x.taskdate == taskDate).toList();
    if (same.isEmpty) return 0;
    return same.map((e) => e.sortorder).reduce((a, b) => a > b ? a : b) + 1;
  }

  DateTime _anchorMonday() {
    final today = scheduleDateOnly(DateTime.now());
    final thisMon = scheduleStartOfWeekMonday(today);
    return thisMon.subtract(Duration(days: 7 * weekPagePastCount.toInt()));
  }

  /// [weekMonday]이 속한 PageView 인덱스 (0 … weekPageCount-1).
  int weekPageIndexFor(DateTime weekMonday) {
    final mon = scheduleDateOnly(scheduleStartOfWeekMonday(weekMonday));
    final days = mon.difference(_anchorMonday()).inDays;
    final idx = days ~/ 7;
    if (idx < 0) return 0;
    if (idx >= weekPageCount) return weekPageCount - 1;
    return idx;
  }

  DateTime weekMondayAtPageIndex(int pageIndex) {
    final i = pageIndex.clamp(0, weekPageCount - 1);
    return scheduleDateOnly(_anchorMonday().add(Duration(days: 7 * i)));
  }

  @override
  DashboardScheduleState build() {
    Future.microtask(_reloadWeek);
    return DashboardScheduleState.initial();
  }

  Future<void> _reloadWeek() async {
    state = state.copyWith(isWeekLoading: true);
    try {
      final from = scheduleDateKey(state.weekStart);
      final to = scheduleDateKey(state.weekStart.add(const Duration(days: 6)));
      final list = await _memosBetween(from, to);
      final key = scheduleDateKey(scheduleDateOnly(state.weekStart));
      final map = Map<String, List<ScheduleMemoModel>>.from(
        state.weekMemosByWeekKey,
      );
      map[key] = List<ScheduleMemoModel>.from(list);
      state = state.copyWith(weekMemos: list, weekMemosByWeekKey: map);
    } catch (e, st) {
      debugPrint('DashboardSchedule week reload failed: $e\n$st');
    } finally {
      state = state.copyWith(isWeekLoading: false);
      // 현재 주가 열려 있을 때는 위젯 데이터(풀 + 이번 주)를 함께 동기화한다.
      final now = DateTime.now();
      final thisMon = scheduleStartOfWeekMonday(now);
      if (scheduleDateOnly(state.weekStart) == scheduleDateOnly(thisMon)) {
        await _updateWidgetData();
      }
    }
  }

  Future<void> _reloadFullMemos() async {
    state = state.copyWith(isFullLoading: true);
    try {
      final today = scheduleDateOnly(DateTime.now());
      final firstMonday = scheduleStartOfWeekMonday(
        today.subtract(const Duration(days: _rangeHalfDays)),
      );
      final lastMonday = scheduleStartOfWeekMonday(
        today.add(const Duration(days: _rangeHalfDays)),
      );
      final from = scheduleDateKey(firstMonday);
      final to = scheduleDateKey(lastMonday.add(const Duration(days: 6)));
      final list = await _memosBetween(from, to);
      state = state.copyWith(fullMemos: list);
    } catch (e, st) {
      debugPrint('DashboardSchedule full reload failed: $e\n$st');
    } finally {
      state = state.copyWith(isFullLoading: false);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(weekMemosByWeekKey: const {});
    await _reloadWeek();
    if (state.fullMemos != null) {
      await _reloadFullMemos();
    }
  }

  /// Loads the wide range once; later calls are no-ops until data is cleared.
  Future<void> loadFullMemosIfNeeded() async {
    if (state.fullMemos != null) return;
    await _reloadFullMemos();
  }

  /// Forces full list refresh (e.g. after edits while full view is open).
  Future<void> refreshFullMemosIfLoaded() async {
    if (state.fullMemos == null) return;
    await _reloadFullMemos();
  }

  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: scheduleDateOnly(day));
  }

  void setWeekPageIndex(int pageIndex) {
    final nextStart = weekMondayAtPageIndex(pageIndex);
    if (scheduleDateOnly(nextStart) ==
        scheduleDateOnly(state.weekStart)) {
      return;
    }
    final weekEnd = nextStart.add(const Duration(days: 6));
    var sel = state.selectedDay;
    if (sel.isBefore(nextStart) || sel.isAfter(weekEnd)) {
      sel = nextStart;
    }
    state = state.copyWith(
      weekStart: nextStart,
      selectedDay: sel,
      weekMemos: const [],
    );
    _reloadWeek();
  }

  void goWeek(int deltaWeeks) {
    final cur = weekPageIndexFor(state.weekStart);
    setWeekPageIndex(cur + deltaWeeks);
  }

  ScheduleMemoModel? _findMemoBySid(int sid) {
    for (final e in state.weekMemos) {
      if (e.sid == sid) return e;
    }
    if (state.fullMemos != null) {
      for (final e in state.fullMemos!) {
        if (e.sid == sid) return e;
      }
    }
    return null;
  }

  Future<void> _afterMutation() async {
    state = state.copyWith(weekMemosByWeekKey: const {});
    await _reloadWeek();
    await refreshFullMemosIfLoaded();
    await _updateWidgetData();
  }

  Future<void> _updateWidgetData() async {
    try {
      final thisMon = scheduleStartOfWeekMonday(DateTime.now());
      final poolFrom = scheduleDateKey(thisMon.subtract(const Duration(days: 7 * 52)));
      final poolTo = scheduleDateKey(thisMon.add(const Duration(days: 7 * 52 + 6)));
      final poolList = await _memosBetween(poolFrom, poolTo);
      await WidgetDataManager.saveSchedulePool(poolList);

      final from = scheduleDateKey(thisMon);
      final to = scheduleDateKey(thisMon.add(const Duration(days: 6)));
      final list = await _memosBetween(from, to);
      await WidgetDataManager.updateScheduleWidget(list);
    } catch (e) {
      debugPrint('Widget sync failed: $e');
    }
  }

  Future<void> _applyPendingWidgetDoneUpdates() async {
    final updates = await WidgetDataManager.consumePendingDoneUpdates();
    if (updates.isEmpty) return;

    final r = ref.read(superAdminRemoteRepositoryProvider);
    var changed = false;
    for (final u in updates) {
      final sid = u.sid;
      if (sid == null) continue;
      final current = scheduleMemoReadToModel(await r.scheduleMemoGet(sid));
      if (current.done == u.done) continue;
      final updated = current.copyWith(done: u.done);
      await r.scheduleMemoPatch(sid, <String, dynamic>{'done': u.done});
      await _safeSyncAlarmForMemo(updated);
      changed = true;
    }

    if (!changed) return;
    state = state.copyWith(weekMemosByWeekKey: const {});
    await _reloadWeek();
    await refreshFullMemosIfLoaded();
  }

  /// 앱 포그라운드 복귀 시 위젯에서 발생한 변경을 반영하고 위젯을 재동기화한다.
  Future<void> syncWidgetSnapshotNow() async {
    await _applyPendingWidgetDoneUpdates();
    await _updateWidgetData();
  }

  Future<void> setDone(int sid, bool done) async {
    final found = _findMemoBySid(sid);
    if (found == null) return;
    final r = ref.read(superAdminRemoteRepositoryProvider);
    final updated = found.copyWith(done: done);
    await r.scheduleMemoPatch(sid, <String, dynamic>{'done': done});
    await _safeSyncAlarmForMemo(updated);
    _replaceMemoInState(updated);
    await _updateWidgetData();
  }

  void _replaceMemoInState(ScheduleMemoModel updated) {
    List<ScheduleMemoModel> replaceIn(List<ScheduleMemoModel> src) => src
        .map((m) => m.sid == updated.sid ? updated : m)
        .toList(growable: false);

    final week = replaceIn(state.weekMemos);
    final full = state.fullMemos == null ? null : replaceIn(state.fullMemos!);

    final updatedWeekCache = <String, List<ScheduleMemoModel>>{};
    state.weekMemosByWeekKey.forEach((key, value) {
      updatedWeekCache[key] = replaceIn(value);
    });

    state = state.copyWith(
      weekMemos: week,
      fullMemos: full,
      weekMemosByWeekKey: updatedWeekCache,
    );
  }

  Future<void> addMemo({
    required DateTime date,
    required String taskTime,
    required String title,
    required String memo,
    required bool alarmEnabled,
    required int alarmOffsetMinutes,
  }) async {
    final t = title.trim();
    if (t.isEmpty) return;
    final r = ref.read(superAdminRemoteRepositoryProvider);
    final taskDateKey0 = scheduleDateKey(scheduleDateOnly(date));
    final sort = await _nextSortOrder(taskDateKey0);
    final ms = DateTime.now().millisecondsSinceEpoch;
    final draft = ScheduleMemoModel(
      taskDate: taskDateKey0,
      taskTime: taskTime.trim(),
      title: t,
      memo: memo.trim(),
      done: false,
      alarmEnabled: alarmEnabled,
      alarmOffsetMinutes: alarmOffsetMinutes,
      sortOrder: sort,
      createdAtMs: ms,
    );
    final created = await r.scheduleMemoCreate(scheduleMemoToCreateBody(draft));
    final withSid = scheduleMemoReadToModel(created);
    await _safeSyncAlarmForMemo(withSid);
    await _afterMutation();
  }

  Future<void> updateMemo(ScheduleMemoModel m) async {
    if (m.sid == null) return;
    final t = m.title.trim();
    if (t.isEmpty) return;
    final r = ref.read(superAdminRemoteRepositoryProvider);
    final updated = m.copyWith(title: t, memo: m.memo.trim());
    await r.scheduleMemoPatch(
      m.sid!,
      scheduleMemoToPatchBody(updated),
    );
    await _safeSyncAlarmForMemo(updated);
    await _afterMutation();
  }

  Future<void> deleteMemo(int sid) async {
    final r = ref.read(superAdminRemoteRepositoryProvider);
    await r.scheduleMemoDelete(sid);
    try {
      await Alarm.stop(sid);
    } catch (e, st) {
      debugPrint('Alarm stop failed on deleteMemo($sid): $e\n$st');
    }
    await _afterMutation();
  }

  Future<void> _safeSyncAlarmForMemo(ScheduleMemoModel memo) async {
    try {
      await _syncAlarmForMemo(memo);
    } catch (e, st) {
      debugPrint('Alarm sync failed for sid=${memo.sid}: $e\n$st');
    }
  }

  Future<void> _syncAlarmForMemo(ScheduleMemoModel memo) async {
    final sid = memo.sid;
    if (sid == null) return;

    if (memo.done || !memo.alarmEnabled) {
      await Alarm.stop(sid);
      return;
    }

    final fireAt = _alarmDateTime(memo);
    if (fireAt == null || !fireAt.isAfter(DateTime.now())) {
      await Alarm.stop(sid);
      return;
    }

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: sid,
        dateTime: fireAt,
        assetAudioPath: null,
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: Platform.isIOS,
        androidFullScreenIntent: Platform.isAndroid,
        androidStopAlarmOnTermination: !Platform.isAndroid,
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 5),
          volume: 0.9,
          volumeEnforced: false,
        ),
        notificationSettings: _alarmNotification.copyWith(
          title: memo.title.trim().isEmpty ? '일정 알람' : memo.title.trim(),
          body: memo.memo.trim().isEmpty ? '등록한 일정 시간입니다.' : memo.memo.trim(),
        ),
        payload: jsonEncode({
          'title': memo.title.trim(),
          'memo': memo.memo.trim(),
          'taskDate': memo.taskDate,
          'taskTime': memo.taskTime.trim(),
          'alarmOffsetMinutes': memo.alarmOffsetMinutes,
        }),
      ),
    );
  }

  DateTime? _alarmDateTime(ScheduleMemoModel memo) {
    final time = memo.taskTime.trim();
    if (time.isEmpty) return null;

    final d = memo.taskDate.split('-');
    final t = time.split(':');
    if (d.length != 3 || t.length != 2) return null;

    final year = int.tryParse(d[0]);
    final month = int.tryParse(d[1]);
    final day = int.tryParse(d[2]);
    final hour = int.tryParse(t[0]);
    final minute = int.tryParse(t[1]);
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    final taskAt = DateTime(year, month, day, hour, minute);
    return taskAt.subtract(Duration(minutes: memo.alarmOffsetMinutes));
  }
}

final dashboardScheduleProvider =
    NotifierProvider<DashboardScheduleViewModel, DashboardScheduleState>(
  DashboardScheduleViewModel.new,
);
