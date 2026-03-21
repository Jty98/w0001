import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';

class HumanWorkDetailState {
  const HumanWorkDetailState({
    required this.workCostList,
    required this.totalSegment,
    required this.taxState,
    required this.completeState,
    required this.selectedPlaceId,
  });

  final List<WorkCost2Model> workCostList;
  final TotalSegment totalSegment;
  final TaxState taxState;
  final CompleteState completeState;
  final int selectedPlaceId;

  bool get isTaxApply => taxState == TaxState.taxOn;
  bool get isIncomplete => completeState == CompleteState.incomplete;

  List<WorkCost2Model> get incompleteWorkCostList =>
      workCostList.where((e) => e.wcomplete == 0).toList();

  List<WorkCost2Model> get filteredWorkCostList =>
      isIncomplete ? incompleteWorkCostList : workCostList;

  int get totalPrice {
    var sum = 0;
    for (final w in filteredWorkCostList) {
      sum += w.wprice;
    }
    return sum;
  }

  factory HumanWorkDetailState.initial() => const HumanWorkDetailState(
        workCostList: [],
        totalSegment: TotalSegment.place,
        taxState: TaxState.taxOn,
        completeState: CompleteState.whole,
        selectedPlaceId: 0,
      );

  HumanWorkDetailState copyWith({
    List<WorkCost2Model>? workCostList,
    TotalSegment? totalSegment,
    TaxState? taxState,
    CompleteState? completeState,
    int? selectedPlaceId,
  }) {
    return HumanWorkDetailState(
      workCostList: workCostList ?? this.workCostList,
      totalSegment: totalSegment ?? this.totalSegment,
      taxState: taxState ?? this.taxState,
      completeState: completeState ?? this.completeState,
      selectedPlaceId: selectedPlaceId ?? this.selectedPlaceId,
    );
  }
}

final humanWorkDetailProvider = NotifierProvider.family<
    HumanWorkDetailViewModel,
    HumanWorkDetailState,
    int>(HumanWorkDetailViewModel.new);

class HumanWorkDetailViewModel extends Notifier<HumanWorkDetailState> {
  HumanWorkDetailViewModel(this.hid);

  final int hid;

  late final _workCostUseCase = ref.read(workCostUseCaseProvider);

  bool _initialized = false;

  @override
  HumanWorkDetailState build() {
    if (!_initialized) {
      _initialized = true;
      Future.microtask(() => fetchWorkCostByHid(0));
    }
    return HumanWorkDetailState.initial();
  }

  Future<void> fetchWorkCostByHid(int pid) async {
    final range = ref.read(workerProvider).dateTimeRange;
    final list = await _workCostUseCase.getWorkCostsByPlaceAndDate(
      hid,
      range.start,
      range.end,
      pid,
    );
    state = state.copyWith(
      workCostList: list,
      selectedPlaceId: pid,
    );
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
  }
}
