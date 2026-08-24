import 'dart:async' show Timer, unawaited;
import 'dart:io';

import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/paged_result.dart' show mergePagedItems;
import 'package:w0001/data/model/work_cost_period_totals.dart';
import 'package:w0001/data/model/work_cost_worker_summary.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/domain/use_case/human_use_case.dart';
import 'package:w0001/domain/use_case/workcost_use_case.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show humanUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/worker_rank_wage_settings_providers.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/fetch_data.dart' show FetchData;
import 'package:w0001/util/human_contact_display.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/phone_number_format.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/ui/screen/4_human/work_cost_human_key_codec.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_skills_editor.dart';
import 'package:w0001/util/worker_skills_display.dart';
import 'package:w0001/util/worker_skills_match.dart';
import 'package:w0001/ui/screen/4_human/widgets/work_cost_period_picker_dialog.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';

/// 인력 목록 API 페이지 크기 — [kListPageSize]와 동일.
const int kHumanListPageSize = kListPageSize;

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

/// 인력별 체크박스 선택 요약 (1단 목록 표시용).
class WorkCostHumanSelection {
  const WorkCostHumanSelection({this.count = 0, this.amount = 0});

  final int count;
  final int amount;

  bool get hasSelection => count > 0;
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
    this.incompleteCount = 0,
    this.completeCount = 0,
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
  final int incompleteCount;
  final int completeCount;

  /// `workerInfoList`에서 병합한 일당(사람 관리와 동일 출처).
  final int hdailyWage;

  /// `workerInfoList`에서 병합한 기본 역할.
  final String hdefaultRole;

  /// 스킬 표시용 — [workerInfoList]와 매칭된 인력.
  final HumanModel? human;

  int get completePrice => totalPrice - incompletePrice;
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
    required this.humanFormWorkerRank,
    required this.humanFormCareerYears,
    required this.taxState,
    required this.dayState,
    required this.completeState,
    required this.selectedIndex,
    required this.totalWorkCostList,
    required this.filteredTotalWorkCostList,
    required this.checkboxStates,
    required this.expandedWorkerKeys,
    required this.hasMore,
    required this.isLoadingMore,
    this.workCostPeriodTotals,
    this.workCostSummaries = const [],
    this.workCostSummariesHasMore = false,
    this.workCostSummariesIsLoadingMore = false,
    this.workCostSummariesNextCursor,
    this.workCostSummariesTotalCount,
    this.workCostUsesLegacyList = false,
    this.workCostItemsByHuman = const {},
    this.workCostItemsLoadingKey,
    this.workCostPlacePid = 0,
    this.workCostPlaceOptionsNonce = 0,
    this.isWorkersLoading = false,
    this.isWorkCostLoading = false,
    this.nextCursor,
    this.totalCount,
  });

  final DateTimeRange dateTimeRange;
  final DateTime selectDay;
  final List<bool> toggleState;
  final List<HumanModel> workerInfoList;
  final List<HumanModel> filteredWorkerList;
  final bool isEditing;

  /// 사람 관리 폼: 역할 칩 선택(`직접입력` 포함). null이면 아직 선택 없음.
  final String? humanFormWorkRole;

  /// 사람 관리 폼: 현장 역할(`worker_rank`). null·`''` = 미선택.
  final String? humanFormWorkerRank;

  /// 사람 관리 폼: 경력 년수. null = 미등록.
  final int? humanFormCareerYears;
  final TaxState taxState;
  final DayTpye dayState;
  final CompleteState completeState;
  final int selectedIndex;
  final List<TotalWorkCostModel> totalWorkCostList;
  final List<TotalWorkCostModel> filteredTotalWorkCostList;
  final Map<int, CheckboxData> checkboxStates;

  /// 하단 총액 — 목록(페이지)과 분리. 서버 `/work-costs/totals` 또는 전체 목록 합산.
  final WorkCostPeriodTotals? workCostPeriodTotals;

  /// 1단 인력별 요약 (`GET /work-costs/worker-summaries`).
  final List<WorkCostWorkerSummary> workCostSummaries;
  final bool workCostSummariesHasMore;
  final bool workCostSummariesIsLoadingMore;
  final String? workCostSummariesNextCursor;
  final int? workCostSummariesTotalCount;

  /// summaries API 미지원 시 전체 wid 목록 fetch.
  final bool workCostUsesLegacyList;

  /// 2단 상세 — 인력별 wid 목록 lazy cache.
  final Map<String, List<TotalWorkCostModel>> workCostItemsByHuman;
  final String? workCostItemsLoadingKey;

  /// 0 = 전체 현장. 목록·상세·footer 공통.
  final int workCostPlacePid;

  /// [workCostPeriodPlaceOptions] 로드 완료 시 증가 — UI 리빌드용.
  final int workCostPlaceOptionsNonce;

  /// 전체·미지급 필터별 펼침 상태(`getUniqueHuman` 키).
  final Map<CompleteState, Set<String>> expandedWorkerKeys;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isWorkersLoading;
  final bool isWorkCostLoading;
  final String? nextCursor;
  final int? totalCount;

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
      toggleState: const [false, true],
      workerInfoList: const [],
      filteredWorkerList: const [],
      isEditing: false,
      humanFormWorkRole: null,
      humanFormWorkerRank: null,
      humanFormCareerYears: null,
      taxState: TaxState.taxOff,
      dayState: DayTpye.month,
      completeState: CompleteState.incomplete,
      selectedIndex: -1,
      totalWorkCostList: const [],
      filteredTotalWorkCostList: const [],
      checkboxStates: const {},
      expandedWorkerKeys: {
        CompleteState.whole: {},
        CompleteState.incomplete: {},
      },
      hasMore: false,
      isLoadingMore: false,
      isWorkersLoading: false,
      isWorkCostLoading: true,
      workCostPlacePid: 0,
      workCostPlaceOptionsNonce: 0,
      nextCursor: null,
      totalCount: null,
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
    String? humanFormWorkerRank,
    bool clearHumanFormWorkerRank = false,
    int? humanFormCareerYears,
    bool clearHumanFormCareerYears = false,
    TaxState? taxState,
    DayTpye? dayState,
    CompleteState? completeState,
    int? selectedIndex,
    List<TotalWorkCostModel>? totalWorkCostList,
    List<TotalWorkCostModel>? filteredTotalWorkCostList,
    Map<int, CheckboxData>? checkboxStates,
    WorkCostPeriodTotals? workCostPeriodTotals,
    bool clearWorkCostPeriodTotals = false,
    List<WorkCostWorkerSummary>? workCostSummaries,
    bool? workCostSummariesHasMore,
    bool? workCostSummariesIsLoadingMore,
    String? workCostSummariesNextCursor,
    bool clearWorkCostSummariesNextCursor = false,
    int? workCostSummariesTotalCount,
    bool clearWorkCostSummariesTotalCount = false,
    bool? workCostUsesLegacyList,
    Map<String, List<TotalWorkCostModel>>? workCostItemsByHuman,
    bool clearWorkCostItemsByHuman = false,
    String? workCostItemsLoadingKey,
    bool clearWorkCostItemsLoadingKey = false,
    int? workCostPlacePid,
    int? workCostPlaceOptionsNonce,
    Map<CompleteState, Set<String>>? expandedWorkerKeys,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isWorkersLoading,
    bool? isWorkCostLoading,
    String? nextCursor,
    bool clearNextCursor = false,
    int? totalCount,
    bool clearTotalCount = false,
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
      humanFormWorkerRank: clearHumanFormWorkerRank
          ? null
          : (humanFormWorkerRank ?? this.humanFormWorkerRank),
      humanFormCareerYears: clearHumanFormCareerYears
          ? null
          : (humanFormCareerYears ?? this.humanFormCareerYears),
      taxState: taxState ?? this.taxState,
      dayState: dayState ?? this.dayState,
      completeState: completeState ?? this.completeState,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      totalWorkCostList: totalWorkCostList ?? this.totalWorkCostList,
      filteredTotalWorkCostList:
          filteredTotalWorkCostList ?? this.filteredTotalWorkCostList,
      checkboxStates: checkboxStates ?? this.checkboxStates,
      workCostPeriodTotals: clearWorkCostPeriodTotals
          ? null
          : (workCostPeriodTotals ?? this.workCostPeriodTotals),
      workCostSummaries: workCostSummaries ?? this.workCostSummaries,
      workCostSummariesHasMore:
          workCostSummariesHasMore ?? this.workCostSummariesHasMore,
      workCostSummariesIsLoadingMore:
          workCostSummariesIsLoadingMore ?? this.workCostSummariesIsLoadingMore,
      workCostSummariesNextCursor: clearWorkCostSummariesNextCursor
          ? null
          : (workCostSummariesNextCursor ?? this.workCostSummariesNextCursor),
      workCostSummariesTotalCount: clearWorkCostSummariesTotalCount
          ? null
          : (workCostSummariesTotalCount ?? this.workCostSummariesTotalCount),
      workCostUsesLegacyList:
          workCostUsesLegacyList ?? this.workCostUsesLegacyList,
      workCostItemsByHuman: clearWorkCostItemsByHuman
          ? const {}
          : (workCostItemsByHuman ?? this.workCostItemsByHuman),
      workCostItemsLoadingKey: clearWorkCostItemsLoadingKey
          ? null
          : (workCostItemsLoadingKey ?? this.workCostItemsLoadingKey),
      workCostPlacePid: workCostPlacePid ?? this.workCostPlacePid,
      workCostPlaceOptionsNonce:
          workCostPlaceOptionsNonce ?? this.workCostPlaceOptionsNonce,
      expandedWorkerKeys: expandedWorkerKeys != null
          ? {
              for (final s in CompleteState.values)
                s: Set<String>.from(expandedWorkerKeys[s] ?? {}),
            }
          : {
              for (final s in CompleteState.values)
                s: Set<String>.from(this.expandedWorkerKeys[s] ?? {}),
            },
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isWorkersLoading: isWorkersLoading ?? this.isWorkersLoading,
      isWorkCostLoading: isWorkCostLoading ?? this.isWorkCostLoading,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      totalCount: clearTotalCount ? null : (totalCount ?? this.totalCount),
    );
  }
}

