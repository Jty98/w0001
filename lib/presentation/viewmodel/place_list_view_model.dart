import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/repository/human_impl.dart';
import 'package:w0001/data/repository/place_impl.dart';
import 'package:w0001/domain/repository/human_abst.dart';
import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/domain/use_case/human_use_case.dart';
import 'package:w0001/domain/use_case/place_use_case.dart';
import 'package:w0001/domain/place_list_display.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';

/// 슬라이드로 '완료'로 바꿀 때 **기본**으로 쓰는 `pend` (다이얼로그 "기존 종료일" 표시에도 사용).
/// `pend`가 비어 있거나 `0`이면 `pstart`로 보정한다.
String pendWhenTogglingToComplete(PlaceInfoModel p) {
  final pend = p.pend.trim();
  if (pend.isNotEmpty && pend != '0') {
    return pend;
  }
  final s = p.pstart.trim();
  if (s.isNotEmpty && s != '0') {
    return s;
  }
  return '0';
}

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
      );

  int get tabPlaceCount => countPlacesForTab(placeList, placeState);

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
    );
  }
}

class PlaceListViewModel extends Notifier<PlaceListState> {
  /// [build]가 재호출될 때 `late final`·초기 state 리셋으로 크래시/빈 화면이 나지 않도록 한다.
  var _lifecycleAttached = false;

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
    final prevUid = prev?.asData?.value?.uid;
    if (prevUid == u.uid && state.hasLoadedOnce) return;
    Future.microtask(() {
      if (!ref.mounted) return;
      unawaited(fetchAllPlace());
    });
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
      return PlaceListState.initial();
    }
    return state;
  }

  Future<void> fetchAllPlace({bool force = false}) async {
    final user = ref.read(authSessionProvider).asData?.value;
    if (user == null) return;

    final hadList = !force && state.placeList.isNotEmpty;
    state = state.copyWith(
      isLoading: true,
      clearLoadError: true,
    );
    try {
      final list = await _useCase.getAllPlaces(
        managementPlacesInfoFirst: user.isManagementRole,
        role: user.role,
      );
      state = state.copyWith(placeList: list);
      _rebuildFilteredList();
    } catch (e, st) {
      debugPrint('Place list fetch failed: $e\n$st');
      final hErr = unwrapHttpClientException(e);
      state = state.copyWith(
        loadError: hadList
            ? state.loadError
            : (hErr?.message ?? '현장 목록을 불러오지 못했습니다.'),
      );
    } finally {
      state = state.copyWith(
        isLoading: false,
        hasLoadedOnce: true,
      );
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
    state = state.copyWith(
      placeState: value,
      sortMode: PlaceListSortMode.defaultFor(value),
    );
    _rebuildFilteredList();
  }

  void setSearchQuery(String query) {
    final next = query;
    if (next == state.searchQuery) return;
    state = state.copyWith(searchQuery: next);
    _rebuildFilteredList();
  }

  void clearSearchQuery() {
    if (state.searchQuery.isEmpty) return;
    state = state.copyWith(searchQuery: '');
    _rebuildFilteredList();
  }

  void setSortMode(PlaceListSortMode mode) {
    if (mode == state.sortMode) return;
    state = state.copyWith(sortMode: mode);
    _rebuildFilteredList();
  }

  void _rebuildFilteredList() {
    final filtered = applyPlaceListDisplay(
      all: state.placeList,
      tab: state.placeState,
      searchQuery: state.searchQuery,
      sortMode: state.sortMode,
    );
    state = state.copyWith(filteredPlaceList: filtered);
  }

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

  Future<void> deletePlace(int pid) async {
    try {
      await _useCase.deletePlace(pid);
      await fetchAllPlace();
    } catch (e, st) {
      debugPrint('deletePlace failed: $e\n$st');
      state = state.copyWith(
        updateText: '현장 삭제에 실패했습니다. 네트워크를 확인해 주세요.',
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
      await _useCase.insertPlace(place);
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
