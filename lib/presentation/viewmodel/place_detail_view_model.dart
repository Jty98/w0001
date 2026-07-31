import 'dart:async' show unawaited;
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/data/datasources/remote/auth/users_api.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/data/model/paged_result.dart' show mergePagedItems;
import 'package:w0001/data/model/revenue_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/data/repository/materialcost_impl.dart';
import 'package:w0001/data/repository/revenue_impl.dart';
import 'package:w0001/data/repository/workcost_impl.dart';
import 'package:w0001/domain/repository/materialcost_abst.dart';
import 'package:w0001/domain/repository/revenue_abst.dart';
import 'package:w0001/domain/repository/workcost_abst.dart';
import 'package:w0001/domain/use_case/materialcost_use_case.dart';
import 'package:w0001/domain/use_case/revenue_use_case.dart';
import 'package:w0001/domain/use_case/workcost_use_case.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show placeUseCaseProvider;
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:scrollable_calendar_package/calendar.dart';
import 'package:w0001/util/concurrent_task_runner.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/image_attachment/upload_image_remote.dart';

/// 선수금 제외 추가 수익 기본 라벨: `1차 잔금`, `2차 잔금`, …
/// 수익 입력은 [PlaceRevenueScreen] 쪽 `TextEditingController`에서 관리(Provider dispose와 분리).
String nextJangeumLabelForRevenueList(List<RevenueModel> list) {
  return '${list.length + 1}차 잔금';
}

/// 현장 사진·문서 묶음 API 페이지 크기 — [kListPageSize]와 동일.
const int kPhotoGroupPageSize = kListPageSize;

/// `site` / `drawing` / `estimate` 탭별 사진·문서 목록 캐시.
class PhotoGroupsTabCache {
  const PhotoGroupsTabCache({
    this.items = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.isRefreshing = false,
    this.initialLoadDone = false,
    this.nextCursor,
    this.totalCount,
  });

  final List<PlacePhotoGroupModel> items;
  final bool hasMore;
  final bool loadingMore;
  final bool isRefreshing;
  final bool initialLoadDone;
  final String? nextCursor;
  final int? totalCount;

  PhotoGroupsTabCache copyWith({
    List<PlacePhotoGroupModel>? items,
    bool? hasMore,
    bool? loadingMore,
    bool? isRefreshing,
    bool? initialLoadDone,
    String? nextCursor,
    bool clearNextCursor = false,
    int? totalCount,
    bool clearTotalCount = false,
  }) {
    return PhotoGroupsTabCache(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      initialLoadDone: initialLoadDone ?? this.initialLoadDone,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      totalCount: clearTotalCount ? null : (totalCount ?? this.totalCount),
    );
  }
}

class PlaceDetailState {
  const PlaceDetailState({
    required this.pid,
    required this.dateTimeRange,
    required this.toggleState,
    required this.selectedDayType,
    required this.selectedFilterType,
    required this.selectedDropdownCategory,
    required this.dialogDateTime,
    required this.revenuePickedDay,
    required this.dialogRevenuePickedDay,
    required this.photoPickedDay,
    required this.totalCostList,
    required this.revenueList,
    required this.photoGroupsByType,
    required this.loadedPlacePhotoType,
    required this.alertText,
    required this.isLoading,
    required this.costCache,
  });

  final int pid;
  final DateTimeRange dateTimeRange;
  final List<bool> toggleState;
  final DayTpye selectedDayType;
  final FilterType selectedFilterType;
  final String? selectedDropdownCategory;
  final DateTime dialogDateTime;

  /// 추가 수익 등록용. `null`이면 아직 캘린더에서 날짜를 확정하지 않은 상태.
  final DateTime? revenuePickedDay;
  final DateTime dialogRevenuePickedDay;
  final DateTime photoPickedDay;
  final List<TotalCostModel> totalCostList;
  final List<RevenueModel> revenueList;
  final Map<String, PhotoGroupsTabCache> photoGroupsByType;
  final String loadedPlacePhotoType;
  final String alertText;
  final bool isLoading;

  /// 기간별 비용 데이터 캐시 (키: "startDate_endDate" 형식)
  final Map<String, List<TotalCostModel>> costCache;

  PhotoGroupsTabCache _tab(String photoType) =>
      photoGroupsByType[photoType] ?? const PhotoGroupsTabCache();

  List<PlacePhotoGroupModel> get photoGroupList =>
      _tab(loadedPlacePhotoType).items;

  bool get photoGroupsHasMore => _tab(loadedPlacePhotoType).hasMore;

  bool get photoGroupsLoadingMore => _tab(loadedPlacePhotoType).loadingMore;

  bool get photoGroupsRefreshing => _tab(loadedPlacePhotoType).isRefreshing;

  String? get photoGroupsNextCursor => _tab(loadedPlacePhotoType).nextCursor;

  int? get photoGroupsTotalCount => _tab(loadedPlacePhotoType).totalCount;

