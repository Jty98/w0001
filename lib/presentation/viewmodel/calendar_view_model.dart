import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/data/model/calendar_day_cost_totals.dart';
import 'package:w0001/data/model/dashboard_calendar_workforce_dots.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/paged_result.dart' show mergePagedItems;
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/data/repository/calendar_impl.dart';
import 'package:w0001/domain/repository/calendar_abst.dart';
import 'package:w0001/domain/use_case/calendar_use_case.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show materialCostUseCaseProvider, workCostUseCaseProvider;
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_schedule.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';

class _CalendarDayCostCacheEntry {
  const _CalendarDayCostCacheEntry({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.totals,
  });

  final List<TotalCostModel> items;
  final bool hasMore;
  final String? nextCursor;
  final CalendarDayCostTotals? totals;
}

class CalendarState {
  const CalendarState({
    required this.selectedDay,
    required this.focusedDay,
    required this.totalCostList,
    required this.events,
    required this.workforceDotEvents,
    required this.selectedFilterType,
    required this.dropDownSelectedCategory,
    required this.alertText,
    required this.dialogDateTime,
    this.hasLoadedOnce = false,
    this.dayCostIsLoading = false,
    this.dayCostIsLoadingMore = false,
    this.dayCostHasMore = false,
    this.dayCostNextCursor,
    this.dayCostTotals,
  });

  final DateTime selectedDay;
  final DateTime focusedDay;
  final List<TotalCostModel> totalCostList;
  final Map<DateTime, List<String>> events;
  final List<CalendarEvent> workforceDotEvents;
  final FilterType selectedFilterType;
  final String? dropDownSelectedCategory;
  final String alertText;
  final DateTime dialogDateTime;
  final bool hasLoadedOnce;
  final bool dayCostIsLoading;
  final bool dayCostIsLoadingMore;
  final bool dayCostHasMore;
  final String? dayCostNextCursor;
  final CalendarDayCostTotals? dayCostTotals;

  factory CalendarState.initial() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return CalendarState(
      selectedDay: now,
      focusedDay: day,
      totalCostList: const [],
      events: const {},
      workforceDotEvents: const [],
      selectedFilterType: FilterType.all,
      dropDownSelectedCategory: null,
      alertText: '',
      dialogDateTime: now,
    );
  }

  CalendarState copyWith({
    DateTime? selectedDay,
    DateTime? focusedDay,
    List<TotalCostModel>? totalCostList,
    Map<DateTime, List<String>>? events,
    List<CalendarEvent>? workforceDotEvents,
    FilterType? selectedFilterType,
    String? dropDownSelectedCategory,
    bool clearDropDownSelectedCategory = false,
    String? alertText,
    DateTime? dialogDateTime,
    bool? hasLoadedOnce,
    bool? dayCostIsLoading,
    bool? dayCostIsLoadingMore,
    bool? dayCostHasMore,
    String? dayCostNextCursor,
    bool clearDayCostNextCursor = false,
    CalendarDayCostTotals? dayCostTotals,
    bool clearDayCostTotals = false,
  }) {
    return CalendarState(
      selectedDay: selectedDay ?? this.selectedDay,
      focusedDay: focusedDay ?? this.focusedDay,
      totalCostList: totalCostList ?? this.totalCostList,
      events: events ?? this.events,
      workforceDotEvents: workforceDotEvents ?? this.workforceDotEvents,
      selectedFilterType: selectedFilterType ?? this.selectedFilterType,
      dropDownSelectedCategory: clearDropDownSelectedCategory
          ? null
          : (dropDownSelectedCategory ?? this.dropDownSelectedCategory),
      alertText: alertText ?? this.alertText,
      dialogDateTime: dialogDateTime ?? this.dialogDateTime,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      dayCostIsLoading: dayCostIsLoading ?? this.dayCostIsLoading,
      dayCostIsLoadingMore: dayCostIsLoadingMore ?? this.dayCostIsLoadingMore,
      dayCostHasMore: dayCostHasMore ?? this.dayCostHasMore,
      dayCostNextCursor: clearDayCostNextCursor
          ? null
          : (dayCostNextCursor ?? this.dayCostNextCursor),
      dayCostTotals:
          clearDayCostTotals ? null : (dayCostTotals ?? this.dayCostTotals),
    );
  }
}

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepositoryImpl(
    ref.read(dashboardRemoteRepositoryProvider),
  ),
);

