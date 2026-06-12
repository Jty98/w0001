import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/util/auth_dio_user_message.dart';
import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show materialCostUseCaseProvider, workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show humanUseCaseProvider;
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/ui/screen/2_add/work_role_suggestions.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/2_add/add_cost_date_picker_dialog.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';

/// 금액 추가 탭에서 현장이 선택된 상태의 **시스템 뒤로가기** — 선택 해제 후 `true`.
///
/// 탭 전환에는 호출하지 않는다. ([GoRoute.onExit]에 두면 다른 탭으로 나갈 때
/// 현장만 초기화되고 쉘 인덱스와 탭바가 어긋날 수 있음.)
///
/// [go_router] 쉘 루트에서는 [PopScope]만으로 Android 뒤로가기가 앱 종료로 이어질 수
/// 있어 [BackButtonListener]와 함께 사용한다.
bool consumeAddCostBackNavigation() {
  final c = rootProviderContainer;
  if (c == null) return false;
  if (c.read(addCostProvider).selectedPlace == null) return false;
  c.read(addCostProvider.notifier).clearSelectedPlace();
  return true;
}

class AddCostState {
  const AddCostState({
    required this.materialCostList,
    required this.workCostList,
    required this.selectDay,
    required this.alertText,
    required this.selectedPlace,
    required this.costPlacePickerFilter,
    required this.selectedWorker,
    required this.selectedWorkers,
    required this.placeRecentWorkers,
    required this.selectedCategory,
    required this.isSaving,
    required this.processTasksOnSelectDay,
    required this.processTasksLoading,
  });

  final List<MaterialCostModel> materialCostList;
  final List<WorkCostModel> workCostList;
  final DateTime selectDay;
  final String alertText;
  final PlaceModel? selectedPlace;

  /// 금액 추가 화면 현장 목록 분류.
  final CostPlacePickerFilter costPlacePickerFilter;

  /// 하위 호환(기존 코드). 현재 UI에서는 `selectedWorkers`가 메인이며,
  /// 이 값은 마지막 선택(또는 1명 선택 시) 용도로 유지한다.
  final HumanModel? selectedWorker;

  /// 드롭다운 선택 상태(현재 날짜·현장의 미저장 목록과 동기화).
  final List<HumanModel> selectedWorkers;

  /// 선택된 현장에서 예전에 투입했던 인원(최근 순, DB).
  final List<HumanModel> placeRecentWorkers;
  final String? selectedCategory;

  /// 선택 현장·날짜의 공정표에 잡힌 공정 이름.
  final List<String> processTasksOnSelectDay;

  final bool processTasksLoading;

  /// 저장 중 여부 (중복 저장 방지용)
  final bool isSaving;

  bool get isAllEmpty => workCostList.isEmpty && materialCostList.isEmpty;

  factory AddCostState.initial() => AddCostState(
        materialCostList: const [],
        workCostList: const [],
        selectDay: (() {
          final n = DateTime.now();
          return DateTime(n.year, n.month, n.day);
        })(),
        alertText: '',
        selectedPlace: null,
        costPlacePickerFilter: CostPlacePickerFilter.inProgress,
        selectedWorker: null,
        selectedWorkers: const [],
        placeRecentWorkers: const [],
        selectedCategory: null,
        processTasksOnSelectDay: const [],
        processTasksLoading: false,
        isSaving: false,
      );

