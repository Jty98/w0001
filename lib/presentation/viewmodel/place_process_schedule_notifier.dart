import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/place_process_schedule_api.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/remote/process_schedule_dto.dart';
import 'package:w0001/data/repository/process_schedule_remote_repository.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/domain/process_schedule/process_schedule_palette.dart';
import 'package:w0001/domain/repository/process_schedule_repository.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/util/fetch_data.dart';

final placeProcessScheduleApiProvider = Provider<PlaceProcessScheduleRemoteApi>(
  (ref) => PlaceProcessScheduleRemoteApi(AppHttpClient.I),
);

final processScheduleRepositoryProvider = Provider<ProcessScheduleRepository>(
  (ref) => ProcessScheduleRemoteRepository(
    ref.read(placeProcessScheduleApiProvider),
  ),
);

/// [PlaceProcessScheduleScreen] 라우트 인자 — `pid`·현장 공사 기간 문자열.
typedef ProcessScheduleFamilyArg = ({
  int pid,
  String pstart,
  String pend,
});

class PlaceProcessScheduleState {
  const PlaceProcessScheduleState({
    required this.data,
    required this.isReady,
    this.loadError,
  });

  final ProcessScheduleData data;
  final bool isReady;

  /// 조회 실패 시 메시지(403 등). 사용자가 닫으면 제거.
  final String? loadError;

  PlaceProcessScheduleState copyWith({
    ProcessScheduleData? data,
    bool? isReady,
    String? loadError,
    bool clearLoadError = false,
  }) {
    return PlaceProcessScheduleState(
      data: data ?? this.data,
      isReady: isReady ?? this.isReady,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }
}

final placeProcessScheduleProvider = NotifierProvider.family<
    PlaceProcessScheduleNotifier,
    PlaceProcessScheduleState,
    ProcessScheduleFamilyArg>(PlaceProcessScheduleNotifier.new);

class PlaceProcessScheduleNotifier extends Notifier<PlaceProcessScheduleState> {
  PlaceProcessScheduleNotifier(this.arg);

  final ProcessScheduleFamilyArg arg;

  ProcessScheduleRepository get _repo =>
      ref.read(processScheduleRepositoryProvider);

  var _loadScheduled = false;

  /// [persist] 직전 정규화와 동일한 형태. 내용이 같으면 PUT 생략.
  ProcessScheduleData? _persistBaseline;

  void _capturePersistBaseline(ProcessScheduleData d) {
    final sorted = ProcessScheduleEditor.sortByEarliestStart(d);
    _persistBaseline = _withPalette(sorted);
  }

  /// `true`면 PUT으로 보낼 페이로드(버전 제외)가 마지막 로드/저장과 다름.
  bool get isScheduleDirty {
    if (!state.isReady || _persistBaseline == null) return true;
    final curNorm =
        _withPalette(ProcessScheduleEditor.sortByEarliestStart(state.data));
    var a = Map<String, dynamic>.from(
      ProcessScheduleDto.buildPutBody(curNorm),
    );
    var b = Map<String, dynamic>.from(
      ProcessScheduleDto.buildPutBody(_persistBaseline!),
    );
    a.remove('expected_version');
    b.remove('expected_version');
    return jsonEncode(a) != jsonEncode(b);
  }

