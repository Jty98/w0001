import 'dart:async' show Timer, unawaited;

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/util/schedule_memo_alarm_sync.dart';
import 'package:w0001/util/widget_data_manager.dart';

DateTime scheduleDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String scheduleDateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
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
      isWeekLoading: false,
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
              m.taskDate.compareTo(fromKey) >= 0 &&
              m.taskDate.compareTo(toKey) <= 0,
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
  /// 전체보기·위젯 풀 — 과거/미래 주 수 (742일 일괄 로드 대신).
  static const int _fullViewWeekRadius = 12;
  static const int _widgetWeekRadius = 4;

  /// 좌우 주 스와이프: 과거 52주 + 미래 52주 + 이번 주 기준 한 칸 = 105페이지.
  static const int weekPagePastCount = 52;
  static const int weekPageFutureCount = 52;
  static const int weekPageCount = weekPagePastCount + weekPageFutureCount + 1;

  int _weekReloadGeneration = 0;

  static const Duration _donePatchDebounce = Duration(milliseconds: 650);
  final Map<int, Timer> _donePatchTimers = {};
  final Map<int, bool> _pendingDoneValues = {};

  bool? _tryReadUserIsWorker() {
    try {
      return ref.read(authSessionProvider).asData?.value?.isWorker;
    } catch (e) {
      if (e is StateError && e.toString().contains('uninitialized provider')) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<ScheduleMemoModel>> _memosBetween(String from, String to) async {
    final r = ref.read(superAdminRemoteRepositoryProvider);
    final base = ListQuery(from: from, to: to);
    final filtered = <ScheduleMemoRead>[];
    String? cursor;
    var guard = 0;
    while (guard++ < 100) {
      final q = cursor == null
          ? base.copyWith(clearCursor: true)
          : base.copyWith(cursor: cursor);
      final page = await r.scheduleMemosQueryPage(q);
      filtered.addAll(page.items);
      if (!page.canLoadMore) break;
      cursor = page.nextCursor!.trim();
    }
    filtered.sort((a, b) {
      final c = a.taskdate.compareTo(b.taskdate);
      if (c != 0) return c;
      final s = a.sortorder.compareTo(b.sortorder);
      if (s != 0) return s;
      return a.sid.compareTo(b.sid);
    });
    return filtered.map(scheduleMemoReadToModel).toList();
  }

  Future<List<ScheduleMemoModel>> _memosForSameDay(String taskDate) async {
    final r = ref.read(superAdminRemoteRepositoryProvider);
    final page = await r.scheduleMemosQueryPage(
      ListQuery(from: taskDate, to: taskDate),
    );
    return page.items.map(scheduleMemoReadToModel).toList();
  }

  Future<int> _nextSortOrder(String taskDate) async {
    final same = await _memosForSameDay(taskDate);
    if (same.isEmpty) return 0;
    return same.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
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

  void _onAuthSessionForSchedule(
      AsyncValue<UserRead?>? prev, AsyncValue<UserRead?> next) {
    final u = next.asData?.value;
    if (u == null) return;
    if (u.isWorker) {
      state = state.copyWith(
        isWeekLoading: false,
        weekMemos: const [],
        weekMemosByWeekKey: const {},
      );
      return;
    }
    unawaited(Future<void>.microtask(() => _reloadWeek(isWorker: false)));
  }

  @override
  DashboardScheduleState build() {
    ref.onDispose(_disposeDonePatchState);
    ref.listen<AsyncValue<UserRead?>>(
        authSessionProvider, _onAuthSessionForSchedule,
        fireImmediately: true);
    return DashboardScheduleState.initial();
  }

  void _disposeDonePatchState() {
    unawaited(flushPendingDonePatches());
  }

  /// 디바운스 대기 중인 완료(done) 변경을 즉시 서버에 반영합니다.
  /// 화면 이탈·탭 전환·앱 백그라운드·새로고침 직전에 호출합니다.
  Future<void> flushPendingDonePatches() async {
    for (final timer in _donePatchTimers.values) {
      timer.cancel();
    }
    _donePatchTimers.clear();
    if (_pendingDoneValues.isEmpty) return;

    final pending = Map<int, bool>.from(_pendingDoneValues);
    _pendingDoneValues.clear();
    for (final entry in pending.entries) {
      await _flushDonePatch(entry.key, entry.value);
    }
  }

  String _weekCacheKey(DateTime weekMonday) =>
      scheduleDateKey(scheduleDateOnly(scheduleStartOfWeekMonday(weekMonday)));

  List<ScheduleMemoModel>? _cachedWeekMemos(DateTime weekMonday) {
    final cached = state.weekMemosByWeekKey[_weekCacheKey(weekMonday)];
    if (cached == null) return null;
    return List<ScheduleMemoModel>.from(cached);
  }

  void _applyWeekToState({
    required DateTime weekMonday,
    required List<ScheduleMemoModel> memos,
    required Map<String, List<ScheduleMemoModel>> cache,
    bool? isWeekLoading,
  }) {
    final isCurrent =
        _weekCacheKey(weekMonday) == _weekCacheKey(state.weekStart);
    state = state.copyWith(
      weekMemosByWeekKey: cache,
      weekMemos: isCurrent ? memos : state.weekMemos,
      isWeekLoading: isCurrent
          ? (isWeekLoading ?? state.isWeekLoading)
          : state.isWeekLoading,
    );
  }

  Future<void> _reloadWeek({
    bool? isWorker,
    DateTime? weekMonday,
    bool background = false,
  }) async {
    final targetMonday = scheduleDateOnly(
        scheduleStartOfWeekMonday(weekMonday ?? state.weekStart));
    final gen = ++_weekReloadGeneration;
    final worker = isWorker ?? _tryReadUserIsWorker();
    if (worker == true || worker == null) {
      if (gen == _weekReloadGeneration) {
        state = state.copyWith(isWeekLoading: false);
      }
      return;
    }

    final cacheKey = _weekCacheKey(targetMonday);
    final cached = state.weekMemosByWeekKey[cacheKey];
    final isCurrent = cacheKey == _weekCacheKey(state.weekStart);

    if (cached != null && isCurrent) {
      state = state.copyWith(
        weekMemos: List<ScheduleMemoModel>.from(cached),
        isWeekLoading: false,
      );
    } else if (!background && cached == null && isCurrent) {
      state = state.copyWith(isWeekLoading: true);
    }

    try {
      final from = scheduleDateKey(targetMonday);
      final to = scheduleDateKey(targetMonday.add(const Duration(days: 6)));
      final list = await _memosBetween(from, to);
      if (gen != _weekReloadGeneration || !ref.mounted) return;

      final map = Map<String, List<ScheduleMemoModel>>.from(
        state.weekMemosByWeekKey,
      );
      map[cacheKey] = List<ScheduleMemoModel>.from(list);
      _applyWeekToState(
        weekMonday: targetMonday,
        memos: list,
        cache: map,
        isWeekLoading: false,
      );
    } catch (e, st) {
      debugPrint('DashboardSchedule week reload failed: $e\n$st');
      if (gen == _weekReloadGeneration && ref.mounted && isCurrent) {
        state = state.copyWith(isWeekLoading: false);
      }
    } finally {
      if (gen == _weekReloadGeneration) {
        final now = DateTime.now();
        final thisMon = scheduleStartOfWeekMonday(now);
        if (scheduleDateOnly(state.weekStart) == scheduleDateOnly(thisMon)) {
          await _updateWidgetData();
        }
      }
    }
  }

  Future<void> _reloadFullMemos() async {
    final worker = _tryReadUserIsWorker();
    if (worker == true) {
      state = state.copyWith(isFullLoading: false);
      return;
    }
    if (worker == null) {
      state = state.copyWith(isFullLoading: false);
      return;
    }
    state = state.copyWith(isFullLoading: true);
    try {
      final today = scheduleDateOnly(DateTime.now());
      final firstMonday = scheduleStartOfWeekMonday(
        today.subtract(Duration(days: 7 * _fullViewWeekRadius)),
      );
      final lastMonday = scheduleStartOfWeekMonday(
        today.add(Duration(days: 7 * _fullViewWeekRadius)),
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

  /// 상황판 진입·세션 확정 시 호출. [force]면 캐시를 비우고 다시 시도한다.
  Future<void> ensureWeekLoaded({bool force = false}) async {
    if (force) {
      _weekReloadGeneration++;
      state = state.copyWith(weekMemosByWeekKey: const {});
    }
    await _reloadWeek();
  }

  Future<void> refresh() async {
    await flushPendingDonePatches();
    state = state.copyWith(weekMemosByWeekKey: const {});
    await _reloadWeek();
    if (state.fullMemos != null) {
      await _reloadFullMemos();
    }
  }

  /// Loads the wide range once; later calls are no-ops until data is cleared.
  Future<void> loadFullMemosIfNeeded() async {
    await flushPendingDonePatches();
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
    if (scheduleDateOnly(nextStart) == scheduleDateOnly(state.weekStart)) {
      return;
    }
    final weekEnd = nextStart.add(const Duration(days: 6));
    var sel = state.selectedDay;
    if (sel.isBefore(nextStart) || sel.isAfter(weekEnd)) {
      sel = nextStart;
    }

    final cached = _cachedWeekMemos(nextStart);
    state = state.copyWith(
      weekStart: nextStart,
      selectedDay: sel,
      weekMemos: cached ?? const [],
      isWeekLoading: cached == null,
    );

    unawaited(
      _reloadWeek(
        weekMonday: nextStart,
        background: cached != null,
      ),
    );
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
    await flushPendingDonePatches();
    state = state.copyWith(weekMemosByWeekKey: const {});
    await _reloadWeek();
    await refreshFullMemosIfLoaded();
    await _updateWidgetData();
  }

  Future<void> _updateWidgetData() async {
    try {
      final thisMon = scheduleStartOfWeekMonday(DateTime.now());
      final poolFrom = scheduleDateKey(
        thisMon.subtract(Duration(days: 7 * _widgetWeekRadius)),
      );
      final poolTo = scheduleDateKey(
        thisMon.add(Duration(days: 7 * _widgetWeekRadius + 6)),
      );
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

  Future<void> setDone(int sid, bool done) {
    final found = _findMemoBySid(sid);
    if (found == null) return Future.value();
    _replaceMemoInState(found.copyWith(done: done));

    _pendingDoneValues[sid] = done;
    _donePatchTimers[sid]?.cancel();
    _donePatchTimers[sid] = Timer(_donePatchDebounce, () {
      unawaited(_flushDonePatch(sid, _pendingDoneValues.remove(sid) ?? done));
    });
    return Future.value();
  }

  Future<void> _flushDonePatch(int sid, bool done) async {
    _donePatchTimers.remove(sid)?.cancel();
    if (!ref.mounted) return;

    final found = _findMemoBySid(sid);
    if (found == null) return;

    final r = ref.read(superAdminRemoteRepositoryProvider);
    try {
      await r.scheduleMemoPatch(sid, <String, dynamic>{'done': done});
      final updated = found.copyWith(done: done);
      await _safeSyncAlarmForMemo(updated);
      _replaceMemoInState(updated);
      await _updateWidgetData();
    } catch (e, st) {
      debugPrint('schedule memo done patch failed sid=$sid: $e\n$st');
      await _reloadWeek();
      await refreshFullMemosIfLoaded();
    }
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
    await syncScheduleMemoLocalAlarmSafe(memo);
  }
}

final dashboardScheduleProvider =
    NotifierProvider<DashboardScheduleViewModel, DashboardScheduleState>(
  DashboardScheduleViewModel.new,
);
