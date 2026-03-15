import 'dart:async';
import 'dart:io';

import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/controller/place_list_controller.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/revenue_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/total_price_bar.dart';

class PlaceController extends GetxController {
  PlaceController({required this.pid});
  final int pid;

  @override
  void onInit() {
    super.onInit();
    _initCategoryTapCallbacks();
    fetchTotalCostFromPlace();
    fetchAllRevenueFromPlace();

  }

  // Slidable closeAll 위한 BuildContext 리스트
  final List<BuildContext> slidableContexts = [];
  // DbHelper instance 생성
  DbHelper dbHelper = DbHelper();
  // DateTimeRange 오늘 날짜 기준 한 달로 초기화
  DateTimeRange dateTimeRange = getMonthDateRange(DateTime.now());
  late PlaceListController placeListController = Get.find<PlaceListController>();
  // TextEditingController 초기화
  TextEditingController mNameController = TextEditingController();
  TextEditingController mPriceController = TextEditingController();
  TextEditingController dialogRPriceController = TextEditingController();
  TextEditingController dialogRNameController = TextEditingController();
  TextEditingController rPriceController = TextEditingController();
  TextEditingController rNameController = TextEditingController();
  // dialog에서 선택한 category
  String? selectedDropdownCategory;
  // 화면에 보여줄 totalPriceBar에서 선택한 category
  // 토글버튼 상태값 초기화
  List<bool> toggleState = [false, false, true];
  DayTpye selectedDayType = DayTpye.whole;
  FilterType selectedFilterType = FilterType.all;
  DateTime dialogDateTime = DateTime.now();
  List<TotalCostModel> totalCostList = [];
  List<RevenueModel> revenueList = [];
  int get totalRevenue =>
      revenueList.fold(0, (sum, element) => sum + element.rprice);

  List<TotalCostModel> get rangeFilterList => totalCostList
      .where((element) =>
          element.getDateTime.isAfter(
              dateTimeRange.start.subtract(const Duration(microseconds: 1))) &&
          element.getDateTime
              .isBefore(dateTimeRange.end.add(const Duration(days: 1))))
      .toList();

  int get totalPrice =>
      rangeFilterList.fold(0, (sum, element) => sum + element.price);

  List<TotalCostModel> get filteredTotalCostList {
    switch (selectedFilterType) {
      case FilterType.all:
        return rangeFilterList;
      case FilterType.work:
        return rangeFilterList
            .where((element) => element.category == 'w')
            .toList()
          ..sort(
            (a, b) => a.wcomplete.compareTo(b.wcomplete),
          );
      case FilterType.material:
        return rangeFilterList
            .where((element) => element.category != 'w')
            .toList();
      case FilterType.notPay:
        return rangeFilterList
            .where((element) => element.wcomplete == 0)
            .toList();
      default:
        return rangeFilterList
            .where((element) => element.category == selectedFilterType.category)
            .toList();
    }
  }

  Map<String, CategoryTapCallback> categoryTapCallbacks = {};
  String alertText = '';

////////////////////// Method ///////////////////////////////////

  /// 디비에서 현장 정보 새로 들고오기 & update
  Future<void> fetchTotalCostFromPlace() async {
    totalCostList = await dbHelper.getTotalCostsForPlace(pid);
    update();
  }

  Future<void> fetchAllRevenueFromPlace() async {
    revenueList = await dbHelper.getAllRevenues(pid);
    update();
  }

  Future<void> deleteRevenue({required int rid}) async {
    await dbHelper.deleteRevenue(rid, pid);
    fetchAllRevenueFromPlace();
    placeListController.fetchAllPlace();
  }

  Future<void> updateRevenue({required int rid}) async {
    int rprice = int.tryParse(dialogRPriceController.text
            .trim()
            .replaceAll(RegExp(r'[,원]'), '')) ??
        0;
    String rname = dialogRNameController.text.trim() == ''
        ? '수익금'
        : dialogRNameController.text.trim();
    RevenueModel revenueModel = RevenueModel(
      rid: rid,
      rpid: -1,
      rname: rname,
      rprice: rprice,
      rorder: -1,
    );
    await dbHelper.updateRevenue(revenue: revenueModel, placeId: pid);
    fetchAllRevenueFromPlace();
    placeListController.fetchAllPlace();
  }