final workerProvider =
    NotifierProvider<WorkerViewModel, WorkerState>(WorkerViewModel.new);

class WorkerViewModel extends Notifier<WorkerState> {
  late final HumanUseCase _humanUseCase = ref.read(humanUseCaseProvider);
  late final WorkCostUseCase _workCostUseCase =
      ref.read(workCostUseCaseProvider);

  final humanSkillsEditorKey = GlobalKey<WorkerSkillsEditorState>();

  final List<BuildContext> slidableContexts = [];
  final Map<String, ExpansionTileController> expansionTileControllerMap = {};

  bool _initialized = false;
  var _disposeHookRegistered = false;
  var _resourcesDisposed = false;
  String _workCostSearchQuery = '';
  Timer? _searchDebounce;
  Timer? _workCostSearchDebounce;
  Future<void>? _loadMoreInFlight;
  Future<void>? _loadMoreWorkCostSummariesInFlight;
  List<HumanModel>? _browseWorkersCache;
  HumanModel? _editingHumanOverride;
  List<PlaceDropDownModel>? _workCostPeriodPlaceOptions;
  DateTimeRange? _workCostPeriodPlaceOptionsRange;
  Future<void>? _workCostPeriodPlacesInFlight;
  int _summariesFetchedForPlacePid = 0;

  bool get isWorkCostPeriodPlacesLoading =>
      _workCostPeriodPlacesInFlight != null;

  /// 인건비 탭 검색어 — [WorkCostScreen] 로컬 컨트롤러와 동기화.
  String get workCostSearchQuery => _workCostSearchQuery;

  int? get _activeWorkCostPlacePid =>
      state.workCostPlacePid == 0 ? null : state.workCostPlacePid;

  List<TotalWorkCostModel> _applyWorkCostPlaceFilter(
    List<TotalWorkCostModel> list,
  ) {
    final pid = state.workCostPlacePid;
    if (pid == 0) return list;
    return list.where((e) => e.involvesPlace(pid)).toList();
  }

  List<PlaceDropDownModel> _placesFromWorkCostItems(
    List<TotalWorkCostModel> items,
  ) {
    final seen = <int, String>{};
    for (final e in items) {
      if (e.sameDayPlaces.isNotEmpty) {
        for (final p in e.sameDayPlaces) {
          if (p.pid == 0) continue;
          seen[p.pid] = p.name;
        }
        continue;
      }
      if (e.wpid == 0) continue;
      seen[e.wpid] = e.pname;
    }
    final entries = seen.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [
      PlaceDropDownModel(pname: '전체 현장', pid: 0),
      for (final e in entries) PlaceDropDownModel(pname: e.value, pid: e.key),
    ];
  }

  List<PlaceDropDownModel> workCostPlaceOptionsForHuman(String uniqueHuman) {
    final cached = state.workCostItemsByHuman[uniqueHuman];
    if (cached != null && cached.isNotEmpty) {
      return _placesFromWorkCostItems(cached);
    }
    final rows = state.filteredTotalWorkCostList
        .where((e) => 'name:${e.hname}#number:${e.hnumber}' == uniqueHuman);
    final fromLegacy = _placesFromWorkCostItems(rows.toList());
    if (fromLegacy.length > 1) return fromLegacy;
    return workCostPeriodPlaceOptions();
  }

  List<PlaceDropDownModel> workCostPeriodPlaceOptions() {
    if (state.workCostUsesLegacyList && state.totalWorkCostList.isNotEmpty) {
      return _placesFromWorkCostItems(state.totalWorkCostList);
    }
    return _workCostPeriodPlaceOptions ??
        [PlaceDropDownModel(pname: '전체 현장', pid: 0)];
  }

  Future<void> ensureWorkCostPeriodPlacesLoaded() async {
    if (state.workCostUsesLegacyList) return;
    final range = state.dateTimeRange;
    if (_workCostPeriodPlaceOptionsRange == range &&
        _workCostPeriodPlaceOptions != null) {
      return;
    }
    if (_workCostPeriodPlacesInFlight != null) {
      return _workCostPeriodPlacesInFlight;
    }
    _workCostPeriodPlacesInFlight = _loadWorkCostPeriodPlaces(range);
    try {
      await _workCostPeriodPlacesInFlight;
    } finally {
      _workCostPeriodPlacesInFlight = null;
    }
  }

  Future<void> _loadWorkCostPeriodPlaces(DateTimeRange range) async {
    try {
      final places = await _workCostUseCase.getPlacesForWorkCostInPeriod(
        range.start,
        range.end,
      );
      _workCostPeriodPlaceOptions = places;
      _workCostPeriodPlaceOptionsRange = range;
    } catch (e, st) {
      debugPrint('Work cost period places load failed: $e\n$st');
      _workCostPeriodPlaceOptions = [
        PlaceDropDownModel(pname: '전체 현장', pid: 0),
      ];
      _workCostPeriodPlaceOptionsRange = range;
    }
    state = state.copyWith(
      workCostPlaceOptionsNonce: state.workCostPlaceOptionsNonce + 1,
    );
  }

  void _invalidateWorkCostPeriodPlaceOptions() {
    _workCostPeriodPlaceOptions = null;
    _workCostPeriodPlaceOptionsRange = null;
  }

  Future<void> syncSummariesIfPlaceFilterChanged() async {
    if (_summariesFetchedForPlacePid == state.workCostPlacePid) return;
    await fetchWorkCost();
  }

  Future<void> setWorkCostPlaceFilter(int pid,
      {bool refetchList = true}) async {
    if (state.workCostPlacePid == pid) return;
    state = state.copyWith(
      workCostPlacePid: pid,
      checkboxStates: refetchList ? {} : state.checkboxStates,
      clearWorkCostItemsByHuman: refetchList,
    );
    if (refetchList) {
      await fetchWorkCost();
    }
  }

  ({int total, int unpaid}) footerTotalsFor({String? uniqueHumanKey}) {
    if (uniqueHumanKey != null && uniqueHumanKey.isNotEmpty) {
      final data = processWorkCostDataFor(
        state.completeState,
        uniqueHumanKey,
      );
      return (total: data.totalPrice, unpaid: data.incompletePrice);
    }
    return (total: totalCost, unpaid: totalIncompleteCost);
  }

  WorkCostHumanSelection footerSelectionFor({String? uniqueHumanKey}) {
    if (uniqueHumanKey != null && uniqueHumanKey.isNotEmpty) {
      final data = processWorkCostDataFor(
        state.completeState,
        uniqueHumanKey,
      );
      return selectionForHuman(
        hid: data.hid,
        uniqueHumanKey: uniqueHumanKey,
      );
    }
    return WorkCostHumanSelection(
      count: state.selectedCount,
      amount: selectedIncompleteCost,
    );
  }

  bool footerCanPayFor({String? uniqueHumanKey}) {
    if (uniqueHumanKey == null || uniqueHumanKey.isEmpty) {
      return selectedUnpaidWidList.isNotEmpty;
    }
    final scoped = _scopedWidsForHuman(uniqueHumanKey);
    return selectedUnpaidWidList.any(scoped.contains);
  }

  bool footerCanUnpayFor({String? uniqueHumanKey}) {
    if (uniqueHumanKey == null || uniqueHumanKey.isEmpty) {
      return selectedPaidWidList.isNotEmpty;
    }
    final scoped = _scopedWidsForHuman(uniqueHumanKey);
    return selectedPaidWidList.any(scoped.contains);
  }

  int footerSelectedUnpaidCostFor({String? uniqueHumanKey}) {
    if (uniqueHumanKey == null || uniqueHumanKey.isEmpty) {
      return selectedUnpaidCost;
    }
    final scoped = _scopedWidsForHuman(uniqueHumanKey);
    var total = 0;
    for (final wid in selectedUnpaidWidList) {
      if (!scoped.contains(wid)) continue;
      total += workCostByWid(wid)?.price ?? 0;
    }
    return total;
  }

