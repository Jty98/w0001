import 'dart:io';

import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/domain/use_case/human_use_case.dart';
import 'package:w0001/domain/use_case/workcost_use_case.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show humanUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show workCostUseCaseProvider;
import 'package:w0001/util/fetch_data.dart' show FetchData;
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';

/// value: check 상태 / price / hid
class CheckboxData {
  CheckboxData({
    required this.isSelected,
    required this.price,
    required this.hid,
  });

  bool isSelected;
  final int price;
  final int hid;

  CheckboxData copyWith({bool? isSelected}) {
    return CheckboxData(
      isSelected: isSelected ?? this.isSelected,
      price: price,
      hid: hid,
    );
  }
}

class WorkCostData {
  WorkCostData({
    required this.hname,
    required this.hnumber,
    required this.hid,
    required this.pcomplete,
    required this.hstar,
    required this.totalPrice,
    required this.incompletePrice,
    required this.filteredList,
    this.hdailyWage = 0,
    this.hdefaultRole = '',
    this.human,
  });

  final String hname;
  final String hnumber;
  final int hid;
  final int hstar;
  final int totalPrice;
  final int pcomplete;
  final int incompletePrice;
  final List<TotalWorkCostModel> filteredList;

  /// `workerInfoList`에서 병합한 일당(사람 관리와 동일 출처).
  final int hdailyWage;

  /// `workerInfoList`에서 병합한 기본 역할.
  final String hdefaultRole;

  /// 스킬 표시용 — [workerInfoList]와 매칭된 인력.
  final HumanModel? human;
}

class WorkerState {
  const WorkerState({
    required this.dateTimeRange,
    required this.selectDay,
    required this.toggleState,
    required this.workerInfoList,
    required this.filteredWorkerList,
    required this.isEditing,
    required this.humanFormWorkRole,
    required this.taxState,
    required this.dayState,
    required this.completeState,
    required this.selectedIndex,
    required this.totalWorkCostList,
    required this.filteredTotalWorkCostList,
    required this.checkboxStates,
    required this.expandedWorkerKeys,
  });

  final DateTimeRange dateTimeRange;
  final DateTime selectDay;
  final List<bool> toggleState;
  final List<HumanModel> workerInfoList;
  final List<HumanModel> filteredWorkerList;
  final bool isEditing;

  /// 사람 관리 폼: 역할 칩 선택(`직접입력` 포함). null이면 아직 선택 없음.
  final String? humanFormWorkRole;
  final TaxState taxState;
  final DayTpye dayState;
  final CompleteState completeState;
  final int selectedIndex;
  final List<TotalWorkCostModel> totalWorkCostList;
  final List<TotalWorkCostModel> filteredTotalWorkCostList;
  final Map<int, CheckboxData> checkboxStates;

  /// 전체·미지급 필터별 펼침 상태(`getUniqueHuman` 키).
  final Map<CompleteState, Set<String>> expandedWorkerKeys;

  bool get isTaxApply => taxState == TaxState.taxOn;
  bool get isIncomplete => completeState == CompleteState.incomplete;

  List<int> get selectedWidList => checkboxStates.entries
      .where((e) => e.value.isSelected)
      .map((e) => e.key)
      .toList();

  int get selectedCount => selectedWidList.length;

  factory WorkerState.initial() {
    final now = DateTime.now();
    return WorkerState(
      dateTimeRange: getMonthDateRange(now),
      selectDay: now,
      toggleState: const [false, false, true],
      workerInfoList: const [],
      filteredWorkerList: const [],
      isEditing: false,
      humanFormWorkRole: null,
      taxState: TaxState.taxOff,
      dayState: DayTpye.month,
      completeState: CompleteState.whole,
      selectedIndex: -1,
      totalWorkCostList: const [],
      filteredTotalWorkCostList: const [],
      checkboxStates: const {},
      expandedWorkerKeys: {
        CompleteState.whole: {},
        CompleteState.incomplete: {},
      },
    );
  }