  Future<void> insertRevenue() async {
    int rprice = int.tryParse(
            rPriceController.text.trim().replaceAll(RegExp(r'[,원]'), '')) ??
        0;
    String rname =
        rNameController.text.trim() == '' ? '수익금' : rNameController.text.trim();
    if(rPriceController.text.trim().replaceAll(RegExp(r'[,원]'), '') == ''){
      alertText = '수익금을 입력해주세요';
      return;
    }
    await dbHelper.insertRevenue(pid: pid, rprice: rprice, rname: rname);
    fetchAllRevenueFromPlace();
    placeListController.fetchAllPlace();
    resetRevenueTextContoller();
    Get.dialog(saveDialog(text: '추가되었습니다.'));
  }

  void resetRevenueTextContoller() {
    rPriceController.text = '';
    rNameController.text = '';
  }

  void resetDialogRevenueTextContoller() {
    dialogRPriceController.text = '';
    dialogRNameController.text = '';
  }

  void updateRevenueController(String value) {
    rPriceController.text = value;
    update();
  }

  /// 현재 리스트 가격
  int get selectedPrice {
    int price = 0;
    for (var element in filteredTotalCostList) {
      price += element.price;
    }
    return price;
  }

  Future<void> changeDateTimeRange(index, BuildContext context) async {
    _setToggleState(index);
    await _setDateTimeRange(index, context);
    update();
    print(dateTimeRange);
    closeAllSliders();
  }

  void _setToggleState(int index) {
    for (int i = 0; i < toggleState.length; i++) {
      toggleState[i] = i == index;
    }
  }

  Future<void> _setDateTimeRange(int index, BuildContext context) async {
    if (index == 0) {
      dateTimeRange = await showRangePickerDialog(
            context: context,
            minDate: DateTime(2000),
            maxDate: DateTime(2099),
            highlightColor: Colors.green,
          ) ??
          dateTimeRange;
    } else if (index == 1) {
      dateTimeRange = DateTimeRange(
        start: DateTime(2000),
        end: DateTime(2099, 12, 31),
      );
    } else {
      dateTimeRange = getMonthDateRange(DateTime.now());
    }
  }

  // 인건비, 자재비 삭제
  Future<void> deleteCost(String category, int id) async {
    if (category == 'w') {
      await dbHelper.deleteWorkCost(id);
    } else {
      await dbHelper.deleteMaterialCost(id);
    }
    fetchTotalCostFromPlace();
    FetchData.fetchAllData();
  }

  // 인건비, 자재비 수정
  Future<void> updateCost(String category, int id, String date) async {
    String priceString = mPriceController.text.trim();
    priceString = priceString.replaceAll(RegExp(r'[,원]'), '');
    int? price = int.tryParse(priceString);

    if (category != 'w') {
      if (mNameController.text.isEmpty || price == null) {
        alertText = '모든 항목을 입력해 주세요.';
        update();
      } else {
        // 자재비
        alertText = '';
        MaterialCostModel materialCost = MaterialCostModel(
            mid: id,
            mname: mNameController.text.trim(),
            mdate: date,
            mcategory: selectedDropdownCategory!,
            mprice: price);
        await dbHelper.updateMaterialCostItem(materialCost);
        fetchTotalCostFromPlace();
        Get.back();
      }
    } else if (price == null) {
      alertText = '모든 항목을 입력해 주세요.';
      update();
    } else {
      // 인건비
      alertText = '';
      WorkCostModel workCost = WorkCostModel(
        wid: id,
        wdate: date,
        wprice: price,
        wcomplete: -1,
        wpid: 1,
      );
      await dbHelper.updateWorkCostItem(workCost);
      fetchTotalCostFromPlace();
      FetchData.fetchAllData();
      Get.back();
    }
  }

  // 미지급, 지급 완료 변경
  Future<void> updateWComplete(int wcomplete, int id) async {
    await dbHelper.toggleWorkCostCompletionStatus(wcomplete, id);
    FetchData.fetchAllData();
    fetchTotalCostFromPlace();
  }

  // 각 카테고리 선택 시 onTap 액션 초기화
  void _initCategoryTapCallbacks() {
    categoryTapCallbacks = {
      for (var type in FilterType.values)
        type.category: (category) => _changeFilterType(category, type)
    };
  }

  void _changeFilterType(String category, FilterType filterType) {
    selectedFilterType = filterType;
    closeAllSliders();
    update();
  }

  dropDownCategoryChangeAction(String value) {
    selectedDropdownCategory = value;
  }