  int footerSelectedPaidCostFor({String? uniqueHumanKey}) {
    if (uniqueHumanKey == null || uniqueHumanKey.isEmpty) {
      return selectedPaidCost;
    }
    final scoped = _scopedWidsForHuman(uniqueHumanKey);
    var total = 0;
    for (final wid in selectedPaidWidList) {
      if (!scoped.contains(wid)) continue;
      total += workCostByWid(wid)?.price ?? 0;
    }
    return total;
  }

  Set<int> _scopedWidsForHuman(String uniqueHumanKey) {
    final cached = state.workCostItemsByHuman[uniqueHumanKey];
    if (cached != null) {
      return cached.map((e) => e.wid).toSet();
    }
    return workCostRowsFor(state.completeState)
        .where((e) => 'name:${e.hname}#number:${e.hnumber}' == uniqueHumanKey)
        .map((e) => e.wid)
        .toSet();
  }

  TextEditingController? _workerNameController;
  TextEditingController get workerNameController =>
      _workerNameController ??= TextEditingController();

  TextEditingController? _workerNumController;
  TextEditingController get workerNumController =>
      _workerNumController ??= TextEditingController();

  TextEditingController? _workerDailyWageController;
  TextEditingController get workerDailyWageController =>
      _workerDailyWageController ??=
          TextEditingController(text: formatIntegerWithComma(0));

  TextEditingController? _workerMemoController;
  TextEditingController get workerMemoController =>
      _workerMemoController ??= TextEditingController();

  TextEditingController? _workerPhoneController;
  TextEditingController get workerPhoneController =>
      _workerPhoneController ??= TextEditingController();

  TextEditingController? _searchWorkerDetailTextContoller;
  TextEditingController get searchWorkerDetailTextContoller =>
      _searchWorkerDetailTextContoller ??= TextEditingController();

  TextEditingController? _workerRoleCustomController;
  TextEditingController get workerRoleCustomController =>
      _workerRoleCustomController ??= TextEditingController();

  TextEditingController? _workerPrimarySpecialtyController;
  TextEditingController get workerPrimarySpecialtyController =>
      _workerPrimarySpecialtyController ??= TextEditingController();

  void _disposeResources() {
    if (_resourcesDisposed) return;
    _resourcesDisposed = true;
    _searchDebounce?.cancel();
    _workCostSearchDebounce?.cancel();
    _workerNameController?.dispose();
    _workerNameController = null;
    _workerNumController?.dispose();
    _workerNumController = null;
    _workerDailyWageController?.dispose();
    _workerDailyWageController = null;
    _workerMemoController?.dispose();
    _workerMemoController = null;
    _workerPhoneController?.dispose();
    _workerPhoneController = null;
    _searchWorkerDetailTextContoller?.dispose();
    _searchWorkerDetailTextContoller = null;
    _workerRoleCustomController?.dispose();
    _workerRoleCustomController = null;
    _workerPrimarySpecialtyController?.dispose();
    _workerPrimarySpecialtyController = null;
  }

  ListQuery _buildWorkersQuery({String? cursor}) {
    final q = searchWorkerDetailTextContoller.text.trim();
    return ListQuery(
      hdelete: 0,
      q: q.isEmpty ? null : q,
      limit: kHumanListPageSize,
      cursor: cursor,
    );
  }

  @override
  WorkerState build() {
    if (!_disposeHookRegistered) {
      _disposeHookRegistered = true;
      ref.onDispose(_disposeResources);
    }
    if (!_initialized) {
      _initialized = true;
      Future(() async {
        await fetchWorkCost();
        await refreshWorkers();
      });
    }
    return WorkerState.initial();
  }

  Future<void> refreshWorkCostsFromGlobalFetch() async {
    state = state.copyWith(checkboxStates: {});
    await fetchWorkCost();
  }

  /// [FetchData.fetchAllData] 등에서 호출
  Future<void> refreshFromGlobalFetch() async {
    state = state.copyWith(checkboxStates: {});
    await fetchWorkCost();
    await refreshWorkers();
  }

  int get totalCost {
    if (_workCostSearchQuery.trim().isNotEmpty &&
        state.workCostUsesLegacyList) {
      return _sumWorkCostPrices(state.filteredTotalWorkCostList);
    }
    final totals = state.workCostPeriodTotals;
    if (totals != null) return totals.totalAmount;
    return _sumWorkCostPrices(state.filteredTotalWorkCostList);
  }

  int get totalIncompleteCost {
    if (_workCostSearchQuery.trim().isNotEmpty &&
        state.workCostUsesLegacyList) {
      return _sumUnpaidWorkCostPrices(state.filteredTotalWorkCostList);
    }
    final totals = state.workCostPeriodTotals;
    if (totals != null) return totals.unpaidAmount;
    return _sumUnpaidWorkCostPrices(state.filteredTotalWorkCostList);
  }

  int _sumWorkCostPrices(List<TotalWorkCostModel> list) {
    var price = 0;
    for (final e in list) {
      price += e.price;
    }
    return price;
  }

