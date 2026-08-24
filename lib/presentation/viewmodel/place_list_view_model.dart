import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/datasources/local/place_contract_deadline_storage.dart';
import 'package:w0001/data/datasources/local/place_list_preferences_storage.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/repository/human_impl.dart';
import 'package:w0001/data/repository/place_impl.dart';
import 'package:w0001/domain/repository/human_abst.dart';
import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/domain/use_case/human_use_case.dart';
import 'package:w0001/domain/use_case/place_use_case.dart';
import 'package:w0001/domain/place_list_display.dart';
import 'package:w0001/domain/place_delete_error.dart';
import 'package:w0001/domain/place_work_period_display.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';

/// 현장 목록 API 페이지 크기 — [kListPageSize]와 동일.
const int kPlaceListPageSize = kListPageSize;

class PlaceListState {
  const PlaceListState({
    required this.placeList,
    required this.filteredPlaceList,
    required this.placeState,
    required this.updateText,
    required this.isLoading,
    required this.hasLoadedOnce,
    required this.loadError,
    required this.searchQuery,
    required this.sortMode,
    required this.favoritePids,
    required this.hasMore,
    required this.isLoadingMore,
    required this.contractPendByPid,
    required this.contractOverWorkDaysByPid,
    this.nextCursor,
    this.totalCount,
  });

  final List<PlaceInfoModel> placeList;
  final List<PlaceInfoModel> filteredPlaceList;
  final PlaceState placeState;
  final String updateText;
  final bool isLoading;

  /// 최초 API 조회가 끝났는지(실패 포함). false면 스켈레톤 유지.
  final bool hasLoadedOnce;
  final String? loadError;
  final String searchQuery;
  final PlaceListSortMode sortMode;
  final List<int> favoritePids;
  final bool hasMore;
  final bool isLoadingMore;

  /// pid → 계약(마감) 종료일 ISO. 공정표 연장으로 늘어난 `pend`와 별도.
  final Map<int, String> contractPendByPid;

  /// pid → 계약 마감 이후 실제 작업 투입 일수.
  final Map<int, int> contractOverWorkDaysByPid;
  final String? nextCursor;
  final int? totalCount;

  factory PlaceListState.initial() => PlaceListState(
        placeList: const [],
        filteredPlaceList: const [],
        placeState: PlaceState.incomplete,
        updateText: '',
        isLoading: true,
        hasLoadedOnce: false,
        loadError: null,
        searchQuery: '',
        sortMode: PlaceListSortMode.defaultFor(PlaceState.incomplete),
        favoritePids: const [],
        hasMore: false,
        isLoadingMore: false,
        contractPendByPid: const {},
        contractOverWorkDaysByPid: const {},
        nextCursor: null,
        totalCount: null,
      );

  int get tabPlaceCount =>
      totalCount ?? countPlacesForTab(placeList, placeState);

  /// 스크롤 load-more 가능 (`has_more` + `next_cursor`).
  bool get canLoadMore =>
      hasMore && nextCursor != null && nextCursor!.trim().isNotEmpty;

  PlaceListState copyWith({
    List<PlaceInfoModel>? placeList,
    List<PlaceInfoModel>? filteredPlaceList,
    PlaceState? placeState,
    String? updateText,
    bool? isLoading,
    bool? hasLoadedOnce,
    String? loadError,
    bool clearLoadError = false,
    String? searchQuery,
    PlaceListSortMode? sortMode,
    List<int>? favoritePids,
    bool? hasMore,
    bool? isLoadingMore,
    Map<int, String>? contractPendByPid,
    Map<int, int>? contractOverWorkDaysByPid,
    String? nextCursor,
    bool clearNextCursor = false,
    int? totalCount,
    bool clearTotalCount = false,
  }) {
    return PlaceListState(
      placeList: placeList ?? this.placeList,
      filteredPlaceList: filteredPlaceList ?? this.filteredPlaceList,
      placeState: placeState ?? this.placeState,
      updateText: updateText ?? this.updateText,
      isLoading: isLoading ?? this.isLoading,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      searchQuery: searchQuery ?? this.searchQuery,
      sortMode: sortMode ?? this.sortMode,
      favoritePids: favoritePids ?? this.favoritePids,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      contractPendByPid: contractPendByPid ?? this.contractPendByPid,
      contractOverWorkDaysByPid:
          contractOverWorkDaysByPid ?? this.contractOverWorkDaysByPid,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      totalCount: clearTotalCount ? null : (totalCount ?? this.totalCount),
    );
  }
}

