import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/datasources/local/human_local_data_source.dart';
import 'package:w0001/data/datasources/local/place_local_data_source.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/repository/human_impl.dart';
import 'package:w0001/data/repository/place_impl.dart';
import 'package:w0001/domain/repository/human_abst.dart';
import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/domain/use_case/human_use_case.dart';
import 'package:w0001/domain/use_case/place_use_case.dart';
import 'package:w0001/enums.dart';

class PlaceListState {
  const PlaceListState({
    required this.placeList,
    required this.filteredPlaceList,
    required this.placeState,
    required this.updateText,
    required this.isLoading,
  });

  final List<PlaceInfoModel> placeList;
  final List<PlaceInfoModel> filteredPlaceList;
  final PlaceState placeState;
  final String updateText;
  final bool isLoading;

  factory PlaceListState.initial() => const PlaceListState(
        placeList: [],
        filteredPlaceList: [],
        placeState: PlaceState.incomplete,
        updateText: '',
        isLoading: false,
      );

  PlaceListState copyWith({
    List<PlaceInfoModel>? placeList,
    List<PlaceInfoModel>? filteredPlaceList,
    PlaceState? placeState,
    String? updateText,
    bool? isLoading,
  }) {
    return PlaceListState(
      placeList: placeList ?? this.placeList,
      filteredPlaceList: filteredPlaceList ?? this.filteredPlaceList,
      placeState: placeState ?? this.placeState,
      updateText: updateText ?? this.updateText,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PlaceListViewModel extends Notifier<PlaceListState> {
  late final PlaceUseCase _useCase;
  bool _initialized = false;

  /// 현장 추가 다이얼로그에서 캘린더로 고른 기간 (날짜만, 시간 제거).
  DateTime? _placeDialogRangeStart;
  DateTime? _placeDialogRangeEnd;

  final TextEditingController placeNameController = TextEditingController();
  final TextEditingController placeRevenueController =
      TextEditingController(text: '0');
  final TextEditingController placeContractTotalController =
      TextEditingController(text: '0');

  @override
  PlaceListState build() {
    _useCase = ref.read(placeUseCaseProvider);
    ref.onDispose(() {
      placeNameController.dispose();
      placeRevenueController.dispose();
      placeContractTotalController.dispose();
    });
    if (!_initialized) {
      _initialized = true;
      // state가 초기화된 이후에 실행되도록 마이크로태스크로 예약
      Future.microtask(fetchAllPlace);
    }
    return PlaceListState.initial();
  }

  Future<void> fetchAllPlace() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _useCase.getAllPlaces();
      final filtered = _filterByState(list, state.placeState);
      state = state.copyWith(
        placeList: list,
        filteredPlaceList: filtered,
      );
    } catch (e, st) {
      debugPrint('Place list fetch failed: $e\n$st');
    } finally {
      state = state.copyWith(isLoading: false);
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
    _placeDialogRangeStart = null;
    _placeDialogRangeEnd = null;
    state = state.copyWith(updateText: '');
  }

  void clearUpdateText() {
    state = state.copyWith(updateText: '');
  }

  void stateValueChanged(PlaceState? value) {
    if (value == null) return;
    final filtered = _filterByState(state.placeList, value);
    state = state.copyWith(
      placeState: value,
      filteredPlaceList: filtered,
    );
  }

  List<PlaceInfoModel> _filterByState(
    List<PlaceInfoModel> list,
    PlaceState placeState,
  ) {
    final complete = placeState == PlaceState.complete ? 1 : 0;
    return list.where((p) => p.pcomplete == complete).toList();
  }

  Future<void> updatePcomplete(int index) async {
    final current = state.filteredPlaceList[index];
    final newComplete = current.pcomplete == 1 ? 0 : 1;
    final endDate = newComplete == 1 ? DateTime.now().toString() : '0';
    await _useCase.updatePlaceCompletionStatus(
      current.pid!,
      newComplete,
      endDate,
    );
    await fetchAllPlace();
  }

  Future<void> deletePlace(int pid) async {
    await _useCase.updatePlaceCompletionStatus(pid, 2, '0');
    await fetchAllPlace();
  }

  Future<bool> updatePlace(
    int pid,
    String pname,
    int prevenue,
    int pcontractTotal,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  ) async {
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
        pcomplete: 0,
        pstart: rangeStart.toIso8601String(),
        pend: end.toIso8601String(),
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
      pcomplete: 0,
      pcontractDate: '',
    );
    await _useCase.insertPlace(place);
    await fetchAllPlace();
  }
}

final dbHelperProvider = Provider<DbHelper>((ref) => DbHelper());

final placeLocalDataSourceProvider = Provider<PlaceLocalDataSource>(
  (ref) => PlaceLocalDataSourceImpl(ref.read(dbHelperProvider)),
);

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => PlaceRepositoryImpl(ref.read(placeLocalDataSourceProvider)),
);

final placeUseCaseProvider = Provider<PlaceUseCase>(
  (ref) => PlaceUseCase(ref.read(placeRepositoryProvider)),
);

final humanLocalDataSourceProvider = Provider<HumanLocalDataSource>(
  (ref) => HumanLocalDataSourceImpl(ref.read(dbHelperProvider)),
);

final humanRepositoryProvider = Provider<HumanRepository>(
  (ref) => HumanRepositoryImpl(ref.read(humanLocalDataSourceProvider)),
);

final humanUseCaseProvider = Provider<HumanUseCase>(
  (ref) => HumanUseCase(ref.read(humanRepositoryProvider)),
);

final placeListProvider =
    NotifierProvider<PlaceListViewModel, PlaceListState>(
  PlaceListViewModel.new,
);