  factory PlaceDetailState.initial(int pid) => PlaceDetailState(
        pid: pid,
        dateTimeRange: getMonthDateRange(DateTime.now()),
        toggleState: const [false, false, true],
        selectedDayType: DayTpye.month,
        selectedFilterType: FilterType.all,
        selectedDropdownCategory: null,
        dialogDateTime: DateTime.now(),
        revenuePickedDay: null,
        dialogRevenuePickedDay: DateTime.now(),
        photoPickedDay: DateTime.now(),
        totalCostList: const [],
        revenueList: const [],
        photoGroupsByType: const {},
        loadedPlacePhotoType: 'site',
        alertText: '',
        isLoading: false,
        costCache: const {},
      );

  PlaceDetailState copyWith({
    DateTimeRange? dateTimeRange,
    List<bool>? toggleState,
    DayTpye? selectedDayType,
    FilterType? selectedFilterType,
    String? selectedDropdownCategory,
    DateTime? dialogDateTime,
    DateTime? revenuePickedDay,
    bool setRevenuePicked = false,
    DateTime? dialogRevenuePickedDay,
    DateTime? photoPickedDay,
    List<TotalCostModel>? totalCostList,
    List<RevenueModel>? revenueList,
    Map<String, PhotoGroupsTabCache>? photoGroupsByType,
    String? loadedPlacePhotoType,
    String? alertText,
    bool? isLoading,
    Map<String, List<TotalCostModel>>? costCache,
  }) {
    return PlaceDetailState(
      pid: pid,
      dateTimeRange: dateTimeRange ?? this.dateTimeRange,
      toggleState: toggleState ?? this.toggleState,
      selectedDayType: selectedDayType ?? this.selectedDayType,
      selectedFilterType: selectedFilterType ?? this.selectedFilterType,
      selectedDropdownCategory:
          selectedDropdownCategory ?? this.selectedDropdownCategory,
      dialogDateTime: dialogDateTime ?? this.dialogDateTime,
      revenuePickedDay:
          setRevenuePicked ? revenuePickedDay : this.revenuePickedDay,
      dialogRevenuePickedDay:
          dialogRevenuePickedDay ?? this.dialogRevenuePickedDay,
      photoPickedDay: photoPickedDay ?? this.photoPickedDay,
      totalCostList: totalCostList ?? this.totalCostList,
      revenueList: revenueList ?? this.revenueList,
      photoGroupsByType: photoGroupsByType ?? this.photoGroupsByType,
      loadedPlacePhotoType: loadedPlacePhotoType ?? this.loadedPlacePhotoType,
      alertText: alertText ?? this.alertText,
      isLoading: isLoading ?? this.isLoading,
      costCache: costCache ?? this.costCache,
    );
  }
}

final workCostRepositoryProvider = Provider<WorkCostRepository>(
  (ref) => WorkCostRepositoryImpl(ref.read(superAdminRemoteRepositoryProvider)),
);
final workCostUseCaseProvider = Provider<WorkCostUseCase>(
  (ref) => WorkCostUseCase(ref.read(workCostRepositoryProvider)),
);

final materialCostRepositoryProvider = Provider<MaterialCostRepository>(
  (ref) =>
      MaterialCostRepositoryImpl(ref.read(superAdminRemoteRepositoryProvider)),
);
final materialCostUseCaseProvider = Provider<MaterialCostUseCase>(
  (ref) => MaterialCostUseCase(ref.read(materialCostRepositoryProvider)),
);

final revenueRepositoryProvider = Provider<RevenueRepository>(
  (ref) => RevenueRepositoryImpl(ref.read(superAdminRemoteRepositoryProvider)),
);
final revenueUseCaseProvider = Provider<RevenueUseCase>(
  (ref) => RevenueUseCase(ref.read(revenueRepositoryProvider)),
);

final placeDetailProvider =
    NotifierProvider.family<PlaceDetailViewModel, PlaceDetailState, int>(
  PlaceDetailViewModel.new,
);

class PlaceDetailViewModel extends Notifier<PlaceDetailState> {
  PlaceDetailViewModel(this.pid);

  final int pid;
  late final _placeUseCase = ref.read(placeUseCaseProvider);
  late final _revenueUseCase = ref.read(revenueUseCaseProvider);
  late final _workCostUseCase = ref.read(workCostUseCaseProvider);
  late final _materialCostUseCase = ref.read(materialCostUseCaseProvider);

  bool _initialized = false;
  int _photoFetchToken = 0;
  Future<void>? _loadMorePhotosInFlight;

  // 수익(추가/수정) TextEditingController는 [PlaceRevenueScreen] State에서 수명 관리(Provider와 분리)
  final TextEditingController mNameController = TextEditingController();
  final TextEditingController mPriceController = TextEditingController();
  final TextEditingController photoTitleController = TextEditingController();
  final TextEditingController photoUrlsController = TextEditingController();