class PlaceListViewModel extends Notifier<PlaceListState> {
  /// [build]가 재호출될 때 `late final`·초기 state 리셋으로 크래시/빈 화면이 나지 않도록 한다.
  var _lifecycleAttached = false;
  Timer? _searchDebounce;
  Future<void>? _loadMoreInFlight;
  final PlaceListPreferencesStorage _prefsStorage =
      PlaceListPreferencesStorage();
  var _prefsRestored = false;
  String? _prefsUid;

  PlaceUseCase get _useCase => ref.read(placeUseCaseProvider);

  /// 현장 추가 다이얼로그에서 캘린더로 고른 기간 (날짜만, 시간 제거).
  DateTime? _placeDialogRangeStart;
  DateTime? _placeDialogRangeEnd;

  final TextEditingController placeNameController = TextEditingController();
  final TextEditingController placeRevenueController =
      TextEditingController(text: '0');
  final TextEditingController placeContractTotalController =
      TextEditingController(text: '0');
  final TextEditingController placeAddressController = TextEditingController();

  void _onAuthSessionForPlaceList(
    AsyncValue<UserRead?>? prev,
    AsyncValue<UserRead?> next,
  ) {
    final u = next.asData?.value;
    if (u == null) return;
    final prevUser = prev?.asData?.value;
    if (prevUser != null &&
        prevUser.uid == u.uid &&
        prevUser.role == u.role &&
        state.hasLoadedOnce) {
      return;
    }
    _prefsRestored = false;
    _prefsUid = null;
    Future.microtask(() async {
      if (!ref.mounted) return;
      await initialize(force: true);
    });
  }

  String? _currentUid() => ref.read(authSessionProvider).asData?.value?.uid;

  Future<void> _persistLocalPreferences() async {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return;
    await _prefsStorage.save(
      uid,
      PlaceListLocalPreferences(
        placeState: state.placeState,
        sortMode: state.sortMode,
        favoritePids: state.favoritePids,
      ),
    );
  }

  Future<void> restoreLocalPreferences() async {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return;
    if (_prefsRestored && _prefsUid == uid) return;

    final prefs = await _prefsStorage.load(uid);
    if (!ref.mounted) return;
    _prefsRestored = true;
    _prefsUid = uid;
    final restoredState = prefs.placeState == PlaceState.archived
        ? PlaceState.incomplete
        : prefs.placeState;
    state = state.copyWith(
      placeState: restoredState,
      sortMode: prefs.placeState == PlaceState.archived
          ? PlaceListSortMode.defaultFor(PlaceState.incomplete)
          : prefs.sortMode,
      favoritePids: prefs.favoritePids,
    );
  }

  /// 로컬 설정 복원 후 목록 조회 (최초 진입·계정 전환).
  Future<void> initialize({bool force = false}) async {
    await restoreLocalPreferences();
    await refreshPlaces(force: force);
  }

  void _pruneStaleFavorites() {
    if (state.favoritePids.isEmpty || state.placeList.isEmpty) return;
    final known = state.placeList.map((p) => p.pid).whereType<int>().toSet();
    final pruned =
        state.favoritePids.where((pid) => known.contains(pid)).toList();
    if (pruned.length == state.favoritePids.length) return;
    state = state.copyWith(favoritePids: pruned);
    unawaited(_persistLocalPreferences());
  }