  WorkerState copyWith({
    DateTimeRange? dateTimeRange,
    DateTime? selectDay,
    List<bool>? toggleState,
    List<HumanModel>? workerInfoList,
    List<HumanModel>? filteredWorkerList,
    bool? isEditing,
    String? humanFormWorkRole,
    bool clearHumanFormWorkRole = false,
    TaxState? taxState,
    DayTpye? dayState,
    CompleteState? completeState,
    int? selectedIndex,
    List<TotalWorkCostModel>? totalWorkCostList,
    List<TotalWorkCostModel>? filteredTotalWorkCostList,
    Map<int, CheckboxData>? checkboxStates,
    Map<CompleteState, Set<String>>? expandedWorkerKeys,
  }) {
    return WorkerState(
      dateTimeRange: dateTimeRange ?? this.dateTimeRange,
      selectDay: selectDay ?? this.selectDay,
      toggleState: toggleState ?? this.toggleState,
      workerInfoList: workerInfoList ?? this.workerInfoList,
      filteredWorkerList: filteredWorkerList ?? this.filteredWorkerList,
      isEditing: isEditing ?? this.isEditing,
      humanFormWorkRole: clearHumanFormWorkRole
          ? null
          : (humanFormWorkRole ?? this.humanFormWorkRole),
      taxState: taxState ?? this.taxState,
      dayState: dayState ?? this.dayState,
      completeState: completeState ?? this.completeState,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      totalWorkCostList: totalWorkCostList ?? this.totalWorkCostList,
      filteredTotalWorkCostList:
          filteredTotalWorkCostList ?? this.filteredTotalWorkCostList,
      checkboxStates: checkboxStates ?? this.checkboxStates,
      expandedWorkerKeys: expandedWorkerKeys != null
          ? {
              for (final s in CompleteState.values)
                s: Set<String>.from(expandedWorkerKeys[s] ?? {}),
            }
          : {
              for (final s in CompleteState.values)
                s: Set<String>.from(this.expandedWorkerKeys[s] ?? {}),
            },
    );
  }
}

final workerProvider =
    NotifierProvider<WorkerViewModel, WorkerState>(WorkerViewModel.new);

class WorkerViewModel extends Notifier<WorkerState> {
  late final HumanUseCase _humanUseCase = ref.read(humanUseCaseProvider);
  late final WorkCostUseCase _workCostUseCase =
      ref.read(workCostUseCaseProvider);

  late final TextEditingController workerNameController =
      TextEditingController();
  late final TextEditingController workerNumController =
      TextEditingController();
  late final TextEditingController workerDailyWageController =
      TextEditingController(text: formatIntegerWithComma(0));
  late final TextEditingController workerMemoController =
      TextEditingController();
  late final TextEditingController searchWorkerDetailTextContoller =
      TextEditingController();
  late final TextEditingController searchWorkerTextContoller =
      TextEditingController();
  late final TextEditingController workerRoleCustomController =
      TextEditingController();

  final List<BuildContext> slidableContexts = [];
  final Map<String, ExpansionTileController> expansionTileControllerMap = {};

  bool _initialized = false;

  @override
  WorkerState build() {
    ref.onDispose(() {
      workerNameController.dispose();
      workerNumController.dispose();
      workerDailyWageController.dispose();
      workerMemoController.dispose();
      searchWorkerDetailTextContoller.dispose();
      searchWorkerTextContoller.dispose();
      workerRoleCustomController.dispose();
    });
    if (!_initialized) {
      _initialized = true;
      Future(() async {
        await fetchWorkCost();
        await fetchWorkerInfo();
      });
    }
    return WorkerState.initial();
  }

  /// [FetchData.fetchAllData] 등에서 호출
  Future<void> refreshFromGlobalFetch() async {
    state = state.copyWith(checkboxStates: {});
    await fetchWorkCost();
    await fetchWorkerInfo();
  }

  int get totalCost {
    var price = 0;
    for (final e in state.filteredTotalWorkCostList) {
      price += e.price;
    }
    return price;
  }

  int get totalIncompleteCost {
    var price = 0;
    for (final e in state.filteredTotalWorkCostList) {
      if (e.wcomplete == 0) price += e.price;
    }
    return price;
  }

  int incompleteCostByHid(int hid) {
    var total = 0;
    for (final e in state.checkboxStates.entries) {
      if (e.value.hid == hid && e.value.isSelected) {
        total += e.value.price;
      }
    }
    return total;
  }

  int get selectedIncompleteCost {
    var total = 0;
    for (final e in state.checkboxStates.values) {
      if (e.isSelected) total += e.price;
    }
    return total;
  }