  @override
  PlaceDetailState build() {
    ref.onDispose(() {
      mNameController.dispose();
      mPriceController.dispose();
      photoTitleController.dispose();
      photoUrlsController.dispose();
    });

    if (!_initialized) {
      _initialized = true;
      Future.microtask(() async {
        // 작업자는 전역 work-cost / revenue 조회 API가 막혀 있을 수 있음.
        // 사진 등 일부 화면만 쓸 때 불필요한 403·예외를 막기 위해 로드하지 않는다.
        final worker =
            ref.read(authSessionProvider).asData?.value?.isWorker ?? false;
        if (!worker) {
          await fetchTotalCostFromPlace();
          await fetchAllRevenueFromPlace();
        }
        // 문서 탭 종류(site/drawing/estimate)는 [PlaceImagesScreen] 등 각 화면에서
        // 첫 진입 시점의 탭에 맞춰 fetch한다. 여기서 site를 강제로 불러오면
        // 사용자가 도면 탭으로 바꾼 직후 비동기로 site 결과가 덮어씌워진다.
      });
    }
    return PlaceDetailState.initial(pid);
  }

  void setDialogDateTime(DateTime value) {
    state = state.copyWith(dialogDateTime: value);
  }

  void setRevenuePickedDay(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    state = state.copyWith(
      revenuePickedDay: d,
      setRevenuePicked: true,
    );
  }

  void setDialogRevenuePickedDay(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    state = state.copyWith(dialogRevenuePickedDay: d);
  }

  void setPhotoPickedDay(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    state = state.copyWith(photoPickedDay: d);
  }

  void clearAlertText() {
    state = state.copyWith(alertText: '');
  }

  /// 금액 변동이 있는 날짜를 CalendarEvent 리스트로 변환
  List<CalendarEvent> _getUniqueDateEventsFromCosts() {
    final uniqueDates = <DateTime>{};

    // 모든 비용 항목에서 날짜 추출
    for (final cost in state.totalCostList) {
      try {
        final date = DateTime.parse(cost.date);
        final dateOnly = DateTime(date.year, date.month, date.day);
        uniqueDates.add(dateOnly);
      } catch (_) {
        // 날짜 파싱 실패 시 무시
      }
    }

    // 각 날짜를 CalendarEvent로 변환
    return uniqueDates.map((date) {
      return CalendarEvent(
        startDate: date,
        endDate: date,
        title: '금액 변동',
        color: Colors.orange.withValues(alpha: 0.7),
      );
    }).toList();
  }