  void _disposePaging() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
  }

  ListQuery _buildListQuery({String? cursor}) {
    final q = state.searchQuery.trim();
    return ListQuery(
      pcomplete: pcompleteQueryForPlaceState(state.placeState),
      q: q.isEmpty ? null : q,
      limit: kPlaceListPageSize,
      cursor: cursor,
    );
  }

  void _applyPlacePage(PagedResult<PlaceInfoModel> page,
      {required bool append}) {
    final merged = append
        ? mergePagedItems(state.placeList, page.items, (p) => p.pid)
        : page.items;
    state = state.copyWith(
      placeList: merged,
      nextCursor: page.nextCursor,
      hasMore: page.canLoadMore,
      totalCount:
          append ? (page.totalCount ?? state.totalCount) : page.totalCount,
    );
    _pruneStaleFavorites();
    _rebuildFilteredList();
    unawaited(() async {
      await _bootstrapContractPendForPlaces(page.items);
      if (ref.mounted) {
        await _healPollutedPlacePendFromContractDeadline(page.items);
      }
      if (ref.mounted) await _refreshContractOverWorkDayCounts();
    }());
  }

  int? contractOverWorkDaysFor(PlaceInfoModel place) {
    final pid = place.pid;
    if (pid == null) return null;
    return state.contractOverWorkDaysByPid[pid];
  }

  Future<void> _refreshContractOverWorkDayCounts() async {
    final user = ref.read(authSessionProvider).asData?.value;
    if (user == null || !user.isManagementRole) return;
    if (state.placeList.isEmpty) {
      if (ref.mounted) {
        state = state.copyWith(contractOverWorkDaysByPid: const {});
      }
      return;
    }

    try {
      final rows =
          await ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
      if (!ref.mounted) return;
      final counts = buildContractOverWorkDayCounts(
        places: state.placeList,
        contractPendByPid: state.contractPendByPid,
        workRows: rows,
      );
      state = state.copyWith(contractOverWorkDaysByPid: counts);
    } catch (e, st) {
      debugPrint('contract over work day counts failed: $e\n$st');
    }
  }

  String? contractPendFor(PlaceInfoModel place) {
    final pid = place.pid;
    if (pid == null) return null;
    return state.contractPendByPid[pid];
  }

  /// 사용자가 기간을 직접 저장할 때만 호출 — 공정표 그리드 연장과 분리.
  Future<void> persistContractDeadline(int pid, DateTime endInclusive) async {
    final day = DateTime(
      endInclusive.year,
      endInclusive.month,
      endInclusive.day,
    );
    final iso = day.toIso8601String();
    await PlaceContractDeadlineStorage.write(pid, iso);
    if (!ref.mounted) return;
    final next = Map<int, String>.from(state.contractPendByPid);
    next[pid] = iso;
    state = state.copyWith(contractPendByPid: next);
    unawaited(_refreshContractOverWorkDayCounts());
  }

  Future<void> _bootstrapContractPendForPlaces(
    List<PlaceInfoModel> places,
  ) async {
    if (places.isEmpty) return;
    final stored = await PlaceContractDeadlineStorage.readAll();
    final next = Map<int, String>.from(state.contractPendByPid);
    next.addAll(stored);
    var wrote = false;
    for (final p in places) {
      final pid = p.pid;
      if (pid == null || next.containsKey(pid)) continue;
      final boot = pendWhenTogglingToComplete(p);
      if (boot == '0') continue;
      await PlaceContractDeadlineStorage.write(pid, boot);
      next[pid] = boot;
      wrote = true;
    }
    if (!ref.mounted) return;
    if (wrote || next.length != state.contractPendByPid.length) {
      state = state.copyWith(contractPendByPid: next);
    }
  }

  /// 공정표 연장으로 `pend`만 길어진 현장을, 로컬 계약 마감일로 되돌린다.
  /// 작업자 리스트는 서버 `pend`를 보므로 관리자 기기에서 한 번 복구해야 맞는다.
  Future<void> _healPollutedPlacePendFromContractDeadline(
    List<PlaceInfoModel> places,
  ) async {
    final user = ref.read(authSessionProvider).asData?.value;
    if (user == null || !user.isManagementRole) return;

    var listChanged = false;
    final nextList = List<PlaceInfoModel>.from(state.placeList);

    for (final p in places) {
      final pid = p.pid;
      if (pid == null) continue;
      final localIso = state.contractPendByPid[pid]?.trim();
      final local = parsePlaceCalendarDay(localIso);
      final master = parsePlaceCalendarDay(pendWhenTogglingToComplete(p));
      if (localIso == null || local == null || master == null) continue;
      if (!local.isBefore(master)) continue;

      try {
        final model = PlaceModel(
          pid: pid,
          pname: p.pname,
          prevenue: p.pfirstrevenue,
          pcontractTotal: p.pcontractTotal,
          pcomplete: p.pcomplete,
          pstart: p.pstart,
          pend: localIso,
          paddress: p.paddress,
          pcontractDate: '',
        );
        await _useCase.updatePlace(model);
        final idx = nextList.indexWhere((e) => e.pid == pid);
        if (idx >= 0) {
          final cur = nextList[idx];
          nextList[idx] = PlaceInfoModel(
            pid: cur.pid,
            pname: cur.pname,
            pcomplete: cur.pcomplete,
            pstart: cur.pstart,
            pend: localIso,
            paddress: cur.paddress,
            pfirstrevenue: cur.pfirstrevenue,
            pcontractTotal: cur.pcontractTotal,
            workerCount: cur.workerCount,
            totalAdditionalRevenue: cur.totalAdditionalRevenue,
            mTotal: cur.mTotal,
            woodTotal: cur.woodTotal,
            metalTotal: cur.metalTotal,
            electricTotal: cur.electricTotal,
            lightingTotal: cur.lightingTotal,
            cleaningTotal: cur.cleaningTotal,
            filmTotal: cur.filmTotal,
            landscapeTotal: cur.landscapeTotal,
            hardwareTotal: cur.hardwareTotal,
            paintTotal: cur.paintTotal,
            facilityTotal: cur.facilityTotal,
            tileTotal: cur.tileTotal,
            glassTotal: cur.glassTotal,
            fuelTotal: cur.fuelTotal,
            accommodationTotal: cur.accommodationTotal,
            foodTotal: cur.foodTotal,
            personalExpensesTotal: cur.personalExpensesTotal,
            firefightingTotal: cur.firefightingTotal,
            signageTotal: cur.signageTotal,
            airConditioningTotal: cur.airConditioningTotal,
            demolitionTotal: cur.demolitionTotal,
            customMadeTotal: cur.customMadeTotal,
            otherExpensesTotal: cur.otherExpensesTotal,
            wTotal: cur.wTotal,
            wIncomplete: cur.wIncomplete,
          );
          listChanged = true;
        }
      } catch (e, st) {
        debugPrint('heal place pend from contract deadline failed: $e\n$st');
      }
    }

    if (!ref.mounted || !listChanged) return;
    state = state.copyWith(placeList: nextList);
    _rebuildFilteredList();
  }

  void _rebuildFilteredList() {
    final hasServerQ = state.searchQuery.trim().isNotEmpty;
    final filtered = applyPlaceListDisplay(
      all: state.placeList,
      tab: state.placeState,
      searchQuery: state.searchQuery,
      sortMode: state.sortMode,
      favoritePids: state.favoritePids,
      skipTabFilter: true,
      skipSearchFilter: hasServerQ,
    );
    state = state.copyWith(filteredPlaceList: filtered);
  }

  void _disposeControllers() {
    placeNameController.dispose();
    placeRevenueController.dispose();
    placeContractTotalController.dispose();
    placeAddressController.dispose();
  }

  @override
  PlaceListState build() {
    if (!_lifecycleAttached) {
      _lifecycleAttached = true;
      ref.listen<AsyncValue<UserRead?>>(
        authSessionProvider,
        _onAuthSessionForPlaceList,
        fireImmediately: true,
      );
      ref.onDispose(_disposeControllers);
      ref.onDispose(_disposePaging);
      return PlaceListState.initial();
    }
    return state;
  }

  Future<void> fetchAllPlace({bool force = false}) =>
      refreshPlaces(force: force);

  /// 첫 페이지부터 다시 조회 (탭·검색·pull-to-refresh).
  Future<void> refreshPlaces({bool force = false}) async {
    final user = ref.read(authSessionProvider).asData?.value;
    if (user == null) return;

    final hadList = !force && state.placeList.isNotEmpty;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearLoadError: true,
      clearNextCursor: true,
      clearTotalCount: true,
    );
    try {
      final page = await _useCase.fetchPlacesPage(
        query: _buildListQuery(),
        managementPlacesInfoFirst: user.isManagementRole,
        role: user.role,
      );
      _applyPlacePage(page, append: false);
      assert(() {
        debugPrint(
          'Place list refresh: ${page.items.length} items, '
          'canLoadMore=${page.canLoadMore}, cursor=${page.nextCursor != null}',
        );
        return true;
      }());
    } catch (e, st) {
      debugPrint('Place list fetch failed: $e\n$st');
      final hErr = unwrapHttpClientException(e);
      state = state.copyWith(
        loadError:
            hadList ? state.loadError : (hErr?.message ?? '현장 목록을 불러오지 못했습니다.'),
      );
    } finally {
      state = state.copyWith(
        isLoading: false,
        hasLoadedOnce: true,
      );
    }
  }

  /// 스크롤 하단 — 다음 cursor 페이지.
  Future<void> loadMorePlaces() async {
    if (!state.canLoadMore || state.isLoading || state.isLoadingMore) return;
    if (_loadMoreInFlight != null) return _loadMoreInFlight;

    final user = ref.read(authSessionProvider).asData?.value;
    if (user == null) return;
    final cursor = state.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    _loadMoreInFlight = _loadMoreBody(user);
    try {
      await _loadMoreInFlight;
    } finally {
      _loadMoreInFlight = null;
    }
  }

  Future<void> _loadMoreBody(UserRead user) async {
    state = state.copyWith(isLoadingMore: true, clearLoadError: true);
    try {
      final page = await _useCase.fetchPlacesPage(
        query: _buildListQuery(cursor: state.nextCursor),
        managementPlacesInfoFirst: user.isManagementRole,
        role: user.role,
      );
      _applyPlacePage(page, append: true);
    } catch (e, st) {
      debugPrint('Place list loadMore failed: $e\n$st');
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setPlaceDialogDateRange(DateTime? start, DateTime? end) {
    _placeDialogRangeStart = start;
    _placeDialogRangeEnd = end;
  }

  void resetTextController() {
    placeNameController.text = '';
    placeRevenueController.text = '0';
    placeContractTotalController.text = '0';
    placeAddressController.text = '';
    _placeDialogRangeStart = null;
    _placeDialogRangeEnd = null;
    state = state.copyWith(updateText: '');
  }

  void clearUpdateText() {
    state = state.copyWith(updateText: '');
  }

  void stateValueChanged(PlaceState? value) {
    if (value == null || value == state.placeState) return;
    // 보관은 설정 → 보관 현장에서만 관리.
    if (value == PlaceState.archived) return;
    state = state.copyWith(
      placeState: value,
      sortMode: PlaceListSortMode.defaultFor(value),
      placeList: const [],
      filteredPlaceList: const [],
      clearNextCursor: true,
      hasMore: false,
      clearTotalCount: true,
    );
    unawaited(_persistLocalPreferences());
    unawaited(refreshPlaces(force: true));
  }

  /// 보관(pcomplete=2) 현장을 진행중(0) 또는 완료(1)로 복구.
  Future<void> restoreArchivedPlace(
    int index, {
    required int toPcomplete,
  }) async {
    if (toPcomplete != 0 && toPcomplete != 1) return;
    final current = state.filteredPlaceList[index];
    if (current.pid == null || current.pcomplete != 2) return;
    final endDate = pendWhenTogglingToComplete(current);
    await _useCase.updatePlaceCompletionStatus(
      current.pid!,
      toPcomplete,
      endDate,
    );
    await refreshPlaces(force: true);
  }

  void setSearchQuery(String query) {
    final next = query;
    if (next == state.searchQuery) return;
    state = state.copyWith(searchQuery: next);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!ref.mounted) return;
      unawaited(refreshPlaces(force: true));
    });
  }

  void clearSearchQuery() {
    if (state.searchQuery.isEmpty) return;
    _searchDebounce?.cancel();
    state = state.copyWith(searchQuery: '');
    unawaited(refreshPlaces(force: true));
  }

  void setSortMode(PlaceListSortMode mode) {
    if (mode == state.sortMode) return;
    state = state.copyWith(sortMode: mode);
    _rebuildFilteredList();
    unawaited(_persistLocalPreferences());
  }

  void toggleFavorite(int pid) {
    if (pid <= 0) return;
    final current = List<int>.from(state.favoritePids);
    final idx = current.indexOf(pid);
    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      current.insert(0, pid);
    }
    state = state.copyWith(favoritePids: current);
    _rebuildFilteredList();
    unawaited(_persistLocalPreferences());
  }

  bool isFavorite(int? pid) => pid != null && state.favoritePids.contains(pid);

  /// [completionPend]: 완료(1)로 바꿀 때만 사용. `null`이면 [pendWhenTogglingToComplete]와 동일.
  Future<void> updatePcomplete(
    int index, {
    String? completionPend,
  }) async {
    final current = state.filteredPlaceList[index];
    final newComplete = current.pcomplete == 1 ? 0 : 1;
    final String endDate;
    if (newComplete == 0) {
      /// 진행중으로 되돌릴 때 `pend`를 `'0'`으로 두면 목록·공정표에서 종료일이 비어
      /// `시작일 ~ 시작일`처럼 보입니다. 현재 저장된 종료일(완료 시점에 찍힌 값)을 유지합니다.
      endDate = pendWhenTogglingToComplete(current);
    } else {
      endDate = completionPend ?? pendWhenTogglingToComplete(current);
    }
    await _useCase.updatePlaceCompletionStatus(
      current.pid!,
      newComplete,
      endDate,
    );
    await fetchAllPlace();
  }

  /// soft delete (`pcomplete=2`) 또는 [permanent] 영구삭제.
  Future<void> deletePlace(int pid, {bool permanent = false}) async {
    try {
      await _useCase.deletePlace(pid, permanent: permanent);
      await PlaceContractDeadlineStorage.remove(pid);
      if (ref.mounted) {
        final next = Map<int, String>.from(state.contractPendByPid);
        next.remove(pid);
        state = state.copyWith(contractPendByPid: next);
      }
      await fetchAllPlace();
    } catch (e, st) {
      debugPrint('deletePlace failed: $e\n$st');
      state = state.copyWith(
        updateText: userMessageForPlaceDeleteFailure(e),
      );
      rethrow;
    }
  }

  Future<bool> updatePlace(
    int pid,
    String pname,
    String paddress,
    int prevenue,
    int pcontractTotal,
    DateTime? rangeStart,
    DateTime? rangeEnd, {
    /// 현장 수정 시 완료(1)·삭제(2) 등 상태 유지. 미지정 시 `0`(진행중).
    int pcomplete = 0,
  }) async {
    if (pname.isEmpty) {
      state = state.copyWith(updateText: '현장 이름을 입력해주세요.');
      return false;
    } else if (prevenue == -1) {
      state = state.copyWith(updateText: '선수금을 입력해주세요.');
      return false;
    } else if (pcontractTotal < 0) {
      state = state.copyWith(updateText: '공사 총액이 올바르지 않습니다.');
      return false;
    } else if (rangeStart == null) {
      state = state.copyWith(updateText: '기간을 선택해주세요.');
      return false;
    } else {
      final end = rangeEnd ?? rangeStart;
      final model = PlaceModel(
        pid: pid,
        pname: pname,
        prevenue: prevenue,
        pcontractTotal: pcontractTotal,
        pcomplete: pcomplete,
        pstart: rangeStart.toIso8601String(),
        pend: end.toIso8601String(),
        paddress: paddress.trim(),
        pcontractDate: '',
      );
      await _useCase.updatePlace(model);
      await persistContractDeadline(pid, end);
      await fetchAllPlace();
      state = state.copyWith(updateText: '');
      return true;
    }
  }

  Future<void> insertPlace() async {
    String revenueString = placeRevenueController.text.trim();
    revenueString = revenueString.replaceAll(RegExp(r'[,원]'), '');
    final revenue = int.tryParse(revenueString);

    String contractString = placeContractTotalController.text.trim();
    contractString = contractString.replaceAll(RegExp(r'[,원]'), '');
    final contractTotal = int.tryParse(contractString);

    if (placeNameController.text.isEmpty) {
      state = state.copyWith(updateText: '현장 이름을 입력해주세요.');
      return;
    } else if (placeRevenueController.text.isEmpty) {
      state = state.copyWith(updateText: '선수금을 입력해주세요.');
      return;
    } else if (revenue == null) {
      state = state.copyWith(updateText: '선수금이 올바르지 않습니다.');
      return;
    } else if (contractTotal == null || contractTotal < 0) {
      state = state.copyWith(updateText: '공사 총액이 올바르지 않습니다.');
      return;
    }

    final rangeStart = _placeDialogRangeStart;
    if (rangeStart == null) {
      state = state.copyWith(updateText: '기간을 선택해주세요.');
      return;
    }
    final rangeEnd = _placeDialogRangeEnd ?? rangeStart;
    final pstart = rangeStart.toIso8601String();
    final pend = rangeEnd.toIso8601String();

    final place = PlaceModel(
      prevenue: revenue,
      pcontractTotal: contractTotal,
      pname: placeNameController.text,
      pstart: pstart,
      pend: pend,
      paddress: placeAddressController.text.trim(),
      pcomplete: 0,
      pcontractDate: '',
    );
    try {
      final created = await _useCase.insertPlace(place);
      final newPid = created.pid;
      if (newPid != null) {
        await persistContractDeadline(newPid, rangeEnd);
      }
      await fetchAllPlace();
      state = state.copyWith(updateText: '');
    } catch (e, st) {
      debugPrint('insertPlace failed: $e\n$st');
      state = state.copyWith(
        updateText: '현장 추가에 실패했습니다. 네트워크를 확인해 주세요.',
      );
    }
  }
}

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => PlaceRepositoryImpl(
    ref.read(superAdminRemoteRepositoryProvider),
    ref.read(dashboardRemoteRepositoryProvider),
  ),
);

final placeUseCaseProvider = Provider<PlaceUseCase>(
  (ref) => PlaceUseCase(ref.read(placeRepositoryProvider)),
);

final humanRepositoryProvider = Provider<HumanRepository>(
  (ref) => HumanRepositoryImpl(ref.read(superAdminRemoteRepositoryProvider)),
);

final humanUseCaseProvider = Provider<HumanUseCase>(
  (ref) => HumanUseCase(ref.read(humanRepositoryProvider)),
);

final placeListProvider = NotifierProvider<PlaceListViewModel, PlaceListState>(
  PlaceListViewModel.new,
);
