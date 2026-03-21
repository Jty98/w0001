import 'dart:io';

import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/data/datasources/local/materialcost_local_data_source.dart';
import 'package:w0001/data/datasources/local/revenue_local_data_source.dart';
import 'package:w0001/data/datasources/local/workcost_local_data_source.dart';
import 'package:w0001/data/model/materialcost_model.dart';
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
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show dbHelperProvider, placeUseCaseProvider;
import 'package:w0001/util/funtions.dart';

class PlaceDetailState {
  const PlaceDetailState({
    required this.pid,
    required this.dateTimeRange,
    required this.toggleState,
    required this.selectedDayType,
    required this.selectedFilterType,
    required this.selectedDropdownCategory,
    required this.dialogDateTime,
    required this.totalCostList,
    required this.revenueList,
    required this.alertText,
    required this.isLoading,
  });

  final int pid;
  final DateTimeRange dateTimeRange;
  final List<bool> toggleState;
  final DayTpye selectedDayType;
  final FilterType selectedFilterType;
  final String? selectedDropdownCategory;
  final DateTime dialogDateTime;
  final List<TotalCostModel> totalCostList;
  final List<RevenueModel> revenueList;
  final String alertText;
  final bool isLoading;

  factory PlaceDetailState.initial(int pid) => PlaceDetailState(
        pid: pid,
        dateTimeRange: getMonthDateRange(DateTime.now()),
        toggleState: const [false, false, true],
        selectedDayType: DayTpye.whole,
        selectedFilterType: FilterType.all,
        selectedDropdownCategory: null,
        dialogDateTime: DateTime.now(),
        totalCostList: const [],
        revenueList: const [],
        alertText: '',
        isLoading: false,
      );