  void toggleCheckboxState(int itemId) {
    final map = Map<int, CheckboxData>.from(state.checkboxStates);
    final cur = map[itemId];
    if (cur != null) {
      map[itemId] = cur.copyWith(isSelected: !cur.isSelected);
      state = state.copyWith(checkboxStates: map);
    }
  }

  Future<void> fetchWorkCost() async {
    final r = state.dateTimeRange;
    final list = await _workCostUseCase.getWorkCostsByDateRange(
      r.start,
      r.end,
    );
    // 각 항목별 체크박스 상태를 초기화/보존
    final newCheckbox = <int, CheckboxData>{};
    for (final e in list) {
      final existing = state.checkboxStates[e.wid];
      newCheckbox[e.wid] = existing ??
          CheckboxData(isSelected: false, price: e.price, hid: e.hid);
    }
    state = state.copyWith(
      totalWorkCostList: list,
      filteredTotalWorkCostList: _applySearchFilter(list),
      checkboxStates: newCheckbox,
    );
  }

  List<TotalWorkCostModel> _applySearchFilter(
    List<TotalWorkCostModel> list,
  ) {
    final q = searchWorkerTextContoller.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((e) => e.hname.toLowerCase().contains(q)).toList();
  }

  /// 검색·기간 필터가 적용된 목록에서 전체/미지급 행만 고른다.
  List<TotalWorkCostModel> workCostRowsFor(CompleteState filter) {
    final base = state.filteredTotalWorkCostList;
    if (filter == CompleteState.incomplete) {
      return base.where((e) => e.wcomplete == 0).toList();
    }
    return base;
  }

  List<String> getUniqueHumanFor(CompleteState filter) {
    return workCostRowsFor(filter)
        .map((m) => 'name:${m.hname}#number:${m.hnumber}')
        .toSet()
        .toList();
  }

  List<String> getUniqueHuman() => getUniqueHumanFor(state.completeState);