  AddCostState copyWith({
    List<MaterialCostModel>? materialCostList,
    List<WorkCostModel>? workCostList,
    DateTime? selectDay,
    String? alertText,
    PlaceModel? selectedPlace,
    bool clearSelectedPlace = false,
    CostPlacePickerFilter? costPlacePickerFilter,
    HumanModel? selectedWorker,
    bool clearSelectedWorker = false,
    List<HumanModel>? selectedWorkers,
    bool clearSelectedWorkers = false,
    List<HumanModel>? placeRecentWorkers,
    bool clearPlaceRecentWorkers = false,
    String? selectedCategory,
    bool clearSelectedCategory = false,
    List<String>? processTasksOnSelectDay,
    bool? processTasksLoading,
    bool? isSaving,
  }) {
    return AddCostState(
      materialCostList: materialCostList ?? this.materialCostList,
      workCostList: workCostList ?? this.workCostList,
      selectDay: selectDay ?? this.selectDay,
      alertText: alertText ?? this.alertText,
      selectedPlace:
          clearSelectedPlace ? null : (selectedPlace ?? this.selectedPlace),
      costPlacePickerFilter:
          costPlacePickerFilter ?? this.costPlacePickerFilter,
      selectedWorker:
          clearSelectedWorker ? null : (selectedWorker ?? this.selectedWorker),
      selectedWorkers: clearSelectedWorkers
          ? const []
          : (selectedWorkers ?? this.selectedWorkers),
      placeRecentWorkers: clearPlaceRecentWorkers
          ? const []
          : (placeRecentWorkers ?? this.placeRecentWorkers),
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      processTasksOnSelectDay:
          processTasksOnSelectDay ?? this.processTasksOnSelectDay,
      processTasksLoading: processTasksLoading ?? this.processTasksLoading,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

final addCostProvider =
    NotifierProvider<AddCostViewModel, AddCostState>(AddCostViewModel.new);

class AddCostViewModel extends Notifier<AddCostState> {
  late final _humanUseCase = ref.read(humanUseCaseProvider);
  late final _materialCostUseCase = ref.read(materialCostUseCaseProvider);
  late final _workCostUseCase = ref.read(workCostUseCaseProvider);

  final TextEditingController hNameController = TextEditingController();
  final TextEditingController hNumController = TextEditingController();
  final TextEditingController hMemoController = TextEditingController();
  final TextEditingController hDailyWageController = TextEditingController();
  final TextEditingController mNameController = TextEditingController();
  final FocusNode mNameFocus = FocusNode();
  final TextEditingController mPriceController = TextEditingController();
  final FocusNode mPriceFocus = FocusNode();
  @override
  AddCostState build() {
    ref.onDispose(() {
      hNameController.dispose();
      hNumController.dispose();
      hMemoController.dispose();
      hDailyWageController.dispose();
      mNameController.dispose();
      mNameFocus.dispose();
      mPriceController.dispose();
      mPriceFocus.dispose();
    });
    return AddCostState.initial();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _dateStringMatchesKey(String s, String key) {
    if (s.isEmpty) return false;
    if (s.length >= 10) return s.substring(0, 10) == key;
    return s == key;
  }

  /// 금액 추가 화면 현장 목록 — 전체 / 진행중 / 완료. 필터와 맞지 않는 선택은 초기화.
  void setCostPlacePickerFilter(CostPlacePickerFilter filter) {
    final sp = state.selectedPlace;
    var dropSelection = false;
    if (sp != null) {
      switch (filter) {
        case CostPlacePickerFilter.all:
          break;
        case CostPlacePickerFilter.inProgress:
          dropSelection = sp.pcomplete != 0;
          break;
        case CostPlacePickerFilter.completed:
          dropSelection = sp.pcomplete != 1;
          break;
      }
    }
    if (dropSelection) {
      state = state.copyWith(
        costPlacePickerFilter: filter,
        clearSelectedPlace: true,
        materialCostList: const [],
        workCostList: const [],
        clearPlaceRecentWorkers: true,
        clearSelectedWorkers: true,
        clearSelectedWorker: true,
      );
      return;
    }
    state = state.copyWith(costPlacePickerFilter: filter);
  }

  /// 현장 선택 화면으로 되돌릴 때(뒤로가기·헤더 버튼).
  void clearSelectedPlace() {
    state = state.copyWith(
      clearSelectedPlace: true,
      clearPlaceRecentWorkers: true,
      workCostList: const [],
      materialCostList: const [],
      clearSelectedWorkers: true,
      clearSelectedWorker: true,
      processTasksOnSelectDay: const [],
      processTasksLoading: false,
    );
  }

  void clearSelectedWorker() {
    state = state.copyWith(clearSelectedWorker: true);
  }

  void clearSelectedWorkers() {
    state =
        state.copyWith(clearSelectedWorkers: true, clearSelectedWorker: true);
  }

  void placeChangeAction(BuildContext context, PlaceModel value) {
    state = state.copyWith(
      selectedPlace: value,
      materialCostList: const [],
      workCostList: const [],
      clearSelectedWorkers: true,
      clearSelectedWorker: true,
    );
    try {
      FocusScope.of(context).unfocus();
    } catch (_) {}
    Future<void>.microtask(() async {
      await refreshPlaceRecentWorkers();
      await refreshProcessTasksOnSelectedDay();
    });
  }

  void workerChangeAction(HumanModel value) {
    state = state.copyWith(selectedWorker: value);
  }

  /// 선택 현장·날짜의 공정표에서 해당 일 공정 이름을 불러옵니다.
  Future<void> refreshProcessTasksOnSelectedDay() async {
    final place = state.selectedPlace;
    if (place == null || place.pid == null) {
      state = state.copyWith(
        processTasksOnSelectDay: const [],
        processTasksLoading: false,
      );
      return;
    }
    state = state.copyWith(processTasksLoading: true);
    final pid = place.pid!;
    try {
      final repo = ref.read(processScheduleRepositoryProvider);
      final start =
          PlaceProcessScheduleNotifier.gridStartFromPlacePstart(place.pstart);
      final dc = PlaceProcessScheduleNotifier.defaultDayCountFromPlacePeriod(
        place.pstart,
        place.pend,
      );
      final raw = await repo.fetchForPlace(
        placeId: pid,
        gridStartFallback: start,
        dayCount: dc,
      );
      final aligned = ProcessScheduleEditor.remapToNewGrid(raw, start, dc);
      final names = processTaskNamesForPlaceDay(
        schedule: aligned,
        day: state.selectDay,
      );
      state = state.copyWith(
        processTasksOnSelectDay: names,
        processTasksLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        processTasksOnSelectDay: const [],
        processTasksLoading: false,
      );
    }
  }

  /// 드롭다운 선택이 바뀔 때마다, 오늘·현재 현장의 미저장 인건비 행을 통째로 맞춘다.
  Future<void> workersChangeAction(List<HumanModel> values) async {
    final pid = state.selectedPlace?.pid;
    if (pid == null) return;
    final dayKey = _dateKey(state.selectDay);

    final list = List<WorkCostModel>.from(state.workCostList);
    final rest = list.where((w) {
      final sameDay = _dateStringMatchesKey(w.wdate, dayKey);
      return !(w.wpid == pid && sameDay && w.whid != null);
    }).toList();

    final newRows = <WorkCostModel>[];
    // 드롭다운 목록 자체는 중복 선택이 없어야 하지만, 안전하게 hid 기준으로 한번 더 정규화한다.
    final byHid = <int, HumanModel>{};
    for (final w in values) {
      final hid = w.hid;
      if (hid == null) continue;
      byHid[hid] = w;
    }
    for (final w in byHid.values) {
      newRows.add(_pendingWorkCostForHuman(w));
    }

    state = state.copyWith(
      workCostList: [...rest, ...newRows],
      selectedWorkers: byHid.values.toList(),
      selectedWorker: byHid.isEmpty ? null : byHid.values.last,
      clearSelectedWorker: byHid.isEmpty,
    );
  }

  Future<void> mergePendingFromPlaceWorkforceRegister({
    required PlaceModel place,
    required DateTime workDate,
    required List<({HumanModel human, int wprice, String wrole})> items,
  }) async {
    final pid = place.pid;
    if (pid == null || items.isEmpty) return;
    final dayKey = _dateKey(workDate);
    final dateStr = formatDateTimeToIsoDate(_dateOnly(workDate));
    final list = List<WorkCostModel>.from(state.workCostList);

    for (final it in items) {
      final h = it.human;
      if (h.hid == null) continue;
      try {
        await _humanUseCase.rememberPlaceWorker(pid, h.hid!);
      } catch (_) {}
      final idx = list.indexWhere(
        (w) =>
            w.wpid == pid &&
            w.whid == h.hid &&
            _dateStringMatchesKey(w.wdate, dayKey),
      );
      final row = WorkCostModel(
        wcomplete: 0,
        wdate: dateStr,
        hname: h.hname,
        wprice: it.wprice,
        wpid: pid,
        whid: h.hid,
        pname: place.pname,
        wrole: it.wrole,
      );
      if (idx >= 0) {
        final old = list[idx];
        list[idx] = row.copyWith(wid: old.wid);
      } else {
        list.add(row);
      }
    }

    state = state.copyWith(
      workCostList: list,
      selectDay: _dateOnly(workDate),
      selectedPlace: place,
    );
    await _rebuildSelectedWorkersFromGrid();
    await refreshPlaceRecentWorkers();
  }

  WorkCostModel _pendingWorkCostForHuman(HumanModel w) {
    return WorkCostModel(
      wcomplete: 0,
      wdate: _dateOnly(state.selectDay).toString(),
      hname: w.hname,
      wprice: w.hdailyWage,
      wpid: state.selectedPlace!.pid!,
      whid: w.hid,
      pname: state.selectedPlace!.pname,
      wrole: defaultWorkRoleForHuman(w),
    );
  }

  Future<void> _rebuildSelectedWorkersFromGrid() async {
    final pid = state.selectedPlace?.pid;
    if (pid == null) {
      state =
          state.copyWith(clearSelectedWorkers: true, clearSelectedWorker: true);
      return;
    }
    final dayKey = _dateKey(state.selectDay);
    final orderedHids = <int>[];
    final seen = <int>{};
    for (final w in state.workCostList) {
      final sameDay = _dateStringMatchesKey(w.wdate, dayKey);
      if (w.wpid == pid && sameDay && w.whid != null) {
        final id = w.whid!;
        if (seen.add(id)) orderedHids.add(id);
      }
    }
    final all = await _humanUseCase.getAllWorkers();
    final byHid = {
      for (final h in all)
        if (h.hid != null) h.hid!: h
    };
    final workers = <HumanModel>[];
    for (final id in orderedHids) {
      final h = byHid[id];
      if (h != null) workers.add(h);
    }
    state = state.copyWith(
      selectedWorkers: workers,
      selectedWorker: workers.isEmpty ? null : workers.last,
      clearSelectedWorker: workers.isEmpty,
    );
  }

  Future<void> refreshPlaceRecentWorkers() async {
    final pid = state.selectedPlace?.pid;
    if (pid == null) {
      state = state.copyWith(clearPlaceRecentWorkers: true);
      return;
    }
    final hids = await _humanUseCase.getPlaceWorkerRecentHids(pid);
    final all = await _humanUseCase.getAllWorkers();
    final byHid = {
      for (final h in all)
        if (h.hid != null) h.hid!: h
    };
    final list = <HumanModel>[];
    for (final id in hids) {
      final h = byHid[id];
      if (h != null) list.add(h);
    }
    state = state.copyWith(placeRecentWorkers: list);
  }

  Future<void> deletePlaceRecentWorker(int hid) async {
    final pid = state.selectedPlace?.pid;
    if (pid == null) return;
    await _humanUseCase.deletePlaceWorkerRecent(pid, hid);
    await refreshPlaceRecentWorkers();
  }

  Future<void> tapPlaceRecentWorker(BuildContext context, HumanModel h) async {
    final messenger = ScaffoldMessenger.of(context);
    final pid = state.selectedPlace?.pid;
    if (pid == null || h.hid == null) return;
    final dayKey = _dateKey(state.selectDay);
    final dup = state.workCostList.any(
      (w) =>
          w.wpid == pid &&
          _dateStringMatchesKey(w.wdate, dayKey) &&
          w.whid == h.hid,
    );
    if (dup) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('이미 오늘 목록에 추가된 인원입니다.')),
      );
      return;
    }
    state = state.copyWith(
      workCostList: [...state.workCostList, _pendingWorkCostForHuman(h)],
    );
    await _rebuildSelectedWorkersFromGrid();
    if (!context.mounted) return;
    FocusScope.of(context).unfocus();
  }

  void categoryChangeAction(String value) {
    state = state.copyWith(selectedCategory: value);
    mNameController.text = value;
    mNameController.selection = TextSelection.fromPosition(
      TextPosition(offset: mNameController.text.length),
    );
    mNameFocus.requestFocus();
  }

  void clearDialogText() {
    state = state.copyWith(alertText: '');
    hMemoController.clear();
    hNameController.clear();
    hNumController.clear();
    hDailyWageController.clear();
  }

  void clearWorkerDialogAlert() {
    state = state.copyWith(alertText: '');
  }

  Future<bool> insertWorker({String hdefaultRole = ''}) async {
    final hName = hNameController.text.trim();
    final hNum = hNumController.text.trim();
    final hMemo =
        hMemoController.text.isEmpty ? null : hMemoController.text.trim();
    final wageText =
        hDailyWageController.text.trim().replaceAll(RegExp(r'[,원\s]'), '');
    final hdailyWage = int.tryParse(wageText) ?? 0;
    final workerInfoList = await _humanUseCase.getAllWorkers();

    if (hName.isEmpty) {
      state = state.copyWith(alertText: '이름을 입력해주세요.');
      return false;
    }
    if (workerInfoList.any((e) => e.hname == hName)) {
      state = state.copyWith(alertText: '중복된 이름입니다.');
      return false;
    }

    final worker = HumanModel(
      hname: hName,
      hnumber: hNum,
      hmemo: hMemo,
      hdailyWage: hdailyWage,
      hdefaultRole: hdefaultRole.trim(),
      hstar: 0,
      hdelete: 0,
    );
    final added = await _humanUseCase.addWorker(worker);

    state = state.copyWith(selectedWorker: added);

    final c = rootProviderContainer;
    if (c != null) {
      await c.read(workerProvider.notifier).fetchWorkerInfo();
    }
    hNameController.clear();
    hNumController.clear();
    hMemoController.clear();
    hDailyWageController.clear();
    state = state.copyWith(alertText: '');
    return true;
  }

  Future<void> changeDateTime(BuildContext context) async {
    final place = state.selectedPlace;
    if (place == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현장을 먼저 선택해주세요.')),
      );
      return;
    }

    (DateTime?, DateTime?) parsedRange() {
      try {
        if (place.pstart.isEmpty) return (null, null);
        final s = DateTime.parse(place.pstart);
        final dStart = DateTime(s.year, s.month, s.day);
        if (place.pend == '0' || place.pend.isEmpty) {
          return (dStart, dStart);
        }
        final e = DateTime.parse(place.pend);
        final dEnd = DateTime(e.year, e.month, e.day);
        return (dStart, dEnd);
      } catch (_) {
        return (null, null);
      }
    }

    final (rangeStart, rangeEnd) = parsedRange();

    final picked = await showDialog<DateTime?>(
      context: context,
      builder: (_) => AddCostDatePickerDialog(
        place: place,
        initialRangeStart: rangeStart,
        initialRangeEnd: rangeEnd,
        initialSelectedDay: DateTime.now(),
      ),
    );
    if (picked == null) return;
    final nextDay = _dateOnly(picked);
    final prevKey = _dateKey(state.selectDay);
    final nextKey = _dateKey(nextDay);
    // 날짜가 바뀌면 "임시 추가 목록"은 해당 날짜 기준으로 새로 시작한다.
    // (기존 구조는 1개의 날짜만을 대상으로 목록을 쌓는 UX이므로, 날짜 변경 시 이전 날짜 항목이 남아있으면
    // 저장 날짜/중복체크가 틀어지는 문제가 발생한다.)
    state = state.copyWith(
      selectDay: nextDay,
      materialCostList: prevKey == nextKey ? state.materialCostList : const [],
      workCostList: prevKey == nextKey ? state.workCostList : const [],
      clearSelectedWorkers: prevKey == nextKey,
      clearSelectedWorker: prevKey != nextKey,
    );
    await _rebuildSelectedWorkersFromGrid();
    await refreshProcessTasksOnSelectedDay();
  }