  static DateTime gridStartFromPlacePstart(String pstart) {
    final p = DateTime.tryParse(pstart.trim());
    if (p != null) {
      return DateTime(p.year, p.month, p.day);
    }
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// 현장 추가 시 설정한 공사 기간으로 그리드 열 개수 (단일일·파싱 실패 시 보정).
  static int defaultDayCountFromPlacePeriod(String pstart, String pend) {
    final start = gridStartFromPlacePstart(pstart);
    final pendTrim = pend.trim();
    if (pendTrim.isEmpty || pendTrim == '0') {
      return 1;
    }
    final e = DateTime.tryParse(pendTrim);
    if (e == null) return 28;
    final endDay = DateTime(e.year, e.month, e.day);
    if (endDay.isBefore(start)) return 1;
    final days = endDay.difference(start).inDays + 1;
    return days.clamp(1, 731);
  }

  /// 편집 후 인접 행 색만 재배치(서버에서 받은 팔레트는 로드 시 그대로 둠).
  ProcessScheduleData _withPalette(ProcessScheduleData d) {
    if (d.tasks.isEmpty) return d;
    return ProcessScheduleEditor.applyPaletteIndices(
      d,
      ProcessSchedulePalette.adjacentContrastIndices(d.tasks.length),
    );
  }

  @override
  PlaceProcessScheduleState build() {
    final start = gridStartFromPlacePstart(arg.pstart);
    final dc = defaultDayCountFromPlacePeriod(arg.pstart, arg.pend);
    if (!_loadScheduled) {
      _loadScheduled = true;
      Future.microtask(() async {
        try {
          final raw = await _repo.fetchForPlace(
            placeId: arg.pid,
            gridStartFallback: start,
            dayCount: dc,
          );
          if (!ref.mounted) return;

          /// 서버 그리드와 현장 공사 기간(`arg`)이 어긋나면 날짜 기준으로 현장 기간 열에 맞춤.
          final aligned = ProcessScheduleEditor.remapToNewGrid(raw, start, dc);
          final painted = _withPalette(aligned);
          state = PlaceProcessScheduleState(
            data: painted,
            isReady: true,
            loadError: null,
          );
          _capturePersistBaseline(painted);
        } catch (e) {
          if (!ref.mounted) return;
          state = PlaceProcessScheduleState(
            data: ProcessScheduleData(
              remoteScheduleId: null,
              scheduleVersion: null,
              gridStart: start,
              dayCount: dc,
              tasks: const [],
            ),
            isReady: true,
            loadError: '공정표를 불러오지 못했습니다: $e',
          );
          _capturePersistBaseline(state.data);
        }
      });
    }
    return PlaceProcessScheduleState(
      data: ProcessScheduleData(
        remoteScheduleId: null,
        scheduleVersion: null,
        gridStart: start,
        dayCount: dc,
        tasks: const [],
      ),
      isReady: false,
      loadError: null,
    );
  }

  void clearLoadError() {
    state = state.copyWith(clearLoadError: true);
  }

  /// [invalidate] 없이 서버에서 다시 읽는다. 로딩 중에도 [isReady]를 유지해 화면이 멈추지 않게 한다.
  Future<void> reloadFromServer() async {
    final start = gridStartFromPlacePstart(arg.pstart);
    final dc = defaultDayCountFromPlacePeriod(arg.pstart, arg.pend);
    try {
      final raw = await _repo.fetchForPlace(
        placeId: arg.pid,
        gridStartFallback: start,
        dayCount: dc,
      );
      if (!ref.mounted) return;

      final aligned = ProcessScheduleEditor.remapToNewGrid(raw, start, dc);
      final painted = _withPalette(aligned);
      state = PlaceProcessScheduleState(
        data: painted,
        isReady: true,
        loadError: null,
      );
      _capturePersistBaseline(painted);
    } catch (e) {
      if (!ref.mounted) return;
      if (state.isReady) {
        state = state.copyWith(
          loadError: '공정표를 불러오지 못했습니다: $e',
        );
        return;
      }
      state = PlaceProcessScheduleState(
        data: ProcessScheduleData(
          remoteScheduleId: null,
          scheduleVersion: null,
          gridStart: start,
          dayCount: dc,
          tasks: const [],
        ),
        isReady: true,
        loadError: '공정표를 불러오지 못했습니다: $e',
      );
      _capturePersistBaseline(state.data);
    }
  }

  /// 범위 밖 날짜 선택 시 그리드를 넓혀 해당 일을 열 안에 넣음(저장은 호출 측에서 [persist]).
  void expandGridToIncludeDay(DateTime calendarDay) {
    if (!state.isReady) return;
    final next = _withPalette(
      ProcessScheduleEditor.expandGridToIncludeCalendarDay(
        state.data,
        calendarDay,
      ),
    );
    if (identical(next, state.data)) return;
    state = state.copyWith(data: next, clearLoadError: true);
  }

  void toggleCell(int taskIndex, int dayIndex) {
    if (!state.isReady) return;
    final next = _withPalette(
      ProcessScheduleEditor.toggleDay(
        state.data,
        taskIndex,
        dayIndex,
        sortRows: false,
      ),
    );
    state = state.copyWith(data: next, clearLoadError: true);
  }

  /// 드래그 채우기 — 목표 상태로 고정.
  void applyDayPaint(int taskIndex, int dayIndex, bool turnOn) {
    if (!state.isReady) return;
    final next = ProcessScheduleEditor.setDayState(
      state.data,
      taskIndex,
      dayIndex,
      turnOn,
      sortRows: false,
    );
    if (identical(next, state.data)) return;
    state = state.copyWith(data: _withPalette(next), clearLoadError: true);
  }

  void addProcess(String name, int startIdx, int endIdx) {
    upsertProcess(name, startIdx, endIdx);
  }

  /// 같은 이름 공정이 있으면 일정만 확장 — 중복 행 생성 방지.
  void upsertProcess(String name, int startIdx, int endIdx) {
    if (!state.isReady) return;
    final next = _withPalette(
      ProcessScheduleEditor.upsertTaskRange(
        state.data,
        name,
        startIdx,
        endIdx,
        sortRows: false,
      ),
    );
    state = state.copyWith(data: next, clearLoadError: true);
  }

  /// 투입 기간이 공정표 범위를 벗어날 때 해당 공정 행의 일정 칸을 확장한다.
  void extendTaskToCoverCalendarRange(
    int taskIndex,
    DateTime rangeStart,
    DateTime rangeEndInclusive,
  ) {
    if (!state.isReady) return;
    final next = _withPalette(
      ProcessScheduleEditor.extendTaskToCoverCalendarRange(
        state.data,
        taskIndex,
        rangeStart,
        rangeEndInclusive,
        sortRows: false,
      ),
    );
    if (identical(next, state.data)) return;
    state = state.copyWith(data: next, clearLoadError: true);
  }

  void addEmptyProcess() {
    if (!state.isReady) return;
    final next = _withPalette(
      ProcessScheduleEditor.addEmptyTask(state.data),
    );
    state = state.copyWith(data: next, clearLoadError: true);
  }

  void setTaskName(int taskIndex, String name) {
    if (!state.isReady) return;
    final next = _withPalette(
      ProcessScheduleEditor.setTaskName(
        state.data,
        taskIndex,
        name,
        sortRows: false,
      ),
    );
    state = state.copyWith(data: next, clearLoadError: true);
  }

  /// 공사 시작·종료일(달력). 종료일은 포함(end-inclusive).
  /// 공정 칸은 날짜 기준으로 재배치.
  void applyPlaceWorkPeriod(DateTime rangeStart, DateTime rangeEndInclusive) {
    if (!state.isReady) return;
    final s = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    var e = DateTime(
      rangeEndInclusive.year,
      rangeEndInclusive.month,
      rangeEndInclusive.day,
    );
    if (e.isBefore(s)) e = s;
    final dayCount = e.difference(s).inDays + 1;
    final next = _withPalette(
      ProcessScheduleEditor.remapToNewGrid(
        state.data,
        s,
        dayCount,
        sortRows: false,
      ),
    );
    state = state.copyWith(data: next, clearLoadError: true);
  }

  /// 현장 수정 API(`updatePlace`)로 `pstart`/`pend` 저장 후, 공정표 그리드를 같은 기간으로 맞춤.
  /// 저장에 실패하면 그리드는 바꾸지 않음.
  Future<void> applyPlaceWorkPeriodAndSyncPlaceMaster(
    PlaceInfoModel place,
    DateTime rangeStart,
    DateTime rangeEndInclusive,
  ) async {
    if (!state.isReady) return;
    final pid = place.pid;
    if (pid == null) return;

    final s = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    var e = DateTime(
      rangeEndInclusive.year,
      rangeEndInclusive.month,
      rangeEndInclusive.day,
    );
    if (e.isBefore(s)) e = s;

    final model = PlaceModel(
      pid: pid,
      pname: place.pname,
      pcomplete: place.pcomplete,
      pstart: s.toIso8601String(),
      pend: e.toIso8601String(),
      paddress: place.paddress,
      prevenue: place.pfirstrevenue,
      pcontractTotal: place.pcontractTotal,
      pcontractDate: '',
    );
    await ref.read(placeUseCaseProvider).updatePlace(model);
    await ref.read(placeListProvider.notifier).persistContractDeadline(pid, e);
    applyPlaceWorkPeriod(rangeStart, rangeEndInclusive);
  }

  static (DateTime, DateTime) _calendarBoundsForPlaceInfo(
      PlaceInfoModel place) {
    final p0 = DateTime.tryParse(place.pstart.trim());
    final s = p0 != null ? DateTime(p0.year, p0.month, p0.day) : DateTime.now();
    final pendTrim = place.pend.trim();
    if (pendTrim.isEmpty || pendTrim == '0') {
      return (s, s);
    }
    final p1 = DateTime.tryParse(pendTrim);
    if (p1 == null) return (s, s);
    var e = DateTime(p1.year, p1.month, p1.day);
    if (e.isBefore(s)) e = s;
    return (s, e);
  }

  static bool _sameYmd(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 공정표 저장 후, 그리드가 현장 **시작일보다 앞**이면 `pstart`만 맞춘다.
  ///
  /// `pend`(계약 마감)는 공정표·추가 작업으로 늘리지 않는다.
  /// 작업자 리스트·D-day가 마스터 `pend`를 쓰므로, 여기서를 그리드 종료로 덮어쓰면
  /// 계약 마감과 추가 작업이 한 날짜로 섞인다.
  Future<void> _syncPlaceMasterDatesToGridIfNeeded(
    PlaceInfoModel place,
    ProcessScheduleData saved,
  ) async {
    if (place.pid == null || place.pid != arg.pid) return;
    final g0 = DateTime(
      saved.gridStart.year,
      saved.gridStart.month,
      saved.gridStart.day,
    );
    final (p0, _) = _calendarBoundsForPlaceInfo(place);
    // 그리드가 더 이른 시작인 경우만 pstart 보정. pend는 건드리지 않음.
    if (!_sameYmd(g0, p0) && g0.isBefore(p0)) {
      final model = PlaceModel(
        pid: place.pid,
        pname: place.pname,
        pcomplete: place.pcomplete,
        pstart: ProcessScheduleDto.formatGridDate(g0),
        pend: place.pend,
        paddress: place.paddress,
        prevenue: place.pfirstrevenue,
        pcontractTotal: place.pcontractTotal,
        pcontractDate: '',
      );
      await ref.read(placeUseCaseProvider).updatePlace(model);
      await FetchData.onDataChanged(
        DataChangeEvent.processScheduleSaved.withPid(place.pid!),
      );
    }
  }

  /// 화면 이탈·저장 시 — PUT + 응답 `version` 반영.
  /// [syncPlaceMaster]: 있으면 그리드 시작이 현장보다 이를 때만 `pstart`를 맞춘다.
  /// (`pend` 계약 마감은 공정표 연장으로 바꾸지 않음)
  Future<void> persist({PlaceInfoModel? syncPlaceMaster}) async {
    if (!state.isReady) return;
    if (!isScheduleDirty) return;
    final sorted = ProcessScheduleEditor.sortByEarliestStart(state.data);
    final namedOnly = ProcessScheduleEditor.withoutUnnamedTasks(sorted);
    final cleaned = ProcessScheduleEditor.withoutPlaceholderTasks(namedOnly);
    final painted = _withPalette(cleaned);
    final saved = await _repo.saveSchedule(
      placeId: arg.pid,
      data: painted,
    );
    if (!ref.mounted) return;
    state = state.copyWith(data: saved);
    _capturePersistBaseline(saved);

    final m = syncPlaceMaster;
    if (m != null) {
      try {
        await _syncPlaceMasterDatesToGridIfNeeded(m, saved);
      } catch (e, st) {
        debugPrint('sync place dates after process schedule persist: $e $st');
      }
    }
  }

  static String messageForPersistError(Object e) {
    HttpStatusException? http;
    if (e is HttpStatusException) {
      http = e;
    } else if (e is DioException && e.error is HttpStatusException) {
      http = e.error! as HttpStatusException;
    }
    if (http != null) {
      if (http.statusCode == 409) {
        return '다른 곳에서 먼저 저장되었습니다. 목록을 새로고침한 뒤 다시 시도해 주세요.';
      }
      if (http.statusCode == 403) {
        return '공정표 저장 권한이 없습니다. (관리자에게 문의)';
      }
    }
    return '저장에 실패했습니다: $e';
  }
}