final calendarUseCaseProvider = Provider<CalendarUseCase>(
  (ref) => CalendarUseCase(ref.read(calendarRepositoryProvider)),
);

final calendarProvider =
    NotifierProvider<CalendarViewModel, CalendarState>(CalendarViewModel.new);

class CalendarViewModel extends Notifier<CalendarState> {
  late final _calendarUseCase = ref.read(calendarUseCaseProvider);
  late final _materialCostUseCase = ref.read(materialCostUseCaseProvider);
  late final _workCostUseCase = ref.read(workCostUseCaseProvider);

  final TextEditingController mNameController = TextEditingController();
  final TextEditingController mPriceController = TextEditingController();

  Future<void>? _refreshInFlight;
  Future<void>? _loadMoreDayCostsInFlight;
  Future<void>? _markersInFlight;
  String? _markersInFlightKey;

  final _dayCostCache = <String, _CalendarDayCostCacheEntry>{};
  int _dayCostFetchGeneration = 0;

  final _loadedMarkerRangeKeys = <String>{};
  final _markerByDay = <String, ({bool sch, bool work})>{};
  final _markerCostDayKeys = <String>{};

  @override
  CalendarState build() {
    ref.onDispose(() {
      mNameController.dispose();
      mPriceController.dispose();
    });
    return CalendarState.initial();
  }

  /// [CalendarScreen] 첫 프레임 이후·로그인 확정 후 호출.
  Future<void> loadInitialData() async {
    await _refreshCalendarData(markLoaded: true);
  }

  /// [FetchData] 등 컨텍스트 없는 호출에서 캘린더만 갱신
  void _clearDayCostCache() => _dayCostCache.clear();

  void _invalidateDayCostCache([DateTime? day]) {
    if (day == null) {
      _clearDayCostCache();
      return;
    }
    _dayCostCache.remove(dateKeyYmd(day));
  }

  void _applyDayCostCache(DateTime day, _CalendarDayCostCacheEntry entry) {
    if (!ref.mounted) return;
    if (dateKeyYmd(state.focusedDay) != dateKeyYmd(day)) return;
    state = state.copyWith(
      totalCostList: entry.items,
      dayCostHasMore: entry.hasMore,
      dayCostNextCursor: entry.nextCursor,
      dayCostTotals: entry.totals,
      dayCostIsLoading: false,
    );
  }

  Future<void> refreshForFetchData() async {
    _clearMarkerCache();
    _clearDayCostCache();
    await _refreshCalendarData(markLoaded: true);
  }

