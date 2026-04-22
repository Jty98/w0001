import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/local/calendar_local_data_source.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/data/repository/calendar_impl.dart';
import 'package:w0001/domain/repository/calendar_abst.dart';
import 'package:w0001/domain/use_case/calendar_use_case.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show materialCostUseCaseProvider, workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show dbHelperProvider;
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/util/fetch_data.dart' show rootProviderContainer;
import 'package:w0001/util/funtions.dart';

class CalendarState {
  const CalendarState({
    required this.selectedDay,
    required this.focusedDay,
    required this.totalCostList,
    required this.events,
    required this.selectedFilterType,
    required this.dropDownSelectedCategory,
    required this.alertText,
    required this.dialogDateTime,
  });

  final DateTime selectedDay;
  final DateTime focusedDay;
  final List<TotalCostModel> totalCostList;
  final Map<DateTime, List<String>> events;
  final FilterType selectedFilterType;
  final String? dropDownSelectedCategory;
  final String alertText;
  final DateTime dialogDateTime;

  factory CalendarState.initial() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return CalendarState(
      selectedDay: now,
      focusedDay: day,
      totalCostList: const [],
      events: const {},
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
    FilterType? selectedFilterType,
    String? dropDownSelectedCategory,
    bool clearDropDownSelectedCategory = false,
    String? alertText,
    DateTime? dialogDateTime,
  }) {
    return CalendarState(
      selectedDay: selectedDay ?? this.selectedDay,
      focusedDay: focusedDay ?? this.focusedDay,
      totalCostList: totalCostList ?? this.totalCostList,
      events: events ?? this.events,
      selectedFilterType: selectedFilterType ?? this.selectedFilterType,
      dropDownSelectedCategory: clearDropDownSelectedCategory
          ? null
          : (dropDownSelectedCategory ?? this.dropDownSelectedCategory),
      alertText: alertText ?? this.alertText,
      dialogDateTime: dialogDateTime ?? this.dialogDateTime,
    );
  }
}

final calendarLocalDataSourceProvider = Provider<CalendarLocalDataSource>(
  (ref) => CalendarLocalDataSourceImpl(ref.read(dbHelperProvider)),
);

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepositoryImpl(ref.read(calendarLocalDataSourceProvider)),
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

  bool _initialized = false;

  @override
  CalendarState build() {
    ref.onDispose(() {
      mNameController.dispose();
      mPriceController.dispose();
    });
    if (!_initialized) {
      _initialized = true;
      Future.microtask(() async {
        await fetchAllEvents();
        await fetchTotalCost();
      });
    }
    return CalendarState.initial();
  }

  /// [FetchData] 등 컨텍스트 없는 호출에서 캘린더만 갱신
  Future<void> refreshForFetchData() async {
    await fetchAllEvents();
    await fetchTotalCost();
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
              (element) => element.category == state.selectedFilterType.category,
            )
            .toList();
    }
  }

  int get getFilteredListPrice {
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

  void setFilterType(FilterType filterType) {
    state = state.copyWith(selectedFilterType: filterType);
  }

  Future<void> fetchAllEvents() async {
    final map = await _calendarUseCase.getAllEvents();
    state = state.copyWith(events: map);
  }

  List<String> getEventsForDay(DateTime day) {
    final selected = DateTime(day.year, day.month, day.day);
    return state.events[selected] ?? [];
  }

  Future<void> fetchTotalCost() async {
    final list =
        await _calendarUseCase.getTotalCostsByDate(state.focusedDay);
    state = state.copyWith(totalCostList: list);
  }

  Future<void> onDaySelected(DateTime selectedDay, DateTime focused) async {
    state = state.copyWith(
      selectedDay: selectedDay,
      focusedDay: selectedDay,
    );
    await fetchTotalCost();
  }

  Future<void> _syncLikeFetchAllData() async {
    await refreshForFetchData();
    final c = rootProviderContainer;
    if (c != null) {
      await c.read(workerProvider.notifier).refreshFromGlobalFetch();
    }
  }

  Future<void> deleteCost(String category, int id) async {
    if (category == 'w') {
      await _workCostUseCase.deleteWorkCost(id);
    } else {
      await _materialCostUseCase.deleteMaterialCost(id);
    }
    await _syncLikeFetchAllData();
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
      await _syncLikeFetchAllData();
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
    await _syncLikeFetchAllData();
    return true;
  }

  Future<String> updateWComplete(int wcomplete, int id) async {
    await _workCostUseCase.toggleWorkCostCompletionStatus(wcomplete, id);
    await _syncLikeFetchAllData();
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
    mPriceController.text =
        getPrice(price: element.price, isContainWon: false);
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