  int _sumUnpaidWorkCostPrices(List<TotalWorkCostModel> list) {
    var price = 0;
    for (final e in list) {
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

  WorkCostHumanSelection selectionForHuman({
    required int hid,
    String? uniqueHumanKey,
  }) {
    final scopedWids = <int>{};
    final key = uniqueHumanKey?.trim();
    if (key != null && key.isNotEmpty) {
      final cached = state.workCostItemsByHuman[key];
      if (cached != null) {
        for (final e in cached) {
          scopedWids.add(e.wid);
        }
      }
    }

    var count = 0;
    var amount = 0;
    for (final e in state.checkboxStates.entries) {
      if (!e.value.isSelected) continue;
      if (scopedWids.isNotEmpty) {
        if (!scopedWids.contains(e.key)) continue;
      } else if (hid > 0) {
        if (e.value.hid != hid) continue;
      } else {
        continue;
      }
      count++;
      amount += e.value.price;
    }
    return WorkCostHumanSelection(count: count, amount: amount);
  }

  int get selectedIncompleteCost {
    var total = 0;
    for (final e in state.checkboxStates.values) {
      if (e.isSelected) total += e.price;
    }
    return total;
  }

  TotalWorkCostModel? workCostByWid(int wid) {
    for (final e in state.totalWorkCostList) {
      if (e.wid == wid) return e;
    }
    for (final items in state.workCostItemsByHuman.values) {
      for (final e in items) {
        if (e.wid == wid) return e;
      }
    }
    return null;
  }

  List<int> get selectedUnpaidWidList => state.selectedWidList
      .where((wid) => workCostByWid(wid)?.wcomplete == 0)
      .toList();

  List<int> get selectedPaidWidList => state.selectedWidList
      .where((wid) => workCostByWid(wid)?.wcomplete == 1)
      .toList();

  int get selectedPaidCost {
    var total = 0;
    for (final wid in selectedPaidWidList) {
      total += workCostByWid(wid)?.price ?? 0;
    }
    return total;
  }

  int get selectedUnpaidCost {
    var total = 0;
    for (final wid in selectedUnpaidWidList) {
      total += workCostByWid(wid)?.price ?? 0;
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

  /// 인건비 항목 체크박스 선택 전체 해제 (목록·상세 공통).
  ///
  /// 맵 자체를 비우면 [toggleCheckboxState]가 동작하지 않으므로 isSelected만 false로 둔다.
  void clearWorkCostCheckboxSelection() {
    if (state.checkboxStates.isEmpty) return;
    final map = Map<int, CheckboxData>.from(state.checkboxStates);
    var changed = false;
    for (final e in map.entries) {
      if (!e.value.isSelected) continue;
      map[e.key] = e.value.copyWith(isSelected: false);
      changed = true;
    }
    if (!changed) return;
    state = state.copyWith(checkboxStates: map);
  }

  bool areAllWidsSelected(Iterable<int> wids) {
    final list = wids.toList();
    if (list.isEmpty) return false;
    for (final wid in list) {
      if (!(state.checkboxStates[wid]?.isSelected ?? false)) return false;
    }
    return true;
  }

  /// [wids] 전체가 선택돼 있으면 해제, 아니면 전부 선택.
  void toggleSelectAllWids(Iterable<int> wids) {
    final targets = wids.toList();
    if (targets.isEmpty) return;
    final selectAll = !areAllWidsSelected(targets);
    final map = Map<int, CheckboxData>.from(state.checkboxStates);
    for (final wid in targets) {
      final cur = map[wid];
      if (cur != null) {
        map[wid] = cur.copyWith(isSelected: selectAll);
      }
    }
    state = state.copyWith(checkboxStates: map);
  }

  List<int> unpaidWidsIn(List<TotalWorkCostModel> items) =>
      items.where((e) => e.wcomplete == 0).map((e) => e.wid).toList();

  List<int> paidWidsIn(List<TotalWorkCostModel> items) =>
      items.where((e) => e.wcomplete == 1).map((e) => e.wid).toList();

  void toggleSelectAllUnpaidIn(List<TotalWorkCostModel> items) =>
      toggleSelectAllWids(unpaidWidsIn(items));

  void toggleSelectAllPaidIn(List<TotalWorkCostModel> items) =>
      toggleSelectAllWids(paidWidsIn(items));

  bool areAllUnpaidSelectedIn(List<TotalWorkCostModel> items) =>
      areAllWidsSelected(unpaidWidsIn(items));

  bool areAllPaidSelectedIn(List<TotalWorkCostModel> items) =>
      areAllWidsSelected(paidWidsIn(items));

  ListQuery _buildWorkCostSummariesQuery({String? cursor}) {
    final r = state.dateTimeRange;
    final q = _workCostSearchQuery.trim();
    return listQueryForDateRange(r.start, r.end).copyWith(
      wcomplete: state.isIncomplete ? 0 : null,
      pid: _activeWorkCostPlacePid,
      q: q.isEmpty ? null : q,
      cursor: cursor,
      clearCursor: cursor == null,
    );
  }

  String? get _workCostTotalsSearchQuery {
    final q = _workCostSearchQuery.trim();
    return q.isEmpty ? null : q;
  }

  Future<WorkCostPeriodTotals?> _fetchWorkCostPeriodTotals() async {
    final r = state.dateTimeRange;
    return _workCostUseCase.getWorkCostPeriodTotals(
      r.start,
      r.end,
      q: _workCostTotalsSearchQuery,
      pid: _activeWorkCostPlacePid,
    );
  }

  void _applyLoadedWorkCostItems(List<TotalWorkCostModel> list) {
    final newCheckbox = Map<int, CheckboxData>.from(state.checkboxStates);
    for (final e in list) {
      newCheckbox.putIfAbsent(
        e.wid,
        () => CheckboxData(isSelected: false, price: e.price, hid: e.hid),
      );
    }
    state = state.copyWith(
      totalWorkCostList: list,
      filteredTotalWorkCostList: _applySearchFilter(list),
      checkboxStates: newCheckbox,
    );
  }

  void _mergeWorkCostItemsIntoState(List<TotalWorkCostModel> incoming) {
    if (incoming.isEmpty) return;
    final byWid = {for (final e in state.totalWorkCostList) e.wid: e};
    for (final e in incoming) {
      byWid[e.wid] = e;
    }
    final merged = byWid.values.toList()
      ..sort((a, b) {
        final c = b.hstar.compareTo(a.hstar);
        if (c != 0) return c;
        final d = a.hname.compareTo(b.hname);
        if (d != 0) return d;
        return a.date.compareTo(b.date);
      });
    _applyLoadedWorkCostItems(merged);
  }

  Future<void> _fetchWorkCostLegacy(
      {WorkCostPeriodTotals? presetTotals}) async {
    final r = state.dateTimeRange;
    final wcomplete = state.isIncomplete ? 0 : null;
    final list = await _workCostUseCase.getWorkCostsByDateRange(
      r.start,
      r.end,
      wcomplete: wcomplete,
      pid: _activeWorkCostPlacePid,
    );
    final totals = presetTotals ??
        await _fetchWorkCostPeriodTotals() ??
        WorkCostPeriodTotals.fromItems(list);
    _applyLoadedWorkCostItems(list);
    state = state.copyWith(
      workCostUsesLegacyList: true,
      workCostSummaries: const [],
      workCostSummariesHasMore: false,
      clearWorkCostSummariesNextCursor: true,
      clearWorkCostSummariesTotalCount: true,
      workCostPeriodTotals: totals,
      clearWorkCostItemsByHuman: true,
    );
  }

  Future<void> fetchWorkCost({bool invalidatePlaceOptions = true}) async {
    if (invalidatePlaceOptions) {
      _invalidateWorkCostPeriodPlaceOptions();
    }
    state = state.copyWith(
      isWorkCostLoading: true,
      clearWorkCostSummariesNextCursor: true,
      clearWorkCostItemsByHuman: true,
      checkboxStates: {},
    );
    try {
      final totalsFuture = _fetchWorkCostPeriodTotals();
      final summariesFuture = _workCostUseCase.getWorkCostWorkerSummariesPage(
        _buildWorkCostSummariesQuery(),
      );
      final summariesPage = await summariesFuture;
      final presetTotals = await totalsFuture;

      if (summariesPage == null) {
        await _fetchWorkCostLegacy(presetTotals: presetTotals);
        return;
      }

      final totals = presetTotals ??
          WorkCostPeriodTotals.fromSummaries(summariesPage.items);

      state = state.copyWith(
        workCostUsesLegacyList: false,
        workCostSummaries: summariesPage.items,
        workCostSummariesHasMore: summariesPage.canLoadMore,
        workCostSummariesNextCursor: summariesPage.nextCursor,
        workCostSummariesTotalCount: summariesPage.totalCount,
        workCostPeriodTotals: totals,
        totalWorkCostList: const [],
        filteredTotalWorkCostList: const [],
      );
    } catch (e, st) {
      debugPrint('Work cost fetch failed: $e\n$st');
    } finally {
      state = state.copyWith(isWorkCostLoading: false);
      _summariesFetchedForPlacePid = state.workCostPlacePid;
      unawaited(ensureWorkCostPeriodPlacesLoaded());
    }
  }

  Future<void> loadMoreWorkCostSummaries() async {
    if (state.workCostUsesLegacyList) return;
    if (!state.workCostSummariesHasMore ||
        state.workCostSummariesIsLoadingMore) {
      return;
    }
    if (_loadMoreWorkCostSummariesInFlight != null) {
      return _loadMoreWorkCostSummariesInFlight;
    }

    _loadMoreWorkCostSummariesInFlight = _loadMoreWorkCostSummariesBody();
    try {
      await _loadMoreWorkCostSummariesInFlight;
    } finally {
      _loadMoreWorkCostSummariesInFlight = null;
    }
  }

  Future<void> _loadMoreWorkCostSummariesBody() async {
    final cursor = state.workCostSummariesNextCursor;
    if (cursor == null || cursor.isEmpty) return;

    state = state.copyWith(workCostSummariesIsLoadingMore: true);
    try {
      final page = await _workCostUseCase.getWorkCostWorkerSummariesPage(
        _buildWorkCostSummariesQuery(cursor: cursor),
      );
      if (page == null) return;
      final merged = mergePagedItems(
        state.workCostSummaries,
        page.items,
        (s) => s.hid,
      );
      state = state.copyWith(
        workCostSummaries: merged,
        workCostSummariesHasMore: page.canLoadMore,
        workCostSummariesNextCursor: page.nextCursor,
        workCostSummariesTotalCount:
            page.totalCount ?? state.workCostSummariesTotalCount,
      );
    } catch (e, st) {
      debugPrint('Work cost summaries loadMore failed: $e\n$st');
    } finally {
      state = state.copyWith(workCostSummariesIsLoadingMore: false);
    }
  }

  int? hidForWorkCostHuman(String uniqueHuman) =>
      _hidForUniqueHuman(uniqueHuman);

  int? _hidForUniqueHuman(String uniqueHuman) {
    for (final s in state.workCostSummaries) {
      if (s.uniqueHumanKey == uniqueHuman) return s.hid;
    }
    for (final e in state.totalWorkCostList) {
      if ('name:${e.hname}#number:${e.hnumber}' == uniqueHuman) return e.hid;
    }
    return null;
  }

  Future<void> ensureWorkCostItemsLoaded(String uniqueHuman) async {
    if (state.workCostUsesLegacyList) return;
    if (state.workCostItemsByHuman.containsKey(uniqueHuman)) return;
    if (state.workCostItemsLoadingKey == uniqueHuman) return;

    final hid = _hidForUniqueHuman(uniqueHuman);
    if (hid == null || hid <= 0) return;

    state = state.copyWith(workCostItemsLoadingKey: uniqueHuman);
    try {
      final r = state.dateTimeRange;
      final items = await _workCostUseCase.getWorkCostsByDateRange(
        r.start,
        r.end,
        hid: hid,
        wcomplete: state.isIncomplete ? 0 : null,
      );
      _mergeWorkCostItemsIntoState(items);
      state = state.copyWith(
        workCostItemsByHuman: {
          ...state.workCostItemsByHuman,
          uniqueHuman: items,
        },
      );
    } catch (e, st) {
      debugPrint('Work cost items load failed: $e\n$st');
    } finally {
      if (state.workCostItemsLoadingKey == uniqueHuman) {
        state = state.copyWith(clearWorkCostItemsLoadingKey: true);
      }
    }
  }

  Future<void> reloadWorkCostItemsForHuman(String uniqueHuman) async {
    if (state.workCostUsesLegacyList) return;
    final next = Map<String, List<TotalWorkCostModel>>.from(
      state.workCostItemsByHuman,
    );
    next.remove(uniqueHuman);
    state = state.copyWith(workCostItemsByHuman: next);
    await ensureWorkCostItemsLoaded(uniqueHuman);
  }

  WorkCostData workCostDataFromSummary(WorkCostWorkerSummary summary) {
    return WorkCostData(
      hname: summary.hname,
      hnumber: summary.hnumber,
      hid: summary.hid,
      hstar: summary.hstar,
      totalPrice: summary.totalAmount,
      incompletePrice: summary.unpaidAmount,
      pcomplete: 1,
      filteredList: const [],
      incompleteCount: summary.unpaidCount,
      completeCount: summary.paidCount,
      hdailyWage: summary.hdailyWage,
      hdefaultRole: summary.hdefaultRole,
      human: summary.toHumanModel(),
    );
  }

  List<WorkCostWorkerSummary> get workCostSummariesForCurrentFilter =>
      state.workCostSummaries;

  List<TotalWorkCostModel> _applySearchFilter(
    List<TotalWorkCostModel> list,
  ) {
    final q = _workCostSearchQuery.trim().toLowerCase();
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

  Future<void> showDateTimeRangePicker(BuildContext context) async {
    final initialType =
        state.dayState == DayTpye.month ? DayTpye.range : state.dayState;
    final picked = await showWorkCostPeriodPickerDialog(
      context,
      initialRange: state.dateTimeRange,
      initialPeriodType: initialType,
    );
    if (picked == null) return;
    state = state.copyWith(
      dateTimeRange: picked.range,
      dayState: picked.periodType,
      toggleState: picked.periodType == DayTpye.month
          ? const [false, true]
          : const [true, false],
    );
    await fetchWorkCost();
  }

  Future<void> updateWComplete(int wcomplete, int id) async {
    await _workCostUseCase.toggleWorkCostCompletionStatus(wcomplete, id);
    await FetchData.onDataChanged(DataChangeEvent.workCostSaved);
  }

  Future<void> updateWorkCostPrice(int wid, int newPrice) async {
    await _workCostUseCase.updateWorkCostPrice(wid, newPrice);
    await FetchData.onDataChanged(DataChangeEvent.workCostSaved);
  }

  Future<void> deleteWorkCost(int wid) async {
    await _workCostUseCase.deleteWorkCost(wid);
    await FetchData.onDataChanged(DataChangeEvent.workCostSaved);
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
    await FetchData.onDataChanged(DataChangeEvent.workCostSaved);
  }

  Future<int?> unassignSameDayPlace({
    required int hid,
    required String dateKey,
    required int pidToRemove,
    required int workCostWid,
    required int workCostWpid,
  }) async {
    final nextWpid = await _workCostUseCase.unassignSameDayPlace(
      hid: hid,
      dateKey: dateKey,
      pidToRemove: pidToRemove,
      workCostWid: workCostWid,
      workCostWpid: workCostWpid,
    );
    await FetchData.onDataChanged(DataChangeEvent.workCostSaved);
    return nextWpid;
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
    _workCostSearchQuery = value;
    if (state.workCostUsesLegacyList) {
      final q = value.toLowerCase();
      state = state.copyWith(
        filteredTotalWorkCostList: q.isEmpty
            ? state.totalWorkCostList
            : state.totalWorkCostList
                .where((e) => e.hname.toLowerCase().contains(q))
                .toList(),
      );
      return;
    }
    _workCostSearchDebounce?.cancel();
    _workCostSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(fetchWorkCost());
    });
  }

  void clearWorkCostSearch() {
    _workCostSearchQuery = '';
    _workCostSearchDebounce?.cancel();
    if (state.workCostUsesLegacyList) {
      state = state.copyWith(
        filteredTotalWorkCostList: state.totalWorkCostList,
      );
      return;
    }
    unawaited(fetchWorkCost());
  }

  Future<void> selectToggleButton(int index, BuildContext context) async {
    if (index == 1) {
      state = state.copyWith(
        toggleState: const [false, true],
        dateTimeRange: getMonthDateRange(DateTime.now()),
        dayState: DayTpye.month,
        checkboxStates: {},
      );
      await fetchWorkCost();
      return;
    }

    final initialType =
        state.dayState == DayTpye.month ? DayTpye.range : state.dayState;
    final picked = await showWorkCostPeriodPickerDialog(
      context,
      initialRange: state.dateTimeRange,
      initialPeriodType: initialType,
    );
    if (picked == null) return;

    state = state.copyWith(
      toggleState: const [true, false],
      dateTimeRange: picked.range,
      dayState: picked.periodType,
      checkboxStates: {},
    );
    await fetchWorkCost();
  }

  void taxStateValueChanged(TaxState? value) {
    if (value != null) {
      state = state.copyWith(taxState: value);
    }
  }

  Future<void> completeStateValueChanged(CompleteState? value) async {
    if (value == null || value == state.completeState) return;
    state = state.copyWith(completeState: value);
    closeAllSliders();
    await fetchWorkCost(invalidatePlaceOptions: false);
  }

  Future<void> fetchWorkerInfo() => refreshWorkers();

  void _mergeHumanInState(HumanModel saved) {
    final hid = saved.hid;
    if (hid == null) return;
    List<HumanModel> upsertIn(List<HumanModel> list) {
      final i = list.indexWhere((h) => h.hid == hid);
      if (i < 0) {
        final next = List<HumanModel>.from(list)..add(saved);
        next.sort((a, b) {
          final c = b.hstar.compareTo(a.hstar);
          if (c != 0) return c;
          return a.hname.compareTo(b.hname);
        });
        return next;
      }
      final next = List<HumanModel>.from(list);
      next[i] = saved;
      return next;
    }

    state = state.copyWith(
      workerInfoList: upsertIn(state.workerInfoList),
      filteredWorkerList: upsertIn(state.filteredWorkerList),
    );
  }

  /// 목록 API가 `worker_rank`·일당 등을 비워 보낼 때 최근 저장값을 유지한다.
  HumanModel _preferNonEmptyHumanFields(
    HumanModel incoming,
    HumanModel? previous,
  ) {
    if (previous == null) return incoming;
    return HumanModel(
      hid: incoming.hid,
      uid: incoming.uid ?? previous.uid,
      hname: incoming.hname,
      hnumber: _coalesceHumanSensitiveText(incoming.hnumber, previous.hnumber),
      hmemo: incoming.hmemo ?? previous.hmemo,
      hdailyWage:
          incoming.hdailyWage > 0 ? incoming.hdailyWage : previous.hdailyWage,
      hdefaultRole: incoming.hdefaultRole.trim().isNotEmpty
          ? incoming.hdefaultRole
          : previous.hdefaultRole,
      primarySpecialty: incoming.primarySpecialty?.trim().isNotEmpty ?? false
          ? incoming.primarySpecialty
          : previous.primarySpecialty,
      specialties: const [],
      career:
          incoming.career.trim().isNotEmpty ? incoming.career : previous.career,
      workerRank: incoming.workerRank.trim().isNotEmpty
          ? incoming.workerRank
          : previous.workerRank,
      canBePlaceMember: incoming.canBePlaceMember || previous.canBePlaceMember,
      linkedUserName: incoming.linkedUserName ?? previous.linkedUserName,
      hphone: _coalesceHumanOptionalText(incoming.hphone, previous.hphone),
      linkedPhone: _coalesceHumanOptionalText(
          incoming.linkedPhone, previous.linkedPhone),
      hstar: incoming.hstar,
      hdelete: incoming.hdelete,
    );
  }

  String _coalesceHumanSensitiveText(String incoming, String previous) {
    final inTrim = incoming.trim();
    if (inTrim.isNotEmpty) return inTrim;
    return previous.trim();
  }

  String? _coalesceHumanOptionalText(String? incoming, String? previous) {
    final inTrim = incoming?.trim() ?? '';
    if (inTrim.isNotEmpty) return incoming;
    final prevTrim = previous?.trim() ?? '';
    return prevTrim.isEmpty ? incoming : previous;
  }

  List<HumanModel> _mergeWorkersWithPrevious(List<HumanModel> incoming) {
    final prevByHid = {
      for (final h in state.workerInfoList)
        if (h.hid != null) h.hid!: h,
    };
    return incoming
        .map((h) => _preferNonEmptyHumanFields(h, prevByHid[h.hid]))
        .toList();
  }

  /// 목록 API가 `worker_rank`·스킬 등을 비워 보낼 때 단건 조회로 보강한다.
  bool _needsWorkerSkillEnrichment(HumanModel h) {
    if (h.displayPrimarySpecialty != null) return false;
    final role = h.hdefaultRole.trim();
    return role.isNotEmpty && !isWorkerSiteRank(role);
  }

  /// 목록 API가 `worker_rank`·스킬 등을 비워 보낼 때 단건 조회로 보강한다.
  Future<List<HumanModel>> _enrichWorkersFromDetail(
      List<HumanModel> items) async {
    final missing = <int>[];
    for (final h in items) {
      final hid = h.hid;
      if (hid == null || hid <= 0) continue;
      final rank = resolveHumanSiteRank(h);
      final needsRank = rank == null || rank.isEmpty;
      if (needsRank || _needsWorkerSkillEnrichment(h)) missing.add(hid);
    }
    if (missing.isEmpty) return items;

    try {
      final fresh = await _humanUseCase.getWorkersByHids(missing);
      if (fresh.isEmpty) return items;
      final byHid = {for (final h in fresh) h.hid!: h};
      return items.map((h) {
        final hid = h.hid;
        if (hid == null) return h;
        final detail = byHid[hid];
        if (detail == null) return h;
        return _preferNonEmptyHumanFields(detail, h);
      }).toList();
    } catch (e, st) {
      debugPrint('_enrichWorkersFromDetail $e\n$st');
      return items;
    }
  }

  /// 첫 페이지부터 인력 목록 조회 (검색·pull-to-refresh).
  Future<void> refreshWorkers() async {
    state = state.copyWith(
      isWorkersLoading: true,
      isLoadingMore: false,
      clearNextCursor: true,
      clearTotalCount: true,
    );
    try {
      final page = await _humanUseCase.fetchWorkersPage(_buildWorkersQuery());
      var items = _mergeWorkersWithPrevious(page.items);
      items = await _enrichWorkersFromDetail(items);
      state = state.copyWith(
        workerInfoList: items,
        filteredWorkerList: items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        totalCount: page.totalCount,
      );
    } catch (e, st) {
      debugPrint('Worker list fetch failed: $e\n$st');
    } finally {
      state = state.copyWith(isWorkersLoading: false);
    }
  }

  /// 스크롤 하단 — 다음 cursor 페이지.
  Future<void> loadMoreWorkers() async {
    if (!state.hasMore || state.isLoadingMore) return;
    if (_loadMoreInFlight != null) return _loadMoreInFlight;

    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    _loadMoreInFlight = _loadMoreWorkersBody();
    try {
      await _loadMoreInFlight;
    } finally {
      _loadMoreInFlight = null;
    }
  }

  Future<void> _loadMoreWorkersBody() async {
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _humanUseCase.fetchWorkersPage(
        _buildWorkersQuery(cursor: state.nextCursor),
      );
      final merged = mergePagedItems(
        state.workerInfoList,
        page.items,
        (h) => h.hid,
      );
      var items = _mergeWorkersWithPrevious(merged);
      items = await _enrichWorkersFromDetail(items);
      state = state.copyWith(
        workerInfoList: items,
        filteredWorkerList: items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        totalCount: page.totalCount ?? state.totalCount,
      );
    } catch (e, st) {
      debugPrint('Worker list loadMore failed: $e\n$st');
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// 인력 관리 화면 진입 시 검색 초기화 + 목록 갱신.
  Future<void> prepareHumanManagementScreen() async {
    searchWorkerDetailTextContoller.clear();
    _searchDebounce?.cancel();
    unawaited(ref.read(workerRankWageSettingsUseCaseProvider).warmUp());
    await refreshWorkers();
  }

  /// 헤더 카운트 — 서버 `total`(첫 페이지). 로딩 중만 로드된 수 fallback.
  int get displayWorkerCount =>
      state.totalCount ?? state.filteredWorkerList.length;

  int indexOfWorkerInPagedList(HumanModel human) {
    final hid = human.hid;
    if (hid == null) return -1;
    return state.filteredWorkerList.indexWhere((w) => w.hid == hid);
  }

  void _invalidateBrowseCache() {
    _browseWorkersCache = null;
  }

  /// 찾기 바텀시트용 — 현재 검색어 기준 전체 인력 (C 용도, 카운트와 분리).
  Future<List<HumanModel>> fetchWorkersForBrowse() async {
    final q = searchWorkerDetailTextContoller.text.trim();
    if (q.isEmpty && _browseWorkersCache != null) {
      return List<HumanModel>.from(_browseWorkersCache!);
    }
    final list = await _humanUseCase.fetchAllWorkers(
      ListQuery(hdelete: 0, q: q.isEmpty ? null : q),
    );
    if (q.isEmpty) {
      _browseWorkersCache = list;
    }
    return list;
  }

  /// 수정 다이얼로그 직전 — 해당 인력만 단건 조회 (목록 N+1 방지).
  /// 목록에만 있는 `worker_rank`·스킬 등은 서버 단건 응답과 병합한다.
  Future<HumanModel> loadWorkerForEdit(HumanModel human) async {
    final hid = human.hid;
    if (hid == null || hid <= 0) return human;
    try {
      final list = await _humanUseCase.getWorkersByHids([hid]);
      if (list.isEmpty) return human;
      return _preferNonEmptyHumanFields(list.first, human);
    } catch (e, st) {
      debugPrint('loadWorkerForEdit $e\n$st');
      return human;
    }
  }

  /// PATCH/GET 응답에 빠진 필드는 방금 저장한 폼 값으로 보완한다.
  HumanModel _coalesceSavedWithForm(HumanModel saved, HumanModel fromForm) {
    return HumanModel(
      hid: saved.hid,
      uid: saved.uid ?? fromForm.uid,
      hname: saved.hname,
      hnumber: saved.hnumber,
      hmemo: saved.hmemo ?? fromForm.hmemo,
      hdailyWage: saved.hdailyWage > 0 ? saved.hdailyWage : fromForm.hdailyWage,
      hdefaultRole: saved.hdefaultRole.trim().isNotEmpty
          ? saved.hdefaultRole
          : fromForm.hdefaultRole,
      primarySpecialty: saved.primarySpecialty?.trim().isNotEmpty ?? false
          ? saved.primarySpecialty
          : fromForm.primarySpecialty,
      specialties: const [],
      workerRank: saved.workerRank.trim().isNotEmpty
          ? saved.workerRank
          : fromForm.workerRank,
      career: saved.career.trim().isNotEmpty ? saved.career : fromForm.career,
      canBePlaceMember: saved.canBePlaceMember || fromForm.canBePlaceMember,
      linkedUserName: saved.linkedUserName ?? fromForm.linkedUserName,
      hphone: saved.hphone ?? fromForm.hphone,
      linkedPhone: saved.linkedPhone ?? fromForm.linkedPhone,
      hstar: saved.hstar,
      hdelete: saved.hdelete,
    );
  }

  HumanModel? _formHuman;

  /// 다이얼로그 폼 초기값 — [showWorkerInfoFromHuman] 시점의 인력.
  HumanModel? get humanEditorSeed => _formHuman;

  /// 편집 중인 인력의 앱 인증 연락처 (읽기 전용 표시용).
  String? get humanFormLinkedPhone {
    final phone = _formHuman?.linkedPhone?.trim();
    if (phone == null || phone.isEmpty) return null;
    return phone;
  }

  void showWorkerInfoFromHuman(HumanModel human, {int? listIndex}) {
    _formHuman = human;
    _editingHumanOverride = null;
    var index = listIndex ?? indexOfWorkerInPagedList(human);
    if (index < 0) {
      _editingHumanOverride = human;
      index = -1;
    }
    workerNameController.text = human.hname;
    workerNumController.text = human.hnumber;
    workerDailyWageController.text = formatIntegerWithComma(human.hdailyWage);
    workerMemoController.text = human.hmemo ?? '';
    workerPhoneController.text = humanManualPhone(human) ?? '';
    state = state.copyWith(
      selectedIndex: index,
      isEditing: true,
    );
    _applyHumanProfileToForm(human);
  }

  void searchWokerInfo(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!ref.mounted) return;
      unawaited(refreshWorkers());
    });
  }

  void humanFormSelectWorkRole(String role) {
    state = state.copyWith(humanFormWorkRole: role);
    if (role != '직접입력') {
      workerRoleCustomController.clear();
    }
  }

  void humanFormSelectWorkerRank(String? rank) {
    final trimmed = rank?.trim();
    final resolved = trimmed == null || trimmed.isEmpty ? null : trimmed;
    state = state.copyWith(
      humanFormWorkerRank: resolved,
      clearHumanFormWorkerRank: resolved == null,
    );
    if (resolved != null) {
      _applyRankWageToForm(resolved);
    }
  }

  void humanFormSelectCareerYears(int years) {
    final clamped = years.clamp(0, CareerInputUtils.maxYears);
    state = state.copyWith(
      humanFormCareerYears: clamped,
      clearHumanFormCareerYears: false,
    );
  }

  void humanFormClearCareerYears() {
    state = state.copyWith(clearHumanFormCareerYears: true);
  }

  bool isHumanEditorFormDirty() {
    final seed = _formHuman;
    if (seed == null) {
      final wage = int.tryParse(
              workerDailyWageController.text.replaceAll(RegExp(r'\D'), '')) ??
          0;
      return workerNameController.text.trim().isNotEmpty ||
          workerNumController.text.trim().isNotEmpty ||
          workerMemoController.text.trim().isNotEmpty ||
          workerPhoneController.text.trim().isNotEmpty ||
          wage > 0 ||
          (state.humanFormWorkerRank?.trim().isNotEmpty ?? false) ||
          state.humanFormCareerYears != null ||
          (humanSkillsEditorKey.currentState?.hasPrimary ?? false);
    }

    final skills = _humanSkillsPrimaryFromEditor();
    final primary = skills?.trim() ?? '';
    final seedPrimary = seed.displayPrimarySpecialty?.trim() ?? '';

    final seedCareerYears = seed.career.trim().isEmpty
        ? null
        : CareerInputUtils.parseYears(seed.career);
    final seedRank = resolveHumanSiteRank(seed)?.trim() ?? '';
    final formRank = state.humanFormWorkerRank?.trim() ?? '';

    final seedWage = seed.hdailyWage;
    final formWage = int.tryParse(
            workerDailyWageController.text.replaceAll(RegExp(r'\D'), '')) ??
        0;

    if (workerNameController.text.trim() != seed.hname.trim()) return true;
    if (workerNumController.text.trim() != seed.hnumber.trim()) return true;
    if ((workerMemoController.text.trim()) != (seed.hmemo?.trim() ?? '')) {
      return true;
    }
    if (formWage != seedWage) return true;
    if ((humanManualPhone(seed) ?? '') != workerPhoneController.text.trim()) {
      return true;
    }
    if (formRank != seedRank) return true;
    if (state.humanFormCareerYears != seedCareerYears) return true;
    if (primary != seedPrimary) return true;
    return false;
  }

  void _applyRankWageToForm(String rank) {
    final wage =
        ref.read(workerRankWageSettingsUseCaseProvider).wageForRankSync(rank);
    if (wage == null) return;
    workerDailyWageController.text = formatIntegerWithComma(wage);
  }

  void _clearHumanRoleForm() {
    workerRoleCustomController.clear();
    workerPrimarySpecialtyController.clear();
    humanSkillsEditorKey.currentState?.clearForm();
    state = state.copyWith(
      clearHumanFormWorkRole: true,
      clearHumanFormWorkerRank: true,
      clearHumanFormCareerYears: true,
    );
  }

  void _clearLegacyPayrollRoleForm() {
    workerRoleCustomController.clear();
    state = state.copyWith(clearHumanFormWorkRole: true);
  }

  HumanModel? _pendingSkillsEditorHuman;

  void _queueSkillsEditorLoad(HumanModel human) {
    _pendingSkillsEditorHuman = human;
  }

  /// [HumanEditorFormFields] 마운트 후 호출 — 편집 중인 주특기·추가 작업을 UI에 반영.
  void syncHumanSkillsEditorIfNeeded() {
    final human = _pendingSkillsEditorHuman;
    if (human == null) return;
    final editor = humanSkillsEditorKey.currentState;
    if (editor == null) return;
    editor.loadFromHuman(human);
    _pendingSkillsEditorHuman = null;
  }

  bool get hasPendingSkillsEditorLoad => _pendingSkillsEditorHuman != null;

  String? _humanSkillsPrimaryFromEditor() {
    final editor = humanSkillsEditorKey.currentState;
    if (editor != null) {
      return editor
          .toProfile(
            workerRank: _humanFormPersistedWorkerRank(),
          )
          .primarySpecialty;
    }
    return _humanFormPrimarySpecialty();
  }

  String _humanFormDefaultPayrollRole({
    required String? primarySpecialty,
    required HumanModel base,
  }) {
    final primary = primarySpecialty?.trim() ?? '';
    if (primary.isNotEmpty) return primary;
    final persisted = humanFormPersistedDefaultRole().trim();
    if (persisted.isNotEmpty) return persisted;
    return base.hdefaultRole.trim();
  }

  String? _humanFormPrimarySpecialty() {
    final t = workerPrimarySpecialtyController.text.trim();
    return t.isEmpty ? null : t;
  }

  String _humanFormPersistedWorkerRank() =>
      state.humanFormWorkerRank?.trim() ?? '';

  String _humanFormPersistedCareer() {
    final years = state.humanFormCareerYears;
    if (years == null) return '';
    return CareerInputUtils.formatYearsForApi(years);
  }

  String? _humanFormManualPhone() {
    final raw = workerPhoneController.text.trim();
    if (raw.isEmpty) return null;
    return formatKoreanMobilePhoneDisplay(raw);
  }

  String? _validateHumanFormPhone() {
    final raw = workerPhoneController.text.trim();
    if (raw.isEmpty) return null;
    return koreanMobilePhoneFormatMessage(raw);
  }

  HumanModel _humanModelFromForm({
    required HumanModel base,
  }) {
    final primarySpecialty = _humanSkillsPrimaryFromEditor();
    return HumanModel(
      hid: base.hid,
      uid: base.uid,
      hname: workerNameController.text.trim(),
      hnumber: workerNumController.text.trim(),
      hmemo: workerMemoController.text.isNotEmpty
          ? workerMemoController.text.trim()
          : null,
      hdailyWage: int.tryParse(
              workerDailyWageController.text.replaceAll(RegExp(r'\D'), '')) ??
          0,
      hdefaultRole: _humanFormDefaultPayrollRole(
        primarySpecialty: primarySpecialty,
        base: base,
      ),
      primarySpecialty: primarySpecialty,
      specialties: const [],
      workerRank: _humanFormPersistedWorkerRank(),
      career: _humanFormPersistedCareer(),
      hphone: _humanFormManualPhone(),
      linkedPhone: base.linkedPhone,
      hstar: base.hstar,
      hdelete: base.hdelete,
    );
  }

  void _applyHumanProfileToForm(HumanModel human) {
    final rank = resolveHumanSiteRank(human);
    final careerRaw = human.career.trim();
    final careerYears =
        careerRaw.isEmpty ? null : CareerInputUtils.parseYears(careerRaw);
    state = state.copyWith(
      humanFormWorkerRank: rank,
      clearHumanFormWorkerRank: rank == null || rank.isEmpty,
      humanFormCareerYears: careerYears,
      clearHumanFormCareerYears: careerYears == null,
    );
    if (rank != null && rank.isNotEmpty) {
      final wageText =
          workerDailyWageController.text.replaceAll(RegExp(r'\D'), '');
      if ((int.tryParse(wageText) ?? 0) <= 0) {
        _applyRankWageToForm(rank);
      }
    }
    _queueSkillsEditorLoad(human);
    syncHumanSkillsEditorIfNeeded();
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
      _clearLegacyPayrollRoleForm();
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

  Future<HumanModel?> insertWorker(BuildContext context) async {
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
      return null;
    }
    final phoneError = _validateHumanFormPhone();
    if (phoneError != null) {
      messenger.showSnackBar(SnackBar(content: Text(phoneError)));
      return null;
    }
    if (state.workerInfoList.any(
      (w) => w.hname.toLowerCase() == hname.toLowerCase(),
    )) {
      messenger.showSnackBar(
        const SnackBar(content: Text('다른 이름으로 등록해 주세요.')),
      );
      return null;
    }

    var worker = _humanModelFromForm(
      base: HumanModel(
        uid: null,
        hname: hname,
        hnumber: hnumber,
        hstar: 0,
        hdelete: 0,
      ),
    );
    worker = await ref
        .read(workerRankWageSettingsUseCaseProvider)
        .applyRankDefaultWage(worker);
    if (worker.hdailyWage > 0) {
      workerDailyWageController.text =
          formatIntegerWithComma(worker.hdailyWage);
    }
    final savedRaw = await _humanUseCase.addWorker(worker);
    final saved = _coalesceSavedWithForm(savedRaw, worker);
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => saveDialog(text: '등록되었습니다.'),
      );
    }
    _invalidateBrowseCache();
    return saved;
  }

  Future<void> updateWorkCostsToComplete(BuildContext context) async {
    final targets = selectedUnpaidWidList;
    if (targets.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => deleteDialog(
        content: '선택 항목을 모두 지급하시겠습니까?',
        onPressed: () async {
          try {
            await _workCostUseCase.updateWorkCostsToComplete(targets);
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
          await FetchData.onDataChanged(DataChangeEvent.workCostSaved);
        },
      ),
    );
  }

  Future<void> updateSelectedWorkCostsToIncomplete(BuildContext context) async {
    final targets = selectedPaidWidList;
    if (targets.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => deleteDialog(
        content: '선택 항목을 미지급으로 변경할까요?',
        onPressed: () async {
          try {
            for (final wid in targets) {
              await _workCostUseCase.toggleWorkCostCompletionStatus(1, wid);
            }
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
          await FetchData.onDataChanged(DataChangeEvent.workCostSaved);
        },
      ),
    );
  }

  Future<HumanModel?> modifyWorkerInfo(
    BuildContext context,
    int index,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final hname = workerNameController.text.trim();

    final tempList = List<HumanModel>.from(state.filteredWorkerList)
      ..removeAt(index);

    if (hname.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('이름을 입력해 주세요.')),
      );
      return null;
    }
    final phoneError = _validateHumanFormPhone();
    if (phoneError != null) {
      messenger.showSnackBar(SnackBar(content: Text(phoneError)));
      return null;
    }

    if (tempList.any(
      (w) => w.hname.toLowerCase() == hname.toLowerCase(),
    )) {
      messenger.showSnackBar(
        const SnackBar(content: Text('다른 이름으로 등록해 주세요.')),
      );
      return null;
    }

    final fromForm = _humanModelFromForm(
      base: state.filteredWorkerList[index],
    );

    final savedRaw = await _humanUseCase.updateWorker(fromForm);
    final saved = _coalesceSavedWithForm(savedRaw, fromForm);
    _invalidateBrowseCache();
    return saved;
  }

  Future<HumanModel?> _modifyWorkerByHuman(
    BuildContext context,
    HumanModel original,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final hname = workerNameController.text.trim();

    final others =
        state.filteredWorkerList.where((w) => w.hid != original.hid).toList();

    if (hname.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('이름을 입력해 주세요.')),
      );
      return null;
    }
    final phoneError = _validateHumanFormPhone();
    if (phoneError != null) {
      messenger.showSnackBar(SnackBar(content: Text(phoneError)));
      return null;
    }

    if (others.any((w) => w.hname.toLowerCase() == hname.toLowerCase())) {
      messenger.showSnackBar(
        const SnackBar(content: Text('다른 이름으로 등록해 주세요.')),
      );
      return null;
    }

    final fromForm = _humanModelFromForm(base: original);

    final savedRaw = await _humanUseCase.updateWorker(fromForm);
    final saved = _coalesceSavedWithForm(savedRaw, fromForm);
    _invalidateBrowseCache();
    return saved;
  }

  void showWorkerInfo(
    int index,
    String workerName,
    String workerNum,
    int workerDailyWage,
    String workerMemo,
  ) {
    workerNameController.text = workerName;
    workerNumController.text = workerNum;
    workerDailyWageController.text = formatIntegerWithComma(workerDailyWage);
    workerMemoController.text = workerMemo;
    workerPhoneController.clear();
    state = state.copyWith(
      selectedIndex: index,
      isEditing: true,
    );
  }

  Future<HumanModel?> editButtonAction(BuildContext context) async {
    HumanModel? saved;
    if (state.isEditing) {
      final override = _editingHumanOverride;
      if (override != null) {
        saved = await _modifyWorkerByHuman(context, override);
      } else if (state.selectedIndex >= 0) {
        saved = await modifyWorkerInfo(context, state.selectedIndex);
      }
    } else {
      saved = await insertWorker(context);
    }
    if (saved == null) return null;
    _mergeHumanInState(saved);
    await FetchData.onDataChanged(DataChangeEvent.humanSaved);
    _mergeHumanInState(saved);
    return saved;
  }

  /// 수정 다이얼로그 닫을 때 — 폼만 초기화 (저장 직후 전체 reload 방지).
  void cancelHumanEditorForm() {
    workerNameController.clear();
    workerNumController.clear();
    workerDailyWageController.text = formatIntegerWithComma(0);
    workerMemoController.clear();
    workerPhoneController.clear();
    _clearHumanRoleForm();
    _pendingSkillsEditorHuman = null;
    _formHuman = null;
    _editingHumanOverride = null;
    state = state.copyWith(isEditing: false, selectedIndex: -1);
  }

  /// 다이얼로그 내 "입력 초기화" — 검색·목록은 유지한다.
  void resetHumanEditorFormInputs() {
    final seed = _formHuman;
    if (seed != null) {
      workerNameController.text = seed.hname;
      workerNumController.text = seed.hnumber;
      workerDailyWageController.text = formatIntegerWithComma(seed.hdailyWage);
      workerMemoController.text = seed.hmemo ?? '';
      workerPhoneController.text = humanManualPhone(seed) ?? '';
      _applyHumanProfileToForm(seed);
      return;
    }
    workerNameController.clear();
    workerNumController.clear();
    workerDailyWageController.text = formatIntegerWithComma(0);
    workerMemoController.clear();
    workerPhoneController.clear();
    _clearHumanRoleForm();
    humanSkillsEditorKey.currentState?.clearForm();
  }

  /// 인건비 탭 등 — 작업자·검색 상태 전체 초기화.
  void refreshAction() {
    cancelHumanEditorForm();
    searchWorkerDetailTextContoller.clear();
    _invalidateBrowseCache();
    fetchWorkerInfo();
  }

  Future<void> updateWorkerDelete(int index) async {
    final human = state.filteredWorkerList[index];
    await deleteNonMemberWorker(human: human);
  }

  /// 비회원(앱 계정 미연결) 인력만 삭제 가능.
  Future<void> deleteNonMemberWorker(
      {int? listIndex, HumanModel? human}) async {
    HumanModel? target;
    if (listIndex != null &&
        listIndex >= 0 &&
        listIndex < state.filteredWorkerList.length) {
      target = state.filteredWorkerList[listIndex];
    } else {
      target = human ?? _formHuman;
    }
    if (target == null || !humanIsNonMember(target)) return;
    final hid = target.hid;
    if (hid == null) return;

    workerNameController.clear();
    workerNumController.clear();
    workerDailyWageController.text = formatIntegerWithComma(0);
    workerMemoController.clear();
    workerPhoneController.clear();
    _clearHumanRoleForm();
    state = state.copyWith(isEditing: false);
    await _humanUseCase.deleteWorker(hid);
    await fetchWorkerInfo();
    _invalidateBrowseCache();
  }

  Future<void> updateHstarFromWorkerList(int index) async {
    final stared = state.filteredWorkerList[index].hstar == 1 ? false : true;
    final hid = state.filteredWorkerList[index].hid!;
    await _humanUseCase.toggleWorkerStarStatus(hid, stared);
    await fetchWorkerInfo();
    _invalidateBrowseCache();
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
        subject:
            '인건비 총계 (${formatDateTimeRangeToString(r, periodType: state.dayState)})',
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
    final parsed = parseWorkCostHumanKey(uniqueHuman);
    if (parsed == null) {
      return WorkCostData(
        pcomplete: 1,
        hname: '',
        hnumber: '',
        hid: 0,
        hstar: 0,
        totalPrice: 0,
        incompletePrice: 0,
        filteredList: [],
        incompleteCount: 0,
        completeCount: 0,
        hdailyWage: 0,
        hdefaultRole: '',
        human: null,
      );
    }
    final hname = parsed.hname;
    final hnumber = parsed.hnumber;

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

    var filteredList = !state.workCostUsesLegacyList &&
            state.workCostItemsByHuman.containsKey(uniqueHuman)
        ? () {
            final cached = state.workCostItemsByHuman[uniqueHuman]!;
            if (filter == CompleteState.incomplete) {
              return cached.where((e) => e.wcomplete == 0).toList();
            }
            return List<TotalWorkCostModel>.from(cached);
          }()
        : workCostRowsFor(filter)
            .where(
              (e) => 'name:${e.hname}#number:${e.hnumber}' == uniqueHuman,
            )
            .toList();
    filteredList = _applyWorkCostPlaceFilter(filteredList);

    if (filteredList.isEmpty) {
      if (state.workCostPlacePid == 0) {
        for (final s in state.workCostSummaries) {
          if (s.uniqueHumanKey == uniqueHuman) {
            return workCostDataFromSummary(s);
          }
        }
      }
      WorkCostWorkerSummary? summary;
      for (final s in state.workCostSummaries) {
        if (s.uniqueHumanKey == uniqueHuman) {
          summary = s;
          break;
        }
      }
      final fromList = humanFromList(summary?.hid ?? 0);
      final human = mergeHumanForWorkCostDisplay(
        hid: summary?.hid ?? 0,
        hname: hname,
        hnumber: hnumber,
        hstar: summary?.hstar ?? 0,
        hdailyWage: summary?.hdailyWage ?? fromList?.hdailyWage ?? 0,
        hdefaultRole: summary?.hdefaultRole ?? fromList?.hdefaultRole ?? '',
        workerRank: summary?.workerRank ?? '',
        primarySpecialty: summary?.primarySpecialty,
        specialties: summary?.specialties ?? const [],
        fromList: fromList,
      );
      return WorkCostData(
        pcomplete: 1,
        hname: hname,
        hnumber: hnumber,
        hid: summary?.hid ?? 0,
        hstar: summary?.hstar ?? 0,
        totalPrice: 0,
        incompletePrice: 0,
        filteredList: [],
        incompleteCount: 0,
        completeCount: 0,
        hdailyWage: human.hdailyWage,
        hdefaultRole: human.hdefaultRole,
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
    final incompleteCount = filteredList.where((e) => e.wcomplete == 0).length;
    final completeCount = filteredList.where((e) => e.wcomplete == 1).length;
    final row = filteredList.first;
    final human = mergeHumanForWorkCostDisplay(
      hid: hid,
      hname: hname,
      hnumber: hnumber,
      hstar: hstar,
      hdailyWage: row.hdailyWage,
      hdefaultRole: row.hdefaultRole,
      workerRank: row.workerRank,
      primarySpecialty: row.primarySpecialty,
      specialties: row.specialties,
      fromList: humanFromList(hid),
    );
    return WorkCostData(
      pcomplete: 1,
      hname: hname,
      hnumber: hnumber,
      hid: hid,
      hstar: hstar,
      totalPrice: totalPrice,
      incompletePrice: incompletePrice,
      filteredList: filteredList,
      incompleteCount: incompleteCount,
      completeCount: completeCount,
      hdailyWage: human.hdailyWage,
      hdefaultRole: human.hdefaultRole,
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