  Future<DateTimeRange?> _pickRangeWithScrollableCalendar(
    BuildContext context,
  ) async {
    // 다이얼로그는 항상 초기화된 상태(미선택)로 시작.
    DateTime? rangeStart;
    DateTime? rangeEnd;
    return showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) {
        final screenH = MediaQuery.sizeOf(ctx).height;
        final maxHeight = (screenH * 0.66).clamp(420.0, 560.0).toDouble();
        final calHeight = (screenH * 0.36).clamp(250.0, 320.0).toDouble();
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '기간 선택',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ScrollableCalendarWidget(
                        height: calHeight,
                        initialRangeStart: rangeStart,
                        initialRangeEnd: rangeEnd,
                        showViewModeToggle: false,
                        showRangeSummarySection: false,
                        disableDateSelectionHighlight: true,
                        onRangeChanged: (s, e) {
                          rangeStart = s;
                          rangeEnd = e;
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () {
                              final s = rangeStart;
                              if (s == null) {
                                Navigator.of(ctx).pop();
                                return;
                              }
                              final e = rangeEnd ?? s;
                              final normalized = s.isBefore(e)
                                  ? DateTimeRange(start: s, end: e)
                                  : DateTimeRange(start: e, end: s);
                              Navigator.of(ctx).pop(normalized);
                            },
                            child: const Text('확인'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> showDateTimeRangePicker(BuildContext context) async {
    final picked = await _pickRangeWithScrollableCalendar(context);
    if (picked != null) {
      state = state.copyWith(dateTimeRange: picked);
      await fetchWorkCost();
    }
  }

  Future<void> updateWComplete(int wcomplete, int id) async {
    await _workCostUseCase.toggleWorkCostCompletionStatus(wcomplete, id);
    await FetchData.fetchAllData();
  }

  Future<void> updateWorkCostPrice(int wid, int newPrice) async {
    await _workCostUseCase.updateWorkCostPrice(wid, newPrice);
    await FetchData.fetchAllData();
  }

  Future<void> deleteWorkCost(int wid) async {
    await _workCostUseCase.deleteWorkCost(wid);
    await FetchData.fetchAllData();
  }

  Future<int?> placeWorkDayPwdidFor(TotalWorkCostModel item) {
    final dateKey =
        item.date.length >= 10 ? item.date.substring(0, 10) : item.date;
    return _workCostUseCase.findPlaceWorkDayPwdid(
      pid: item.wpid,
      hid: item.hid,
      dateKey: dateKey,
    );
  }

  Future<void> deleteWorkCostLinked({
    required int wid,
    int? pwdid,
  }) async {
    await _workCostUseCase.deleteWorkCostLinked(wid: wid, pwdid: pwdid);
    await FetchData.fetchAllData();
  }

  Future<void> changeDateTime(BuildContext context) async {
    final picked = await showDatePickerDialog(
      context: context,
      minDate: DateTime(2000),
      maxDate: DateTime(2099),
    );
    if (picked != null) {
      state = state.copyWith(selectDay: picked);
    }
  }

  void searchWoker(String value) {
    final q = value.toLowerCase();
    state = state.copyWith(
      filteredTotalWorkCostList: q.isEmpty
          ? state.totalWorkCostList
          : state.totalWorkCostList
              .where((e) => e.hname.toLowerCase().contains(q))
              .toList(),
    );
  }

  void resetSearchText() {
    searchWorkerTextContoller.clear();
    state = state.copyWith(
      filteredTotalWorkCostList: state.totalWorkCostList,
    );
  }

  Future<void> selectToggleButton(int index, BuildContext context) async {
    List<bool> nextToggle;
    DateTimeRange nextRange = state.dateTimeRange;

    DayTpye nextDayState = state.dayState;
    if (index == 0) {
      nextToggle = [true, false, false];
      nextDayState = DayTpye.range;
      final picked = await _pickRangeWithScrollableCalendar(context);
      nextRange = picked ?? nextRange;
    } else if (index == 1) {
      nextToggle = [false, true, false];
      nextDayState = DayTpye.whole;
      nextRange = DateTimeRange(
        start: DateTime(2000),
        end: DateTime(2099, 12, 31),
      );
    } else {
      nextToggle = [false, false, true];
      nextDayState = DayTpye.month;
      nextRange = getMonthDateRange(DateTime.now());
    }

    state = state.copyWith(
      toggleState: nextToggle,
      dateTimeRange: nextRange,
      dayState: nextDayState,
      checkboxStates: {},
    );
    await fetchWorkCost();
  }

  void taxStateValueChanged(TaxState? value) {
    if (value != null) {
      state = state.copyWith(taxState: value);
    }
  }

  void completeStateValueChanged(CompleteState? value) {
    if (value != null) {
      state = state.copyWith(completeState: value);
    }
    closeAllSliders();
  }

  Future<void> fetchWorkerInfo() async {
    final list = await _humanUseCase.getAllWorkers();
    state = state.copyWith(
      workerInfoList: list,
      filteredWorkerList: list,
    );
  }

  /// 인력 관리 화면 진입 시 검색 초기화 + 목록 갱신.
  Future<void> prepareHumanManagementScreen() async {
    searchWorkerDetailTextContoller.clear();
    await fetchWorkerInfo();
  }

  void searchWokerInfo(String value) {
    final q = value.toLowerCase();
    state = state.copyWith(
      filteredWorkerList: state.workerInfoList
          .where((h) => h.hname.toLowerCase().contains(q))
          .toList(),
    );
  }

  void humanFormSelectWorkRole(String role) {
    state = state.copyWith(humanFormWorkRole: role);
    if (role != '직접입력') {
      workerRoleCustomController.clear();
    }
  }

  void _clearHumanRoleForm() {
    workerRoleCustomController.clear();
    state = state.copyWith(clearHumanFormWorkRole: true);
  }

  /// 사람 관리 폼 → DB `hdefaultRole` 문자열.
  String humanFormPersistedDefaultRole() {
    final r = state.humanFormWorkRole;
    if (r == null) return '';
    if (r == '직접입력') return workerRoleCustomController.text.trim();
    return r;
  }

  void applyHumanFormRoleFromPersisted(String persisted) {
    final resolved = persisted.trim();
    if (resolved.isEmpty) {
      _clearHumanRoleForm();
      return;
    }
    final fixed = kWorkRolePresets.where((e) => e != '직접입력').toSet();
    if (fixed.contains(resolved)) {
      state = state.copyWith(humanFormWorkRole: resolved);
      workerRoleCustomController.clear();
      return;
    }
    state = state.copyWith(humanFormWorkRole: '직접입력');
    workerRoleCustomController.text = resolved;
  }

  Future<void> insertWorker(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final hname = workerNameController.text.trim();
    final hnumber = workerNumController.text.trim();
    final wageText =
        workerDailyWageController.text.replaceAll(RegExp(r'\D'), '');
    final hdailyWage = int.tryParse(wageText) ?? 0;
    final hmemo = workerMemoController.text.isNotEmpty
        ? workerMemoController.text.trim()
        : null;

    if (hname.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('이름을 입력해 주세요.')),
      );
      return;
    }
    if (state.workerInfoList.any(
      (w) => w.hname.toLowerCase() == hname.toLowerCase(),
    )) {
      messenger.showSnackBar(
        const SnackBar(content: Text('다른 이름으로 등록해 주세요.')),
      );
      return;
    }

    final worker = HumanModel(
      uid: null,
      hname: hname,
      hnumber: hnumber,
      hdailyWage: hdailyWage,
      hdefaultRole: humanFormPersistedDefaultRole(),
      hstar: 0,
      hmemo: hmemo,
      hdelete: 0,
    );
    await _humanUseCase.addWorker(worker);
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => saveDialog(text: '등록되었습니다.'),
      );
    }
    workerNameController.clear();
    workerNumController.clear();
    workerDailyWageController.text = formatIntegerWithComma(0);
    workerMemoController.clear();
    _clearHumanRoleForm();
    await fetchWorkerInfo();
  }