  void addMaterialCostList(BuildContext context) {
    var mpriceString = mPriceController.text.trim();
    mpriceString = mpriceString.replaceAll(RegExp(r'[,원]'), '');
    final mprice = int.tryParse(mpriceString);
    final mname = mNameController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (state.selectedPlace == null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('현장을 선택해주세요.')),
      );
      return;
    }
    if (state.selectedCategory == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요.')),
      );
      return;
    }
    if (mname.isEmpty || mprice == null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
      return;
    }

    final model = MaterialCostModel(
      mcategory: state.selectedCategory!,
      pname: state.selectedPlace!.pname,
      mpid: state.selectedPlace!.pid,
      mname: mname,
      mdate: _dateOnly(state.selectDay).toString(),
      mprice: mprice,
    );
    state = state.copyWith(
      materialCostList: [...state.materialCostList, model],
    );
    mNameController.clear();
    mPriceController.clear();
    FocusScope.of(context).unfocus();
  }

  void deleteMaterialList(int index) {
    final next = List<MaterialCostModel>.from(state.materialCostList)
      ..removeAt(index);
    state = state.copyWith(materialCostList: next);
  }

  Future<void> deleteWorkList(int index) async {
    final next = List<WorkCostModel>.from(state.workCostList)..removeAt(index);
    state = state.copyWith(workCostList: next);
    await _rebuildSelectedWorkersFromGrid();
  }

  void updateWorkCostAt(int index, WorkCostModel next) {
    if (index < 0 || index >= state.workCostList.length) return;
    final list = List<WorkCostModel>.from(state.workCostList);
    list[index] = next;
    state = state.copyWith(workCostList: list);
  }

  Future<void> insertCostLists(BuildContext context) async {
    // 이미 저장 중이면 중복 실행 방지
    if (state.isSaving) return;
    
    // 저장 시작
    state = state.copyWith(isSaving: true);
    
    try {
      var isMaterialCostSuccess = false;
      var isWorkCostSuccess = false;
      final selectedPid = state.selectedPlace?.pid;
      final dateKey = _dateKey(state.selectDay);

    final materialToSave = state.materialCostList
        .where((m) => m.mdate.length >= 10
            ? m.mdate.substring(0, 10) == dateKey
            : m.mdate == dateKey)
        .toList();
    final workToSave = state.workCostList
        .where((w) =>
            w.wpid == selectedPid &&
            (w.wdate.length >= 10
                ? w.wdate.substring(0, 10) == dateKey
                : w.wdate == dateKey))
        .toList();

    // 같은 날짜/현장에 같은 인원이 2번 들어가면 "의도치 않은 중복 저장"이 발생한다.
    // (사용자가 정말로 2번 저장하고 싶다면 저장을 2번 누르는 방식으로 남기고,
    //  한 번의 저장 액션에서는 1인 1건만 허용)
    final hidCounts = <int, int>{};
    for (final w in workToSave) {
      final hid = w.whid;
      if (hid == null) continue;
      hidCounts[hid] = (hidCounts[hid] ?? 0) + 1;
    }
    final dupHids =
        hidCounts.entries.where((e) => e.value > 1).map((e) => e.key).toList();
    if (dupHids.isNotEmpty) {
      final names = workToSave
          .where((e) => e.whid != null && dupHids.contains(e.whid))
          .map((e) => e.hname ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              names.isEmpty
                  ? '같은 날짜에 같은 인원이 중복으로 포함되어 있습니다. 목록을 정리한 뒤 저장해주세요.'
                  : '같은 날짜에 같은 인원이 중복으로 포함되어 있습니다. (${names.join(', ')})\n목록을 정리한 뒤 저장해주세요.',
            ),
          ),
        );
      }
      return;
    }

    if (materialToSave.isNotEmpty) {
      isMaterialCostSuccess =
          await _materialCostUseCase.addMaterialCosts(materialToSave);
    }

    if (workToSave.isNotEmpty && selectedPid != null) {
      final savedHids = (await _workCostUseCase.getSavedWorkDayHidsForPlaceDate(
        pid: selectedPid,
        dateKey: dateKey,
      ))
          .toSet();
      final pendingHids =
          workToSave.where((e) => e.whid != null).map((e) => e.whid!).toSet();
      final dup = pendingHids.intersection(savedHids);
      if (dup.isNotEmpty) {
        final dupNames = workToSave
            .where((e) => e.whid != null && dup.contains(e.whid))
            .map((e) => e.hname ?? '')
            .where((e) => e.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final msg = dupNames.isEmpty
            ? '이미 $dateKey에 저장된 인원이 포함되어 있습니다.\n정말로 또 저장할까요?'
            : '이미 $dateKey에 저장된 인원이 포함되어 있습니다.\n'
                '(${dupNames.join(', ')})\n\n정말로 또 저장할까요?';
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('중복 저장 확인'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('저장', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }
    }

    if (workToSave.isNotEmpty) {
      try {
        isWorkCostSuccess = await _workCostUseCase.addWorkCosts(workToSave);
      } catch (e) {
        if (!context.mounted) return;
        if (isWorkerTroublePairConflictError(e)) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('트러블 페어'),
              content: const Text(
                '선택한 인력에 트러블 페어로 묶인 조합이 포함되어 있어, 기본적으로는 같은 날 함께 투입할 수 없습니다.\n\n'
                '그래도 투입을 진행할까요?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('투입 진행'),
                ),
              ],
            ),
          );
          if (proceed == true && context.mounted) {
            try {
              isWorkCostSuccess = await _workCostUseCase.addWorkCosts(
                workToSave,
                acknowledgeTroublePair: true,
              );
            } catch (e2) {
              if (!context.mounted) return;
              final msg = snackMessageForHttpFailure(e2);
              if (msg != null && msg.isNotEmpty) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg)),
                );
              }
              return;
            }
          } else {
            return;
          }
        } else {
          final msg = snackMessageForHttpFailure(e);
          if (msg != null && msg.isNotEmpty) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          }
          return;
        }
      }
    }

    if (!isMaterialCostSuccess && !isWorkCostSuccess) {
      return;
    }

    // "이 현장에서 일했던 인원"은 실제로 인건비가 저장된 경우에만 누적한다.
    if (isWorkCostSuccess) {
      for (final w in workToSave) {
        final pid = w.wpid;
        final hid = w.whid;
        if (hid == null) continue;
        await _humanUseCase.rememberPlaceWorker(pid, hid);
      }
      await refreshPlaceRecentWorkers();
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    await FetchData.fetchAllData();
    if (!context.mounted) return;
    FocusScope.of(context).unfocus();

    String message;
    if (isMaterialCostSuccess && isWorkCostSuccess) {
      message = '인건비 및 자재비가 저장되었습니다.';
    } else if (isMaterialCostSuccess) {
      message = '자재비가 저장되었습니다.';
    } else {
      message = '인건비가 저장되었습니다.';
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => saveDialog(text: message),
    );
    clearAllLists();
    } finally {
      // 저장 완료 (성공/실패 관계없이)
      state = state.copyWith(isSaving: false);
    }
  }

  void clearAllLists() {
    state = state.copyWith(
      materialCostList: const [],
      workCostList: const [],
      clearSelectedWorkers: true,
      clearSelectedWorker: true,
    );
  }

  void showClearDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => deleteDialog(
        content: '모두 비우시겠습니까?',
        onPressed: () {
          clearAllLists();
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}