  /////////////////////////
  // 엑셀 파일 생성 및 공유 메소드
  /////////////////////////
  Future<void> exportAndSharePlaceInfoToExcel(String pname) async {
    List<List<dynamic>> summaryCsvData = [];
    List<List<dynamic>> detailCsvData = [];

    // 세부 정보 조회
    List<Map<String, dynamic>> detailQueryResult =
        await dbHelper.getPlaceTotalCostsForCsv(dateTimeRange, pid);

    // 요약 정보 조회
    List<Map<String, dynamic>> summaryQueryResult =
        await dbHelper.getPlaceSummaryForCsv(pid);

    if (detailQueryResult.isEmpty) {
      Get.snackbar('알림', '추출할 데이터가 없습니다.');
      return;
    }

    // 현장 이름 추가
    detailCsvData.add(['', '현장 이름', pname]);
    detailCsvData.add([]);
    // 헤더 행 추가
    detailCsvData.add([''] + detailQueryResult.first.keys.toList());
    // 데이터 행 추가
    for (Map<String, dynamic> row in detailQueryResult) {
      detailCsvData.add(['' as dynamic] + row.values.toList());
    }

    // 요약 정보 데이터 처리
    if (summaryQueryResult.isNotEmpty) {
      summaryCsvData.add(['', '현장 이름', pname]);
      summaryCsvData.add([]);
      summaryCsvData.add(['', '항목', '금액']);
      // 요약 정보를 세로로 나열
      for (Map<String, dynamic> row in summaryQueryResult) {
        row.forEach((key, value) {
          summaryCsvData.add(['' as dynamic] + [key, value]);
        });
        summaryCsvData.add([]); // 요약 정보 간 간격을 두기 위해 빈 행 추가
      }
    } else {
      summaryCsvData.add(['요약 정보가 없습니다.']);
    }

    // 엑셀 파일 생성
    var excel = Excel.createExcel();
    Sheet detailSheet = excel['세부 정보'];
    Sheet summarySheet = excel['요약 정보'];

    try {
      excel.delete('Sheet1');
    } catch (e) {
      debugPrint('1');
    }

    // 세부 정보 데이터를 엑셀 시트에 추가
    for (int i = 0; i < detailCsvData.length; i++) {
      List row = detailCsvData[i];
      for (int j = 0; j < row.length; j++) {
        detailSheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i),
          (row[j] is String)
              ? TextCellValue(row[j].toString())
              : IntCellValue(int.tryParse(row[j].toString()) ?? 0),
        );
      }
    }

    // 요약 정보 데이터를 엑셀 시트에 추가
    for (int i = 0; i < summaryCsvData.length; i++) {
      List row = summaryCsvData[i];
      for (int j = 0; j < row.length; j++) {
        summarySheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i),
          (row[j] is String)
              ? TextCellValue(row[j].toString())
              : IntCellValue(int.tryParse(row[j].toString()) ?? 0),
        );
      }
    }

    // 앱 문서 디렉터리 경로 가져오기
    Directory appDocDir = await getApplicationDocumentsDirectory();
    // 엑셀 파일 경로 지정
    String excelFilePath =
        '${appDocDir.path}/$pname (${formatDateTimeRangeToString(dateTimeRange)}).xlsx';

    // 엑셀 파일 저장
    var bytes = excel.encode();
    File excelFile = File(excelFilePath);
    await excelFile.writeAsBytes(bytes!);

    // 엑셀 파일 공유
    Share.shareXFiles(
      [XFile(excelFile.path)],
      subject: '$pname (${formatDateTimeRangeToString(dateTimeRange)})',
    ).then((result) {
      if (result.status == ShareResultStatus.success) {
        Get.dialog(saveDialog(text: '공유되었습니다.'));
      }
    }).catchError((error) {
      Get.dialog(saveDialog(text: '공유에 실패했습니다.\n다시 시도해주세요.'));
    });
  }

  ///////////////////////
  // Slidable 닫기 위한 메소드
  ///////////////////////
  void registerSlidable(BuildContext context) {
    if (!slidableContexts.contains(context)) {
      slidableContexts.add(context);
    }
  }

  void closeAllSliders() {
    for (var context in List.from(slidableContexts)) {
      try {
        Slidable.of(context)?.close();
      } catch (e) {
        debugPrint(e.toString());
      }
    }
    slidableContexts.clear(); // 모든 컨텍스트 제거
  }
}