  Future<void> updateWorkCostsToComplete(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => deleteDialog(
        content: '선택 항목을 모두 지급하시겠습니까?',
        onPressed: () async {
          try {
            await _workCostUseCase
                .updateWorkCostsToComplete(state.selectedWidList);
          } catch (_) {
            if (dialogCtx.mounted) {
              await showDialog<void>(
                context: dialogCtx,
                builder: (_) => saveDialog(text: '실패했습니다.'),
              );
            }
            return;
          }
          state = state.copyWith(checkboxStates: {});
          if (dialogCtx.mounted) {
            Navigator.of(dialogCtx).pop();
          }
          await FetchData.fetchAllData();
        },
      ),
    );
  }

  Future<void> modifyWorkerInfo(
    BuildContext context,
    int index,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final hname = workerNameController.text.trim();
    final hnumber = workerNumController.text.trim();
    final wageText =
        workerDailyWageController.text.replaceAll(RegExp(r'\D'), '');
    final hdailyWage = int.tryParse(wageText) ?? 0;
    final hmemo = workerMemoController.text.isNotEmpty
        ? workerMemoController.text.trim()
        : null;

    final tempList = List<HumanModel>.from(state.filteredWorkerList)
      ..removeAt(index);

    if (hname.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('이름을 입력해 주세요.')),
      );
      return;
    }

    if (tempList.any(
      (w) => w.hname.toLowerCase() == hname.toLowerCase(),
    )) {
      messenger.showSnackBar(
        const SnackBar(content: Text('다른 이름으로 등록해 주세요.')),
      );
      return;
    }

    final updated = HumanModel(
      hid: state.filteredWorkerList[index].hid,
      uid: state.filteredWorkerList[index].uid,
      hname: hname,
      hnumber: hnumber,
      hdailyWage: hdailyWage,
      hdefaultRole: humanFormPersistedDefaultRole(),
      hmemo: hmemo,
      hstar: state.filteredWorkerList[index].hstar,
      hdelete: 0,
    );

    await _humanUseCase.updateWorker(updated);
    workerNameController.clear();
    workerNumController.clear();
    workerDailyWageController.text = formatIntegerWithComma(0);
    workerMemoController.clear();
    _clearHumanRoleForm();
    state = state.copyWith(isEditing: false);
    await fetchWorkerInfo();
  }

  void showWorkerInfo(
    int index,
    String workerName,
    String workerNum,
    int workerDailyWage,
    String workerMemo,
    String hdefaultRole,
  ) {
    workerNameController.text = workerName;
    workerNumController.text = workerNum;
    workerDailyWageController.text = formatIntegerWithComma(workerDailyWage);
    workerMemoController.text = workerMemo;
    applyHumanFormRoleFromPersisted(hdefaultRole);
    state = state.copyWith(
      selectedIndex: index,
      isEditing: true,
    );
  }

  Future<void> editButtonAction(BuildContext context) async {
    if (state.isEditing && state.selectedIndex >= 0) {
      await modifyWorkerInfo(context, state.selectedIndex);
    } else {
      await insertWorker(context);
    }
    await FetchData.fetchAllData();
  }

  void refreshAction() {
    workerNameController.clear();
    workerNumController.clear();
    workerDailyWageController.text = formatIntegerWithComma(0);
    workerMemoController.clear();
    searchWorkerDetailTextContoller.clear();
    _clearHumanRoleForm();
    state = state.copyWith(isEditing: false);
    fetchWorkerInfo();
  }

  Future<void> updateWorkerDelete(int index) async {
    final hid = state.filteredWorkerList[index].hid!;
    workerNameController.clear();
    workerNumController.clear();
    workerDailyWageController.text = formatIntegerWithComma(0);
    workerMemoController.clear();
    _clearHumanRoleForm();
    state = state.copyWith(isEditing: false);
    await _humanUseCase.deleteWorker(hid);
    await fetchWorkerInfo();
  }

  Future<void> updateHstarFromWorkerList(int index) async {
    final stared = state.filteredWorkerList[index].hstar == 1 ? false : true;
    final hid = state.filteredWorkerList[index].hid!;
    await _humanUseCase.toggleWorkerStarStatus(hid, stared);
    await fetchWorkerInfo();
  }

  Future<void> updateHstar({required int hid, required int hstar}) async {
    final stared = hstar == 1 ? false : true;
    await _humanUseCase.toggleWorkerStarStatus(hid, stared);
    await fetchWorkCost();
  }

  Future<void> exportAndSendWorkCostToExcel(BuildContext context) async {
    final r = state.dateTimeRange;
    final detailQueryResult =
        await _workCostUseCase.getWorkCostDetailsForCsv(r.start, r.end);
    final totalQueryResult =
        await _workCostUseCase.getWorkCostTotalsForCsv(r.start, r.end);

    if (!context.mounted) return;

    if (detailQueryResult.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추출할 데이터가 없습니다.')),
      );
      return;
    }

    final detailCsvData = <List<dynamic>>[];
    final totalCsvData = <List<dynamic>>[];

    detailCsvData.add(detailQueryResult.first.keys.toList());
    if (totalQueryResult.isNotEmpty) {
      totalCsvData.add(totalQueryResult.first.keys.toList());
    }

    for (final row in detailQueryResult) {
      detailCsvData.add(row.values.toList());
    }
    if (totalQueryResult.isNotEmpty) {
      for (final row in totalQueryResult) {
        totalCsvData.add(row.values.toList());
      }
    }

    final excel = Excel.createExcel();
    final totalSheet = excel['총계'];
    final detailSheet = excel['세부사항'];

    try {
      excel.delete('Sheet1');
    } catch (_) {}

    for (var i = 0; i < detailCsvData.length; i++) {
      final row = detailCsvData[i];
      for (var j = 0; j < row.length; j++) {
        detailSheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i),
          (row[j] is String)
              ? TextCellValue(row[j].toString())
              : IntCellValue(int.tryParse(row[j].toString()) ?? 0),
        );
      }
    }
    for (var i = 0; i < totalCsvData.length; i++) {
      final row = totalCsvData[i];
      for (var j = 0; j < row.length; j++) {
        totalSheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i),
          (row[j] is String)
              ? TextCellValue(row[j].toString())
              : IntCellValue(int.tryParse(row[j].toString()) ?? 0),
        );
      }
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final excelFilePath =
        '${appDocDir.path}/인건비 총계 (${formatDateTimeRangeToString(r, periodType: state.dayState)}).xlsx';

    final bytes = excel.encode();
    final excelFile = File(excelFilePath);
    await excelFile.writeAsBytes(bytes!);

    try {
      final result = await Share.shareXFiles(
        [XFile(excelFile.path)],
        subject: '인건비 총계 (${formatDateTimeRangeToString(r, periodType: state.dayState)})',
      );
      if (result.status == ShareResultStatus.success && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => saveDialog(text: '공유되었습니다.'),
        );
      }
    } catch (_) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => saveDialog(text: '공유에 실패했습니다.\n다시 시도해주세요.'),
        );
      }
    }
  }

  WorkCostData processWorkCostDataFor(
    CompleteState filter,
    String uniqueHuman,
  ) {
    final splitHuman = uniqueHuman.split('#');
    final hname = splitHuman[0].split(':')[1];
    final hnumber = splitHuman[1].split(':')[1];

    HumanModel? humanFromList(int hid) {
      if (hid != 0) {
        for (final h in state.workerInfoList) {
          if (h.hid == hid) return h;
        }
      }
      for (final h in state.workerInfoList) {
        if (h.hname == hname && h.hnumber == hnumber) return h;
      }
      return null;
    }

    final filteredList = workCostRowsFor(filter)
        .where(
          (e) => 'name:${e.hname}#number:${e.hnumber}' == uniqueHuman,
        )
        .toList();

    if (filteredList.isEmpty) {
      final human = humanFromList(0);
      return WorkCostData(
        pcomplete: 1,
        hname: hname,
        hnumber: hnumber,
        hid: 0,
        hstar: 0,
        totalPrice: 0,
        incompletePrice: 0,
        filteredList: [],
        hdailyWage: human?.hdailyWage ?? 0,
        hdefaultRole: human?.hdefaultRole ?? '',
        human: human,
      );
    }

    final hid = filteredList[0].hid;
    final hstar = filteredList[0].hstar;
    final totalPrice = filteredList.fold<int>(0, (s, i) => s + i.price);
    final incompletePrice = filteredList.fold<int>(
      0,
      (s, i) => i.wcomplete == 0 ? s + i.price : s,
    );
    final human = humanFromList(hid);
    return WorkCostData(
      pcomplete: 1,
      hname: hname,
      hnumber: hnumber,
      hid: hid,
      hstar: hstar,
      totalPrice: totalPrice,
      incompletePrice: incompletePrice,
      filteredList: filteredList,
      hdailyWage: human?.hdailyWage ?? 0,
      hdefaultRole: human?.hdefaultRole ?? '',
      human: human,
    );
  }

  WorkCostData processWorkCostData(String uniqueHuman) =>
      processWorkCostDataFor(state.completeState, uniqueHuman);

  void registerSlidable(BuildContext context) {
    if (!slidableContexts.contains(context)) {
      slidableContexts.add(context);
    }
  }

  String expansionControllerKey(CompleteState filter, String uniqueHuman) =>
      '${filter.name}|$uniqueHuman';

  bool isWorkerExpandedFor(CompleteState filter, String uniqueHuman) {
    final set = state.expandedWorkerKeys[filter];
    return set?.contains(uniqueHuman) ?? false;
  }

  bool isWorkerExpanded(String uniqueHuman) =>
      isWorkerExpandedFor(state.completeState, uniqueHuman);

  void setWorkerExpandedFor(
    CompleteState filter,
    String uniqueHuman,
    bool expanded,
  ) {
    final next = {
      for (final s in CompleteState.values)
        s: Set<String>.from(state.expandedWorkerKeys[s] ?? {}),
    };
    final set = next[filter]!;
    if (expanded) {
      set.add(uniqueHuman);
    } else {
      set.remove(uniqueHuman);
    }
    next[filter] = set;
    state = state.copyWith(expandedWorkerKeys: next);
  }

  void setWorkerExpanded(String uniqueHuman, bool expanded) =>
      setWorkerExpandedFor(state.completeState, uniqueHuman, expanded);

  void registerExpansionTile({
    required CompleteState completeState,
    required String uniqueHuman,
    required ExpansionTileController controller,
  }) {
    expansionTileControllerMap[
        expansionControllerKey(completeState, uniqueHuman)] = controller;
  }

  void closeAllSliders() {
    for (final ctx in List<BuildContext>.from(slidableContexts)) {
      try {
        Slidable.of(ctx)?.close();
      } catch (_) {}
    }
    slidableContexts.clear();
  }

  void collapseAllExpansionTiles() {
    for (final c in expansionTileControllerMap.values) {
      try {
        c.collapse();
      } catch (_) {}
    }
    state = state.copyWith(
      expandedWorkerKeys: {
        CompleteState.whole: {},
        CompleteState.incomplete: {},
      },
    );
  }
}