  Future<DateTimeRange?> _pickRangeWithScrollableCalendar(
    BuildContext context,
  ) async {
    // 다이얼로그는 항상 초기화된 상태(미선택)로 시작해
    // 다른 화면에서 사용한 범위가 남아 보이지 않도록 한다.
    DateTime? rangeStart;
    DateTime? rangeEnd;

    // ✅ 금액 변동이 있는 날짜를 이벤트로 변환
    final transactionDates = _getUniqueDateEventsFromCosts();

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
                        initialEvents: transactionDates, // ✅ 금액 변동일 표시
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

  // ===== computed (기존 controller getter 대체) =====

  List<TotalCostModel> get rangeFilterList => state.totalCostList
      .where((e) =>
          e.getDateTime.isAfter(state.dateTimeRange.start
              .subtract(const Duration(microseconds: 1))) &&
          e.getDateTime
              .isBefore(state.dateTimeRange.end.add(const Duration(days: 1))))
      .toList();

  int get totalPrice => rangeFilterList.fold(0, (sum, e) => sum + e.price);

  int get totalRevenue => state.revenueList.fold(0, (sum, e) => sum + e.rprice);

  List<TotalCostModel> get filteredTotalCostList {
    switch (state.selectedFilterType) {
      case FilterType.all:
        return rangeFilterList;
      case FilterType.work:
        return rangeFilterList.where((e) => e.category == 'w').toList()
          ..sort((a, b) => a.wcomplete.compareTo(b.wcomplete));
      case FilterType.material:
        return rangeFilterList.where((e) => e.category != 'w').toList();
      case FilterType.notPay:
        return rangeFilterList.where((e) => e.wcomplete == 0).toList();
      default:
        return rangeFilterList
            .where((e) => e.category == state.selectedFilterType.category)
            .toList();
    }
  }

  int get selectedPrice =>
      filteredTotalCostList.fold(0, (sum, e) => sum + e.price);

  // ===== actions =====

  /// 비용 화면에서 수익 화면으로 갔다 돌아올 때: 날짜만 초기화(입력 필드는 수익 화면 dispose로 끊김).
  void clearRevenuePickedOnLeaveRevenueScreen() {
    state = state.copyWith(
      revenuePickedDay: null,
      setRevenuePicked: true,
    );
  }

  void _resetRevenueFormAfterInsert() {
    state = state.copyWith(
      revenuePickedDay: null,
      setRevenuePicked: true,
    );
  }

  void dropDownCategoryChangeAction(String value) {
    state = state.copyWith(selectedDropdownCategory: value);
  }

  void changeFilterType(FilterType filterType) {
    state = state.copyWith(selectedFilterType: filterType);
  }

  /// 날짜 범위를 캐시 키로 변환
  String _getCacheKey(DateTimeRange range) {
    final start = range.start.toIso8601String().substring(0, 10);
    final end = range.end.toIso8601String().substring(0, 10);
    return '${start}_$end';
  }

  /// 비용 데이터 조회 (캐싱 지원)
  ///
  /// [forceRefresh]: true면 캐시를 무시하고 서버에서 새로 가져옴
  /// [silent]: true면 로딩 인디케이터를 표시하지 않음
  Future<void> fetchTotalCostFromPlace({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    if (ref.read(authSessionProvider).asData?.value?.isWorker ?? false) {
      state = state.copyWith(totalCostList: const [], isLoading: false);
      return;
    }

    final r = state.dateTimeRange;
    final cacheKey = _getCacheKey(r);

    // ✅ 캐시 확인 (forceRefresh가 false일 때만)
    if (!forceRefresh && state.costCache.containsKey(cacheKey)) {
      print('✅ [금액관리] 캐시 사용: $cacheKey');
      final cachedList = state.costCache[cacheKey]!;
      state = state.copyWith(
        totalCostList: cachedList,
        isLoading: false,
      );
      return;
    }

    // 🌐 서버에서 데이터 조회
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

    print('🌐 [금액관리] API 호출: $cacheKey (forceRefresh: $forceRefresh)');

    try {
      final list = await _placeUseCase.getTotalCostsForPlace(
        pid,
        from: r.start,
        to: r.end,
      );

      // ✅ 캐시에 저장
      final updatedCache =
          Map<String, List<TotalCostModel>>.from(state.costCache);
      updatedCache[cacheKey] = list;

      state = state.copyWith(
        totalCostList: list,
        isLoading: false,
        costCache: updatedCache,
      );

      print('✅ [금액관리] 데이터 로드 완료: ${list.length}건, 캐시 저장됨');
    } catch (e) {
      print('❌ [금액관리] 데이터 로드 실패: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchAllRevenueFromPlace() async {
    if (ref.read(authSessionProvider).asData?.value?.isWorker ?? false) {
      state = state.copyWith(revenueList: const []);
      return;
    }
    final list = await _revenueUseCase.getAllRevenues(pid);
    state = state.copyWith(revenueList: list);
  }

  /// 비용 저장·삭제 후 — 비용 목록만 다시 읽는다 (캐시 무효화).
  Future<void> refreshCostsForGlobalFetch() async {
    if (ref.read(authSessionProvider).asData?.value?.isWorker ?? false) {
      return;
    }
    // 캐시 무효화 후 새로 가져오기
    await fetchTotalCostFromPlace(silent: true, forceRefresh: true);
  }

  Future<void> refreshRevenueForGlobalFetch() async {
    if (ref.read(authSessionProvider).asData?.value?.isWorker ?? false) {
      return;
    }
    await fetchAllRevenueFromPlace();
  }

  Future<void> refreshPhotosForGlobalFetch() async {
    await refreshPlacePhotoGroups();
  }

  /// [FetchData.fetchAllData]용: `invalidate`로 notifier를 끊지 않고 목록·비용·사진만 다시 읽는다. (TextEditingController 유지)
  Future<void> refreshForGlobalFetch() async {
    final worker =
        ref.read(authSessionProvider).asData?.value?.isWorker ?? false;
    if (!worker) {
      await fetchTotalCostFromPlace(silent: true, forceRefresh: true);
      await fetchAllRevenueFromPlace();
    }
    await refreshPlacePhotoGroups();
  }

  Future<void> deleteRevenue({required int rid}) async {
    await _revenueUseCase.deleteRevenue(rid, pid);
    await fetchAllRevenueFromPlace();
  }

  PhotoGroupsTabCache _photoCacheFor(String photoType) =>
      state.photoGroupsByType[photoType] ?? const PhotoGroupsTabCache();

  void _setPhotoCache(String photoType, PhotoGroupsTabCache cache) {
    state = state.copyWith(
      photoGroupsByType: {...state.photoGroupsByType, photoType: cache},
    );
  }

  /// 탭 전환 — 캐시가 있으면 즉시 표시, 없을 때만 API 호출.
  void switchPlacePhotoType(String photoType) {
    state = state.copyWith(loadedPlacePhotoType: photoType);
    final cached = _photoCacheFor(photoType);
    if (!cached.initialLoadDone) {
      fetchPlacePhotoGroups(photoType: photoType);
    }
  }

  Future<void> refreshPlacePhotoGroups({String? photoType}) {
    return fetchPlacePhotoGroups(
      photoType: photoType ?? state.loadedPlacePhotoType,
      force: true,
    );
  }

  Future<void> fetchPlacePhotoGroups({
    required String photoType,
    bool force = false,
  }) async {
    final cached = _photoCacheFor(photoType);
    if (!force && cached.initialLoadDone) {
      state = state.copyWith(loadedPlacePhotoType: photoType);
      return;
    }

    final fetchToken = ++_photoFetchToken;
    _setPhotoCache(
      photoType,
      cached.copyWith(
        isRefreshing: true,
        loadingMore: false,
        items: force ? cached.items : const [],
        hasMore: force ? cached.hasMore : false,
        clearNextCursor: !force,
        clearTotalCount: !force,
      ),
    );
    state = state.copyWith(loadedPlacePhotoType: photoType);

    try {
      final page = await _placeUseCase.fetchPlacePhotoGroupsPage(
        pid,
        photoType: photoType,
        query: const ListQuery(limit: kPhotoGroupPageSize),
      );
      var groups = await _enrichPhotoAuthors(page.items);
      if (fetchToken != _photoFetchToken) return;
      _setPhotoCache(
        photoType,
        PhotoGroupsTabCache(
          items: groups,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          totalCount: page.totalCount,
          initialLoadDone: true,
        ),
      );
    } catch (e, st) {
      debugPrint('fetchPlacePhotoGroups failed: $e\n$st');
      if (fetchToken != _photoFetchToken) return;
      if (force && cached.initialLoadDone) {
        _setPhotoCache(
          photoType,
          cached.copyWith(isRefreshing: false),
        );
      } else {
        _setPhotoCache(
          photoType,
          const PhotoGroupsTabCache(initialLoadDone: true),
        );
      }
    }
  }

  /// 스크롤 하단 — 사진·문서 묶음 다음 페이지.
  Future<void> loadMorePlacePhotoGroups() async {
    if (!state.photoGroupsHasMore || state.photoGroupsLoadingMore) return;
    if (_loadMorePhotosInFlight != null) return _loadMorePhotosInFlight;

    final cursor = state.photoGroupsNextCursor;
    if (cursor == null || cursor.isEmpty) return;

    _loadMorePhotosInFlight = _loadMorePlacePhotoGroupsBody();
    try {
      await _loadMorePhotosInFlight;
    } finally {
      _loadMorePhotosInFlight = null;
    }
  }

  Future<void> _loadMorePlacePhotoGroupsBody() async {
    final fetchToken = _photoFetchToken;
    final photoType = state.loadedPlacePhotoType;
    final tab = _photoCacheFor(photoType);
    _setPhotoCache(photoType, tab.copyWith(loadingMore: true));
    try {
      final page = await _placeUseCase.fetchPlacePhotoGroupsPage(
        pid,
        photoType: photoType,
        query: ListQuery(
          limit: kPhotoGroupPageSize,
          cursor: tab.nextCursor,
        ),
      );
      var groups = await _enrichPhotoAuthors(page.items);
      if (fetchToken != _photoFetchToken) return;
      final merged = _photoCacheFor(photoType);
      _setPhotoCache(
        photoType,
        merged.copyWith(
          items: mergePagedItems(merged.items, groups, (g) => g.pgid),
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          totalCount: page.totalCount ?? merged.totalCount,
          loadingMore: false,
        ),
      );
    } catch (e, st) {
      debugPrint('loadMorePlacePhotoGroups failed: $e\n$st');
    } finally {
      if (fetchToken == _photoFetchToken) {
        final tabNow = _photoCacheFor(photoType);
        if (tabNow.loadingMore) {
          _setPhotoCache(photoType, tabNow.copyWith(loadingMore: false));
        }
      }
    }
  }

  Future<List<PlacePhotoGroupModel>> _enrichPhotoAuthors(
    List<PlacePhotoGroupModel> groups,
  ) async {
    final me = ref.read(authSessionProvider).asData?.value;
    final names = <String, String>{};
    if (me != null && me.uid.isNotEmpty && me.uname.isNotEmpty) {
      names[me.uid] = me.uname;
    }

    final toFetch = <String>{};
    for (final g in groups) {
      for (final p in g.photos) {
        final u = p.createdByUid;
        if (u == null || u.isEmpty) continue;
        final inline = p.authorDisplayName?.trim();
        if (inline != null && inline.isNotEmpty) continue;
        if (!names.containsKey(u)) toFetch.add(u);
      }
    }

    if (toFetch.isNotEmpty) {
      final api = UsersRemoteApi(AppHttpClient.I);
      final uids = toFetch.toList();
      final fetched = await runWithConcurrencyLimit<String?>(
        uids.map(
          (u) => () async {
            try {
              final user = await api.get(u);
              return user.uname;
            } catch (_) {
              return null;
            }
          },
        ),
        limit: 6,
      );
      for (var i = 0; i < uids.length; i++) {
        final name = fetched[i];
        if (name != null && name.isNotEmpty) {
          names[uids[i]] = name;
        }
      }
    }

    return groups
        .map(
          (g) => PlacePhotoGroupModel(
            pgid: g.pgid,
            pid: g.pid,
            photoDate: g.photoDate,
            photoType: g.photoType,
            title: g.title,
            sortOrder: g.sortOrder,
            createdAtMs: g.createdAtMs,
            photos: g.photos.map(
              (e) {
                final uid = e.createdByUid;
                var display = e.authorDisplayName?.trim();
                if (display == null || display.isEmpty) {
                  if (uid != null && uid.isNotEmpty) {
                    display = names[uid];
                  }
                }
                return PlacePhotoEntry(
                  phid: e.phid,
                  displayUrl: e.displayUrl,
                  originalName: e.originalName,
                  originalUrl: e.originalUrl,
                  mediaKind: e.mediaKind,
                  createdByUid: e.createdByUid,
                  authorDisplayName: display,
                  memo: e.memo,
                );
              },
            ).toList(),
          ),
        )
        .toList();
  }

  Future<void> deletePlacePhotoGroup(int pgid,
      {required String photoType}) async {
    await _placeUseCase.deletePlacePhotoGroup(pgid, pid: pid);
    await fetchPlacePhotoGroups(photoType: photoType, force: true);
  }

  Future<String?> patchPlacePhotoMemo({
    required int phid,
    required String memo,
    required String photoType,
  }) =>
      patchPlacePhoto(
        phid: phid,
        memo: memo,
        photoType: photoType,
      );

  /// 메모 수정·선택적으로 로컬에서 새 파일 업로드 후 이미지 URL 교체.
  /// 성공 시 `null`, 실패 시 스낵바용 문구.
  Future<String?> patchPlacePhoto({
    required int phid,
    required String photoType,
    required String memo,
    String? replacementLocalPath,
  }) async {
    try {
      String? displayUrl;
      String? originalUrl;
      String? originalname;
      final rp = replacementLocalPath?.trim();
      if (rp != null && rp.isNotEmpty) {
        final up = await uploadLocalImageFile(
          rp,
          category: ImageUploadCategory.fromPlacePhotoType(photoType),
        );
        displayUrl = up.displayUrl;
        originalUrl = up.originalUrl;
        originalname = up.originalname;
      }
      await _placeUseCase.patchPlacePhoto(
        phid,
        memo: memo,
        displayUrl: displayUrl,
        originalUrl: originalUrl,
        originalname: originalname,
      );
      await fetchPlacePhotoGroups(photoType: photoType, force: true);
      return null;
    } catch (e) {
      final h = unwrapHttpClientException(e);
      return h?.message ?? e.toString();
    }
  }

  /// 묶음 작업명·업로드일(yyyy-MM-dd) 수정.
  Future<String?> patchPlacePhotoGroupMeta({
    required int pgid,
    required String photoType,
    String? title,
    String? photoDate,
  }) async {
    try {
      await _placeUseCase.patchPlacePhotoGroupMeta(
        pgid,
        title: title,
        photoDate: photoDate,
      );
      await fetchPlacePhotoGroups(photoType: photoType, force: true);
      return null;
    } catch (e) {
      final h = unwrapHttpClientException(e);
      return h?.message ?? e.toString();
    }
  }

  Future<void> addPlacePhotoGroup({required String photoType}) async {
    final title = photoTitleController.text.trim();
    final urls = photoUrlsController.text
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (urls.isEmpty) {
      state = state.copyWith(alertText: '이미지 URL을 한 개 이상 입력해주세요.');
      return;
    }
    state = state.copyWith(alertText: '');
    await _placeUseCase.insertPlacePhotoGroup(
      pid: pid,
      photoDate: formatDateTimeToIsoDate(state.photoPickedDay),
      photoType: photoType,
      title: title.isEmpty ? '사진 묶음' : title,
      photoUrls: urls,
    );
    photoTitleController.clear();
    photoUrlsController.clear();
    await fetchPlacePhotoGroups(photoType: photoType, force: true);
  }

  /// 기기에서 고른 이미지 경로를 업로드 후 `PlacePhoto` 행으로 저장. 실패 시 안내 문구.
  Future<String?> addPlacePhotoGroupFromDeviceFiles({
    required String photoType,
    required DateTime photoDate,
    required List<String> localPaths,
    List<String>? memosPerFile,
  }) async {
    if (localPaths.isEmpty) {
      return '첨부된 이미지가 없습니다.';
    }
    final title = photoTitleController.text.trim();
    state = state.copyWith(alertText: '');
    try {
      await _placeUseCase.insertPlacePhotoGroupFromDeviceFiles(
        pid: pid,
        photoDate: formatDateTimeToIsoDate(photoDate),
        photoType: photoType,
        title: title.isEmpty ? '사진 묶음' : title,
        localFilePaths: localPaths,
        memosPerFile: memosPerFile,
      );
      photoTitleController.clear();
      photoUrlsController.clear();
      await fetchPlacePhotoGroups(photoType: photoType, force: true);
      return null;
    } on HttpClientException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> updateRevenue({
    required int rid,
    required String rname,
    required int rprice,
    required DateTime revenueDate,
  }) async {
    final model = RevenueModel(
      rid: rid,
      rpid: -1,
      rname: rname.trim().isEmpty ? '수익금' : rname.trim(),
      rprice: rprice,
      rorder: -1,
      rdate: formatDateTimeToIsoDate(revenueDate),
    );
    await _revenueUseCase.updateRevenue(revenue: model, placeId: state.pid);
    await fetchAllRevenueFromPlace();
  }

  /// 성공 시 `null`, 실패 시 안내 문구(스낵바 등에 사용).
  /// [rnameOrEmpty]·[rpriceRaw]는 수익 화면 `TextEditingController`에서 전달.
  Future<String?> insertRevenue({
    required String rnameOrEmpty,
    required String rpriceRaw,
  }) async {
    if (state.revenuePickedDay == null) {
      return '날짜를 선택해주세요';
    }
    final priceTokens = rpriceRaw.trim().replaceAll(RegExp(r'[,원]'), '');
    if (priceTokens.isEmpty) {
      return '수익금을 입력해주세요';
    }
    final rprice = int.tryParse(priceTokens) ?? 0;
    final trimmedName = rnameOrEmpty.trim();
    final rname = trimmedName.isEmpty
        ? nextJangeumLabelForRevenueList(state.revenueList)
        : trimmedName;

    await _revenueUseCase.insertRevenue(
      pid: pid,
      rprice: rprice,
      rname: rname,
      rdate: formatDateTimeToIsoDate(state.revenuePickedDay!),
    );
    await fetchAllRevenueFromPlace();
    _resetRevenueFormAfterInsert();
    return null;
  }

  Future<void> deleteCost(String category, int id) async {
    if (category == 'w') {
      await _workCostUseCase.deleteWorkCost(id);
    } else {
      await _materialCostUseCase.deleteMaterialCost(id);
    }
    _removeCostFromState(id: id, category: category);
  }

  /// 인건비와 같은 날·현장·인력의 작업 투입(place-work-days) 연결 여부.
  Future<int?> placeWorkDayPwdidForWorkCost(TotalCostModel item) {
    final hid = item.whid;
    final pid = item.wpid ?? state.pid;
    if (hid == null || pid <= 0) return Future.value(null);
    final dateKey =
        item.date.length >= 10 ? item.date.substring(0, 10) : item.date;
    return _workCostUseCase.findPlaceWorkDayPwdid(
      pid: pid,
      hid: hid,
      dateKey: dateKey,
    );
  }

  /// 인건비 삭제. [pwdid]가 있으면 작업 투입도 함께 삭제.
  Future<void> deleteWorkCostLinked({
    required int wid,
    int? pwdid,
  }) async {
    await _workCostUseCase.deleteWorkCostLinked(wid: wid, pwdid: pwdid);
    _removeCostFromState(id: wid, category: 'w');
  }

  Future<void> updateCost(String category, int id, String date) async {
    String priceString = mPriceController.text.trim();
    priceString = priceString.replaceAll(RegExp(r'[,원]'), '');
    final price = int.tryParse(priceString);

    if (category != 'w') {
      if (mNameController.text.isEmpty || price == null) {
        state = state.copyWith(alertText: '모든 항목을 입력해 주세요.');
        return;
      }
      state = state.copyWith(alertText: '');
      final m = MaterialCostModel(
        mid: id,
        mname: mNameController.text.trim(),
        mdate: date,
        mcategory: state.selectedDropdownCategory!,
        mprice: price,
      );
      await _materialCostUseCase.updateMaterialCostItem(m);
      final current = _findCostById(category: category, id: id);
      if (current != null) {
        _upsertCostInState(
          TotalCostModel(
            pname: current.pname,
            pcomplete: current.pcomplete,
            name: m.mname,
            date: m.mdate,
            price: m.mprice,
            category: m.mcategory,
            id: current.id,
            wcomplete: current.wcomplete,
            wcompletedAt: current.wcompletedAt,
            whid: current.whid,
            wpid: current.wpid,
            workrole: current.workrole,
          ),
        );
      }
    } else {
      if (price == null) {
        state = state.copyWith(alertText: '모든 항목을 입력해 주세요.');
        return;
      }
      state = state.copyWith(alertText: '');
      final w = WorkCostModel(
        wid: id,
        wdate: date,
        wprice: price,
        wcomplete: -1,
        wpid: 1,
      );
      await _workCostUseCase.updateWorkCostItem(w);
      final current = _findCostById(category: category, id: id);
      if (current != null) {
        _upsertCostInState(
          TotalCostModel(
            pname: current.pname,
            pcomplete: current.pcomplete,
            name: current.name,
            date: w.wdate,
            price: w.wprice,
            category: current.category,
            id: current.id,
            wcomplete: current.wcomplete,
            wcompletedAt: current.wcompletedAt,
            whid: current.whid,
            wpid: current.wpid,
            workrole: current.workrole,
          ),
        );
      }
    }
  }

  Future<void> updateWComplete(int wcomplete, int id) async {
    await _workCostUseCase.toggleWorkCostCompletionStatus(wcomplete, id);
    final nextComplete = wcomplete == 1 ? 0 : 1;
    final nowIso = DateTime.now().toIso8601String();
    final current = _findCostById(category: 'w', id: id);
    if (current != null) {
      _upsertCostInState(
        TotalCostModel(
          pname: current.pname,
          pcomplete: current.pcomplete,
          name: current.name,
          date: current.date,
          price: current.price,
          category: current.category,
          id: current.id,
          wcomplete: nextComplete,
          wcompletedAt: nextComplete == 1 ? (current.wcompletedAt ?? nowIso) : null,
          whid: current.whid,
          wpid: current.wpid,
          workrole: current.workrole,
        ),
      );
    }
    // 화면 체감 속도는 즉시 반영으로 확보하고, 실제 서버 상태는 백그라운드 동기화.
    unawaited(fetchTotalCostFromPlace(silent: true, forceRefresh: true));
  }

  TotalCostModel? _findCostById({
    required String category,
    required int id,
  }) {
    for (final cost in state.totalCostList) {
      if (cost.category == category && cost.id == id) return cost;
    }
    return null;
  }

  void _upsertCostInState(TotalCostModel updated) {
    final updatedList = state.totalCostList
        .map((e) => (e.id == updated.id && e.category == updated.category) ? updated : e)
        .toList(growable: false);
    final updatedCache = <String, List<TotalCostModel>>{};
    for (final entry in state.costCache.entries) {
      updatedCache[entry.key] = entry.value
          .map((e) => (e.id == updated.id && e.category == updated.category) ? updated : e)
          .toList(growable: false);
    }
    state = state.copyWith(
      totalCostList: updatedList,
      costCache: updatedCache,
    );
  }

  void _removeCostFromState({
    required int id,
    required String category,
  }) {
    final updatedList = state.totalCostList
        .where((e) => !(e.id == id && e.category == category))
        .toList(growable: false);
    final updatedCache = <String, List<TotalCostModel>>{};
    for (final entry in state.costCache.entries) {
      updatedCache[entry.key] = entry.value
          .where((e) => !(e.id == id && e.category == category))
          .toList(growable: false);
    }
    state = state.copyWith(
      totalCostList: updatedList,
      costCache: updatedCache,
    );
  }

  Future<void> changeDateTimeRange(int index, BuildContext context) async {
    final toggle = List<bool>.from(state.toggleState);
    for (int i = 0; i < toggle.length; i++) {
      toggle[i] = i == index;
    }

    DateTimeRange nextRange = state.dateTimeRange;
    DayTpye nextType = state.selectedDayType;

    if (index == 0) {
      nextType = DayTpye.range;
      nextRange = await _pickRangeWithScrollableCalendar(context) ?? nextRange;
    } else if (index == 1) {
      nextType = DayTpye.whole;
      nextRange =
          DateTimeRange(start: DateTime(2000), end: DateTime(2099, 12, 31));
    } else {
      nextType = DayTpye.month;
      nextRange = getMonthDateRange(DateTime.now());
    }

    state = state.copyWith(
      toggleState: toggle,
      selectedDayType: nextType,
      dateTimeRange: nextRange,
    );

    // ✅ 날짜 범위 변경 후 데이터 다시 불러오기 (캐시 우선 사용)
    await fetchTotalCostFromPlace(forceRefresh: false);
  }

  Future<void> exportAndSharePlaceInfoToExcel(String pname) async {
    final pid = state.pid;
    final dateTimeRange = state.dateTimeRange;

    final detailQueryResult = await _placeUseCase.getPlaceTotalCostsForCsv(
        dateTimeRange.start, dateTimeRange.end, pid);
    final summaryQueryResult = await _placeUseCase.getPlaceSummaryForCsv(pid);

    if (detailQueryResult.isEmpty) return;

    final detailCsvData = <List<dynamic>>[];
    final summaryCsvData = <List<dynamic>>[];

    detailCsvData.add(['', '현장 이름', pname]);
    detailCsvData.add([]);
    detailCsvData.add([''] + detailQueryResult.first.keys.toList());
    for (final row in detailQueryResult) {
      detailCsvData.add(['' as dynamic] + row.values.toList());
    }

    if (summaryQueryResult.isNotEmpty) {
      summaryCsvData.add(['', '현장 이름', pname]);
      summaryCsvData.add([]);
      summaryCsvData.add(['', '항목', '금액']);
      for (final row in summaryQueryResult) {
        row.forEach((key, value) {
          summaryCsvData.add(['' as dynamic] + [key, value]);
        });
        summaryCsvData.add([]);
      }
    } else {
      summaryCsvData.add(['요약 정보가 없습니다.']);
    }

    final excel = Excel.createExcel();
    final detailSheet = excel['세부 정보'];
    final summarySheet = excel['요약 정보'];
    try {
      excel.delete('Sheet1');
    } catch (_) {}

    for (int i = 0; i < detailCsvData.length; i++) {
      final row = detailCsvData[i];
      for (int j = 0; j < row.length; j++) {
        detailSheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i),
          (row[j] is String)
              ? TextCellValue(row[j].toString())
              : IntCellValue(int.tryParse(row[j].toString()) ?? 0),
        );
      }
    }

    for (int i = 0; i < summaryCsvData.length; i++) {
      final row = summaryCsvData[i];
      for (int j = 0; j < row.length; j++) {
        summarySheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i),
          (row[j] is String)
              ? TextCellValue(row[j].toString())
              : IntCellValue(int.tryParse(row[j].toString()) ?? 0),
        );
      }
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final excelFilePath =
        '${appDocDir.path}/$pname (${formatDateTimeRangeToString(dateTimeRange, periodType: state.selectedDayType)}).xlsx';
    final bytes = excel.encode();
    final excelFile = File(excelFilePath);
    await excelFile.writeAsBytes(bytes!);

    await Share.shareXFiles(
      [XFile(excelFile.path)],
      subject:
          '$pname (${formatDateTimeRangeToString(dateTimeRange, periodType: state.selectedDayType)})',
    );
  }
}