  PlaceDetailState copyWith({
    DateTimeRange? dateTimeRange,
    List<bool>? toggleState,
    DayTpye? selectedDayType,
    FilterType? selectedFilterType,
    String? selectedDropdownCategory,
    DateTime? dialogDateTime,
    List<TotalCostModel>? totalCostList,
    List<RevenueModel>? revenueList,
    String? alertText,
    bool? isLoading,
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
      totalCostList: totalCostList ?? this.totalCostList,
      revenueList: revenueList ?? this.revenueList,
      alertText: alertText ?? this.alertText,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final workCostLocalDataSourceProvider = Provider<WorkCostLocalDataSource>(
  (ref) => WorkCostLocalDataSourceImpl(ref.read(dbHelperProvider)),
);
final workCostRepositoryProvider = Provider<WorkCostRepository>(
  (ref) => WorkCostRepositoryImpl(ref.read(workCostLocalDataSourceProvider)),
);
final workCostUseCaseProvider = Provider<WorkCostUseCase>(
  (ref) => WorkCostUseCase(ref.read(workCostRepositoryProvider)),
);

final materialCostLocalDataSourceProvider = Provider<MaterialCostLocalDataSource>(
  (ref) => MaterialCostLocalDataSourceImpl(ref.read(dbHelperProvider)),
);
final materialCostRepositoryProvider = Provider<MaterialCostRepository>(
  (ref) =>
      MaterialCostRepositoryImpl(ref.read(materialCostLocalDataSourceProvider)),
);
final materialCostUseCaseProvider = Provider<MaterialCostUseCase>(
  (ref) => MaterialCostUseCase(ref.read(materialCostRepositoryProvider)),
);

final revenueLocalDataSourceProvider = Provider<RevenueLocalDataSource>(
  (ref) => RevenueLocalDataSourceImpl(ref.read(dbHelperProvider)),
);
final revenueRepositoryProvider = Provider<RevenueRepository>(
  (ref) => RevenueRepositoryImpl(ref.read(revenueLocalDataSourceProvider)),
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

  // 기존 controller에서 쓰던 입력 컨트롤러들 (UI에서 계속 재사용)
  final TextEditingController mNameController = TextEditingController();
  final TextEditingController mPriceController = TextEditingController();
  final TextEditingController dialogRPriceController = TextEditingController();
  final TextEditingController dialogRNameController = TextEditingController();
  final TextEditingController rPriceController = TextEditingController();
  final TextEditingController rNameController = TextEditingController();

  @override
  PlaceDetailState build() {
    ref.onDispose(() {
      mNameController.dispose();
      mPriceController.dispose();
      dialogRPriceController.dispose();
      dialogRNameController.dispose();
      rPriceController.dispose();
      rNameController.dispose();
    });

    if (!_initialized) {
      _initialized = true;
      Future.microtask(() async {
        await fetchTotalCostFromPlace();
        await fetchAllRevenueFromPlace();
      });
    }
    return PlaceDetailState.initial(pid);
  }

  void setDialogDateTime(DateTime value) {
    state = state.copyWith(dialogDateTime: value);
  }

  void clearAlertText() {
    state = state.copyWith(alertText: '');
  }

  // ===== computed (기존 controller getter 대체) =====

  List<TotalCostModel> get rangeFilterList => state.totalCostList
      .where((e) =>
          e.getDateTime.isAfter(
              state.dateTimeRange.start.subtract(const Duration(microseconds: 1))) &&
          e.getDateTime.isBefore(
              state.dateTimeRange.end.add(const Duration(days: 1))))
      .toList();

  int get totalPrice => rangeFilterList.fold(0, (sum, e) => sum + e.price);

  int get totalRevenue => state.revenueList.fold(0, (sum, e) => sum + e.rprice);

  List<TotalCostModel> get filteredTotalCostList {
    switch (state.selectedFilterType) {
      case FilterType.all:
        return rangeFilterList;
      case FilterType.work:
        return rangeFilterList
            .where((e) => e.category == 'w')
            .toList()
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

  void resetRevenueTextController() {
    rPriceController.text = '';
    rNameController.text = '';
  }

  void resetDialogRevenueTextController() {
    dialogRPriceController.text = '';
    dialogRNameController.text = '';
  }

  void updateRevenueController(String value) {
    rPriceController.text = value;
  }

  void dropDownCategoryChangeAction(String value) {
    state = state.copyWith(selectedDropdownCategory: value);
  }

  void changeFilterType(FilterType filterType) {
    state = state.copyWith(selectedFilterType: filterType);
  }

  Future<void> fetchTotalCostFromPlace() async {
    state = state.copyWith(isLoading: true);
    final list = await _placeUseCase.getTotalCostsForPlace(pid);
    state = state.copyWith(totalCostList: list, isLoading: false);
  }

  Future<void> fetchAllRevenueFromPlace() async {
    final list = await _revenueUseCase.getAllRevenues(pid);
    state = state.copyWith(revenueList: list);
  }

  Future<void> deleteRevenue({required int rid}) async {
    await _revenueUseCase.deleteRevenue(rid, pid);
    await fetchAllRevenueFromPlace();
  }

  Future<void> updateRevenue({required int rid}) async {
    final rprice = int.tryParse(
          dialogRPriceController.text.trim().replaceAll(RegExp(r'[,원]'), ''),
        ) ??
        0;
    final rname =
        dialogRNameController.text.trim().isEmpty ? '수익금' : dialogRNameController.text.trim();
    final model = RevenueModel(
      rid: rid,
      rpid: -1,
      rname: rname,
      rprice: rprice,
      rorder: -1,
    );
    await _revenueUseCase.updateRevenue(revenue: model, placeId: state.pid);
    await fetchAllRevenueFromPlace();
  }

  Future<void> insertRevenue() async {
    final rprice = int.tryParse(
          rPriceController.text.trim().replaceAll(RegExp(r'[,원]'), ''),
        ) ??
        0;
    final rname = rNameController.text.trim().isEmpty ? '수익금' : rNameController.text.trim();

    if (rPriceController.text.trim().replaceAll(RegExp(r'[,원]'), '').isEmpty) {
      state = state.copyWith(alertText: '수익금을 입력해주세요');
      return;
    }

    await _revenueUseCase.insertRevenue(pid: pid, rprice: rprice, rname: rname);
    await fetchAllRevenueFromPlace();
    resetRevenueTextController();
  }

  Future<void> deleteCost(String category, int id) async {
    if (category == 'w') {
      await _workCostUseCase.deleteWorkCost(id);
    } else {
      await _materialCostUseCase.deleteMaterialCost(id);
    }
    await fetchTotalCostFromPlace();
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
      await fetchTotalCostFromPlace();
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
      await fetchTotalCostFromPlace();
    }
  }

  Future<void> updateWComplete(int wcomplete, int id) async {
    await _workCostUseCase.toggleWorkCostCompletionStatus(wcomplete, id);
    await fetchTotalCostFromPlace();
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
      nextRange = await showRangePickerDialog(
            context: context,
            minDate: DateTime(2000),
            maxDate: DateTime(2099),
            highlightColor: Colors.green,
          ) ??
          nextRange;
    } else if (index == 1) {
      nextType = DayTpye.whole;
      nextRange = DateTimeRange(start: DateTime(2000), end: DateTime(2099, 12, 31));
    } else {
      nextType = DayTpye.month;
      nextRange = getMonthDateRange(DateTime.now());
    }

    state = state.copyWith(
      toggleState: toggle,
      selectedDayType: nextType,
      dateTimeRange: nextRange,
    );
  }

  Future<void> exportAndSharePlaceInfoToExcel(String pname) async {
    final pid = state.pid;
    final dateTimeRange = state.dateTimeRange;

    final detailQueryResult =
        await _placeUseCase.getPlaceTotalCostsForCsv(dateTimeRange.start, dateTimeRange.end, pid);
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
        '${appDocDir.path}/$pname (${formatDateTimeRangeToString(dateTimeRange)}).xlsx';
    final bytes = excel.encode();
    final excelFile = File(excelFilePath);
    await excelFile.writeAsBytes(bytes!);

    await Share.shareXFiles(
      [XFile(excelFile.path)],
      subject: '$pname (${formatDateTimeRangeToString(dateTimeRange)})',
    );
  }
}