  Future<void> _refreshCalendarData({required bool markLoaded}) async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }
    final job = _refreshCalendarDataBody(markLoaded: markLoaded);
    _refreshInFlight = job;
    try {
      await job;
    } finally {
      if (identical(_refreshInFlight, job)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _refreshCalendarDataBody({required bool markLoaded}) async {
    await Future.wait([
      _ensureCalendarMarkersLoaded(state.focusedDay),
      _runCalendarStep(fetchTotalCost, 'fetchTotalCost'),
    ]);
    if (markLoaded && ref.mounted) {
      state = state.copyWith(hasLoadedOnce: true);
    }
  }

  Future<void> _runCalendarStep(
    Future<void> Function() step,
    String label,
  ) async {
    try {
      await step();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('calendar $label failed: $e\n$st');
      }
    }
  }

  List<TotalCostModel> get filteredTotalCostList {
    switch (state.selectedFilterType) {
      case FilterType.all:
        return state.totalCostList;
      case FilterType.work:
        return state.totalCostList
            .where((element) => element.category == 'w')
            .toList();
      case FilterType.material:
        return state.totalCostList
            .where((element) => element.category != 'w')
            .toList();
      case FilterType.notPay:
        return state.totalCostList
            .where((element) => element.wcomplete == 0)
            .toList();
      default:
        return state.totalCostList
            .where(
              (element) =>
                  element.category == state.selectedFilterType.category,
            )
            .toList();
    }
  }

  int get getFilteredListPrice {
    final totals = state.dayCostTotals;
    if (totals != null) {
      switch (state.selectedFilterType) {
        case FilterType.all:
          return totals.totalAmount;
        case FilterType.work:
          return totals.workAmount;
        case FilterType.material:
          return totals.materialAmount;
        case FilterType.notPay:
          return totals.unpaidAmount;
        default:
          break;
      }
    }
    var price = 0;
    for (final element in filteredTotalCostList) {
      price += element.price;
    }
    return price;
  }

  int get placeCount =>
      filteredTotalCostList.map((model) => model.pname).toSet().length;

  List<Map<String, dynamic>> getUniquePlaceNameAndComplete() {
    final uniquePlaceNameAndComplete = <Map<String, dynamic>>[];
    final uniquePlaceNames =
        filteredTotalCostList.map((model) => model.pname).toSet();

    for (final pname in uniquePlaceNames) {
      final firstModel =
          filteredTotalCostList.firstWhere((model) => model.pname == pname);
      uniquePlaceNameAndComplete.add({
        'pname': firstModel.pname,
        'pcomplete': firstModel.pcomplete,
      });
    }

    uniquePlaceNameAndComplete.sort((a, b) => a['pname'].compareTo(b['pname']));

    return uniquePlaceNameAndComplete;
  }

  /// 현장별 일자 합계 — 접힌 타일 요약용 (필터와 무관하게 해당 일 전체).
  PlaceDayCostSummary placeDayCostSummary(String pname) {
    var work = 0;
    var material = 0;
    var unpaid = 0;
    var paid = 0;
    for (final e in state.totalCostList.where((m) => m.pname == pname)) {
      if (e.category == 'w') {
        work += e.price;
        if (e.wcomplete == 0) {
          unpaid += e.price;
        } else if (e.wcomplete == 1) {
          paid += e.price;
        }
      } else {
        material += e.price;
      }
    }
    return PlaceDayCostSummary(
      workAmount: work,
      materialAmount: material,
      paidAmount: paid,
      unpaidAmount: unpaid,
    );
  }

  void setFilterType(FilterType filterType) {
    state = state.copyWith(selectedFilterType: filterType);
  }

  void _clearMarkerCache() {
    _loadedMarkerRangeKeys.clear();
    _markerByDay.clear();
    _markerCostDayKeys.clear();
  }

  String _markerRangeKey(String from, String to) => '$from|$to';

  void _mergeMarkerPayload(DashboardCalendarWorkforceDots dots) {
    for (final e in dots.byDay.entries) {
      final prev = _markerByDay[e.key] ?? (sch: false, work: false);
      _markerByDay[e.key] = (
        sch: prev.sch || e.value.sch,
        work: prev.work || e.value.work,
      );
    }
    _markerCostDayKeys.addAll(dots.costDayKeys);
  }

  void _publishMarkerDotEvents() {
    if (!ref.mounted) return;
    state = state.copyWith(
      workforceDotEvents:
          PlaceWorkforceSchedule.calendarDotEventsFromSiteAndCosts(
        byDay: Map<String, ({bool sch, bool work})>.from(_markerByDay),
        costDayKeys: Set<String>.from(_markerCostDayKeys),
        eventIdPrefix: 'gwf_',
      ),
    );
  }

  Future<void> _ensureCalendarMarkersLoaded(DateTime anchor) async {
    final range = calendarMarkerRangeAroundMonth(anchor);
    final key = _markerRangeKey(range.from, range.to);
    if (_loadedMarkerRangeKeys.contains(key)) return;
    if (_markersInFlight != null && _markersInFlightKey == key) {
      return _markersInFlight!;
    }

    final job = _loadCalendarMarkersBody(range.from, range.to, key);
    _markersInFlightKey = key;
    _markersInFlight = job;
    try {
      await job;
    } finally {
      if (identical(_markersInFlight, job)) {
        _markersInFlight = null;
        _markersInFlightKey = null;
      }
    }
  }

  Future<void> _loadCalendarMarkersBody(
    String from,
    String to,
    String key,
  ) async {
    try {
      final dots = await _calendarUseCase.getCalendarMarkers(
        from: from,
        to: to,
      );
      _loadedMarkerRangeKeys.add(key);
      _mergeMarkerPayload(dots);
      _publishMarkerDotEvents();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('calendar markers failed: $e\n$st');
      }
      if (ref.mounted && _markerByDay.isEmpty && _markerCostDayKeys.isEmpty) {
        state = state.copyWith(workforceDotEvents: const []);
      }
    }
  }

  /// 월 스크롤·페이지 전환 — 보이는 달 ±1달 마커 lazy load.
  Future<void> onCalendarVisibleMonthChanged(DateTime anchor) async {
    await _ensureCalendarMarkersLoaded(anchor);
  }

  /// [FetchData] 등 — 현재 포커스 월 마커만 갱신.
  Future<void> refreshCalendarMarkers() async {
    final anchor = state.focusedDay;
    final range = calendarMarkerRangeAroundMonth(anchor);
    _loadedMarkerRangeKeys.remove(_markerRangeKey(range.from, range.to));
    await _ensureCalendarMarkersLoaded(anchor);
  }

  Future<void> fetchTotalCost() async {
    await _fetchTotalCostForDay(state.focusedDay);
  }

  Future<void> _fetchTotalCostForDay(DateTime day) async {
    final key = dateKeyYmd(day);
    final gen = ++_dayCostFetchGeneration;
    final cached = _dayCostCache[key];

    if (cached != null) {
      _applyDayCostCache(day, cached);
    } else if (ref.mounted && dateKeyYmd(state.focusedDay) == key) {
      state = state.copyWith(
        dayCostIsLoading: true,
        totalCostList: const [],
        dayCostHasMore: false,
        clearDayCostNextCursor: true,
        clearDayCostTotals: true,
      );
    }

    try {
      final page = await _calendarUseCase.getTotalCostsByDatePage(day);
      if (!ref.mounted || gen != _dayCostFetchGeneration) return;
      if (dateKeyYmd(state.focusedDay) != key) return;

      final entry = _CalendarDayCostCacheEntry(
        items: page.items,
        hasMore: page.canLoadMore,
        nextCursor: page.nextCursor,
        totals: page.totals ??
            (page.items.isEmpty
                ? null
                : CalendarDayCostTotals.fromItems(page.items)),
      );
      _dayCostCache[key] = entry;
      _applyDayCostCache(day, entry);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('calendar day costs failed: $e\n$st');
      }
      if (ref.mounted &&
          gen == _dayCostFetchGeneration &&
          dateKeyYmd(state.focusedDay) == key) {
        state = state.copyWith(
          totalCostList: const [],
          dayCostIsLoading: false,
        );
      }
    }
  }

  Future<void> loadMoreDayCosts() async {
    if (!state.dayCostHasMore || state.dayCostIsLoadingMore) return;
    if (_loadMoreDayCostsInFlight != null) return _loadMoreDayCostsInFlight;

    _loadMoreDayCostsInFlight = _loadMoreDayCostsBody();
    try {
      await _loadMoreDayCostsInFlight;
    } finally {
      _loadMoreDayCostsInFlight = null;
    }
  }

  Future<void> _loadMoreDayCostsBody() async {
    final cursor = state.dayCostNextCursor;
    if (cursor == null || cursor.isEmpty) return;

    state = state.copyWith(dayCostIsLoadingMore: true);
    try {
      final page = await _calendarUseCase.getTotalCostsByDatePage(
        state.focusedDay,
        cursor: cursor,
      );
      if (!ref.mounted) return;
      final merged = mergePagedItems(
        state.totalCostList,
        page.items,
        (e) => Object.hash(e.category, e.id),
      );
      final key = dateKeyYmd(state.focusedDay);
      _dayCostCache[key] = _CalendarDayCostCacheEntry(
        items: merged,
        hasMore: page.canLoadMore,
        nextCursor: page.nextCursor,
        totals: state.dayCostTotals,
      );
      state = state.copyWith(
        totalCostList: merged,
        dayCostHasMore: page.canLoadMore,
        dayCostNextCursor: page.nextCursor,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('calendar day costs loadMore failed: $e\n$st');
      }
    } finally {
      if (ref.mounted) {
        state = state.copyWith(dayCostIsLoadingMore: false);
      }
    }
  }

  Future<void> onDaySelected(DateTime selectedDay, DateTime focused) async {
    state = state.copyWith(
      selectedDay: selectedDay,
      focusedDay: selectedDay,
    );
    await Future.wait([
      fetchTotalCost(),
      _ensureCalendarMarkersLoaded(selectedDay),
    ]);
  }

  Future<void> _syncLikeFetchAllData({required DataChangeKind kind}) async {
    _invalidateDayCostCache(state.focusedDay);
    await fetchTotalCost();
    if (kind == DataChangeKind.workCost) {
      await refreshCalendarMarkers();
    }
    FetchData.onDataChanged(
      DataChangeEvent(
        kind,
        date: state.focusedDay,
      ).withoutCalendarRefresh(),
    );
  }

  Future<void> deleteCost(String category, int id) async {
    if (category == 'w') {
      await _workCostUseCase.deleteWorkCost(id);
    } else {
      await _materialCostUseCase.deleteMaterialCost(id);
    }
    await _syncLikeFetchAllData(
      kind: category == 'w'
          ? DataChangeKind.workCost
          : DataChangeKind.materialCost,
    );
  }

  Future<int?> placeWorkDayPwdidForWorkCost(TotalCostModel item) {
    final hid = item.whid;
    final pid = item.wpid;
    if (hid == null || pid == null) return Future.value(null);
    final dateKey =
        item.date.length >= 10 ? item.date.substring(0, 10) : item.date;
    return _workCostUseCase.findPlaceWorkDayPwdid(
      pid: pid,
      hid: hid,
      dateKey: dateKey,
    );
  }

  Future<void> deleteWorkCostLinked({
    required int wid,
    int? pwdid,
  }) async {
    await _workCostUseCase.deleteWorkCostLinked(wid: wid, pwdid: pwdid);
    await _syncLikeFetchAllData(kind: DataChangeKind.workCost);
  }

  Future<bool> updateCost(String category, int id, String date) async {
    var priceString = mPriceController.text.trim();
    priceString = priceString.replaceAll(RegExp(r'[,원]'), '');
    final price = int.tryParse(priceString);

    if (category != 'w') {
      if (mNameController.text.isEmpty || price == null) {
        state = state.copyWith(alertText: '모든 항목을 입력해 주세요.');
        return false;
      }
      final cat = state.dropDownSelectedCategory;
      if (cat == null) {
        state = state.copyWith(alertText: '모든 항목을 입력해 주세요.');
        return false;
      }
      state = state.copyWith(alertText: '');
      final materialCost = MaterialCostModel(
        mid: id,
        mname: mNameController.text.trim(),
        mdate: date,
        mcategory: cat,
        mprice: price,
      );
      await _materialCostUseCase.updateMaterialCostItem(materialCost);
      await _syncLikeFetchAllData(kind: DataChangeKind.materialCost);
      return true;
    }
    if (price == null) {
      state = state.copyWith(alertText: '모든 항목을 입력해 주세요.');
      return false;
    }
    state = state.copyWith(alertText: '');
    final workCost = WorkCostModel(
      wid: id,
      wdate: date,
      wprice: price,
      wcomplete: -1,
      wpid: 1,
    );
    await _workCostUseCase.updateWorkCostItem(workCost);
    await _syncLikeFetchAllData(kind: DataChangeKind.workCost);
    return true;
  }

  Future<String> updateWComplete(int wcomplete, int id) async {
    await _workCostUseCase.toggleWorkCostCompletionStatus(wcomplete, id);
    await _syncLikeFetchAllData(kind: DataChangeKind.workCost);
    return wcomplete == 1 ? '미지급으로 변경되었습니다.' : '완료로 변경되었습니다.';
  }

  void categoryChangeAction(String value) {
    state = state.copyWith(dropDownSelectedCategory: value);
  }

  void clearEditAlert() {
    state = state.copyWith(alertText: '');
  }

  void prepareEditDialog(TotalCostModel element) {
    mNameController.text = element.name;
    mPriceController.text = getPrice(price: element.price, isContainWon: false);
    state = state.copyWith(
      dialogDateTime: DateTime.parse(element.date),
      dropDownSelectedCategory: element.category,
      alertText: '',
    );
  }

  Future<void> pickDialogDate(BuildContext context) async {
    final picked = await showDatePickerDialog(
      context: context,
      minDate: DateTime(2000),
      maxDate: DateTime(2099),
    );
    if (picked != null) {
      state = state.copyWith(dialogDateTime: picked);
    }
  }
}

/// 현장별 일자 비용 요약 (캘린더 접힌 타일).
class PlaceDayCostSummary {
  const PlaceDayCostSummary({
    required this.workAmount,
    required this.materialAmount,
    required this.paidAmount,
    required this.unpaidAmount,
  });

  final int workAmount;
  final int materialAmount;
  final int paidAmount;
  final int unpaidAmount;

  int get totalAmount => workAmount + materialAmount;
}
