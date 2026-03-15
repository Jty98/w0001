import 'dart:io';

import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';

class WorkerController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    initValues();
    fetchWorkCost();
    fetchWorkerInfo();
  }

  DateTimeRange dateTimeRange = getMonthDateRange(DateTime.now());
  DateTime selectDay = DateTime.now();
  var dbHelper = DbHelper();
  List<bool> toggleState = [false, false, true];

  late TextEditingController workerNameController;
  late TextEditingController workerNumController;
  late TextEditingController workerMemoController;
  late TextEditingController searchWorkerDetailTextContoller;
  late TextEditingController searchWorkerTextContoller;

  int workListCount = 0;
  List<HumanModel> workerInfoList = [];
  List<HumanModel> filteredWorkerList = [];
  bool isEditing = false;
  bool isStarred = false;
  bool get isTaxApply => taxState == TaxState.taxOn;

  // Slidable closeAll 위한 BuildContext 리스트
  final List<BuildContext> slidableContexts = [];
  final Map<int, ExpansionTileController> expansionTileControllerMap = {};

  /// 체크된 항목 데이터 저장 맵
  Map<int, CheckboxData> checkboxStates = {};
  List<int> get selectedWidList => checkboxStates.entries
      .where((entry) => entry.value.isSelected)
      .map((entry) => entry.key)
      .toList();
  int get selectedCount => selectedWidList.length;
  TaxState taxState = TaxState.taxOff;
  DayTpye dayState = DayTpye.whole;
  CompleteState completeState = CompleteState.whole;

  /// filterdHumanList를 선택했을 때 그 인덱스를 listview 외부에서도 알 수 있게 하기 위해.
  int selectedIndex = -1;

  List<TotalWorkCostModel> totalWorkCostList = [];
  List<TotalWorkCostModel> filteredTotalWorkCostList = [];

  int get totalCost {
    int price = 0;
    for (var element in filteredTotalWorkCostList) {
      price += element.price;
    }
    return price;
  }

  int get totalIncompleteCost {
    int price = 0;
    for (var element in filteredTotalWorkCostList) {
      if (element.wcomplete == 0) {
        price += element.price;
      }
    }
    return price;
  }

  int incompleteCostByHid(int hid) {
    int total = 0;
    checkboxStates.forEach((key, data) {
      if (data.hid == hid && data.isSelected) {
        total += data.price;
      }
    });
    return total;
  }

  int get selectedIncompleteCost {
    int total = 0;
    checkboxStates.forEach((key, data) {
      if (data.isSelected) {
        total += data.price;
      }
    });
    return total;
  }

  void toggleCheckboxState(int itemId) {
    if (checkboxStates.containsKey(itemId)) {
      checkboxStates[itemId]!.isSelected = !checkboxStates[itemId]!.isSelected;
      update(); // Notify the UI to rebuild
    }
  }

  // Method to initialize checkbox states with price
  void initializeCheckboxState(int wid, int price, int hid) {
    if (!checkboxStates.containsKey(wid)) {
      checkboxStates[wid] =
          CheckboxData(isSelected: false, price: price, hid: hid);
    }
  }

  Future<void> fetchWorkCost() async {
    totalWorkCostList = await dbHelper.getWorkCostsByDateRange(dateTimeRange);
    filteredTotalWorkCostList = totalWorkCostList;
    searchWoker(searchWorkerTextContoller.text.trim());
    update();
  }

  List<String> getUniqueHuman() {
    var tempList = isIncomplete
        ? filteredTotalWorkCostList
            .where((element) => element.wcomplete == 0)
            .toList()
        : filteredTotalWorkCostList;
    return tempList
        .map((model) => 'name:${model.hname}#number:${model.hnumber}')
        .toSet()
        .toList();
  }

  bool get isIncomplete => completeState == CompleteState.incomplete;

  void initValues() {
    workerNameController = TextEditingController();
    workerNumController = TextEditingController();
    workerMemoController = TextEditingController();
    searchWorkerDetailTextContoller = TextEditingController();
    searchWorkerTextContoller = TextEditingController();
  }

  Future<void> showDateTimeRangePicker(context) async {
    dateTimeRange = await showRangePickerDialog(
          context: context,
          minDate: DateTime(2000),
          maxDate: DateTime(2099),
          highlightColor: Colors.green,
        ) ??
        DateTimeRange(
          start: DateTime.now(),
          end: DateTime.now(),
        );
    fetchWorkCost();
  }

  Future<void> updateWComplete(int wcomplete, int id) async {
    await dbHelper.toggleWorkCostCompletionStatus(wcomplete, id);
    FetchData.fetchAllData();
  }

  Future<void> changeDateTime(BuildContext context) async {
    selectDay = await showDatePickerDialog(
          context: context,
          minDate: DateTime(2000),
          maxDate: DateTime(2099),
        ) ??
        DateTime.now();
    update();
  }

//--------------사람관리 view filter---------------

  void searchWoker(value) {
    filteredTotalWorkCostList = totalWorkCostList
        .where((humanTotal) =>
            humanTotal.hname.toLowerCase().contains(value.toLowerCase()))
        .toList();
    update();
  }

  void resetSearchText() {
    searchWorkerTextContoller.text = '';
    filteredTotalWorkCostList = totalWorkCostList;
    update();
  }

  Future<void> selectToggleButton(index, BuildContext context) async {
    if (index == 0) {
      toggleState[0] = true;
      toggleState[1] = false;
      toggleState[2] = false;
      dateTimeRange = await showRangePickerDialog(
            context: context,
            minDate: DateTime(2000),
            maxDate: DateTime(2099),
            highlightColor: Colors.green,
          ) ??
          dateTimeRange;
    } else if (index == 1) {
      toggleState[0] = false;
      toggleState[1] = true;
      toggleState[2] = false;
      dateTimeRange = DateTimeRange(
        start: DateTime(2000),
        end: DateTime(2099, 12, 31),
      );
    } else {
      toggleState[0] = false;
      toggleState[1] = false;
      toggleState[2] = true;
      dateTimeRange = getMonthDateRange(DateTime.now());
    }
    checkboxStates = {};
    fetchWorkCost();
  }

  void taxStateValueChanged(value) {
    if (value != null) {
      taxState = value;
    }
    update();
  }

  void completeStateValueChanged(value) {
    collapseAllExpansionTiles();
    if (value != null) {
      completeState = value;
    }
    closeAllSliders();
    update();
  }

  //------사람추가 View  ----------
  Future<void> fetchWorkerInfo() async {
    workerInfoList = await dbHelper.getAllWorkers();
    filteredWorkerList = workerInfoList;
    update();
  }

  void searchWokerInfo(value) {
    filteredWorkerList = workerInfoList
        .where(
            (human) => human.hname.toLowerCase().contains(value.toLowerCase()))
        .toList();
    update();
  }

  Future<void> _insertWorker() async {
    String hname = workerNameController.text.trim();
    String hnumber = workerNumController.text.trim();
    String? hmemo = workerMemoController.text.isNotEmpty
        ? workerMemoController.text.trim()
        : null;

    if (hname.isEmpty) {
      Get.closeAllSnackbars();
      Get.snackbar('알림', '이름을 입력해 주세요.', snackPosition: SnackPosition.BOTTOM);
    } else if (workerInfoList.any((worker) =>
        worker.hname.toLowerCase() ==
        workerNameController.text.toLowerCase())) {
      Get.closeAllSnackbars();
      Get.snackbar('중복된 이름이 있습니다', '다른 이름으로 등록해 주세요.',
          snackPosition: SnackPosition.BOTTOM);
    } else {
      HumanModel worker = HumanModel(
        hname: hname,
        hnumber: hnumber,
        hstar: 0,
        hmemo: hmemo,
        hdelete: 0,
      );
      await dbHelper.addWorker(worker);
      Get.dialog(saveDialog(text: '등록되었습니다.'));
      workerNameController.text = '';
      workerNumController.text = '';
      workerMemoController.text = '';
      fetchWorkerInfo();
    }
  }

  /// 선택 항목들 완료로 변경
  void updateWorkCostsToComplete() {
    Get.dialog(
      deleteDialog(
        content: '선택 항목을 모두 지급하시겠습니까?',
        onPressed: () async {
          try {
            await dbHelper.updateWorkCostsToComplete(selectedWidList);
          } catch (e) {
            Get.dialog(saveDialog(text: '실패했습니다.'));
            return;
          }
          checkboxStates = {};
          Get.back();
          FetchData.fetchAllData();
        },
      ),
    );
  }

  Future<void> _modifyWorkerInfo(int index) async {
    String hname = workerNameController.text.trim();
    String hnumber = workerNumController.text.trim();
    String? hmemo = workerMemoController.text.isNotEmpty
        ? workerMemoController.text.trim()
        : null;

    List<HumanModel> tempList = List.from(filteredWorkerList);
    tempList.removeAt(index);

    if (hname.isEmpty) {
      Get.closeAllSnackbars();
      Get.snackbar('알림', '이름을 입력해 주세요.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (tempList.any((worker) =>
        worker.hname.toLowerCase() ==
        workerNameController.text.toLowerCase())) {
      Get.closeAllSnackbars();
      Get.snackbar('중복된 이름이 있습니다', '다른 이름으로 등록해 주세요.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    HumanModel updatedWorker = HumanModel(
      hid: filteredWorkerList[selectedIndex].hid,
      hname: hname,
      hnumber: hnumber,
      hmemo: hmemo,
      hstar: filteredWorkerList[index].hstar,
      hdelete: 0,
    );

    await dbHelper.updateWorker(updatedWorker);
    workerNameController.text = '';
    workerNumController.text = '';
    workerMemoController.text = '';
    isEditing = !isEditing;
    fetchWorkerInfo();
  }

  void showWorkerInfo(
      int index, String workerName, String workerNum, String workerMemo) {
    selectedIndex = index;
    isEditing = true;
    workerNameController.text = workerName;
    workerNumController.text = workerNum;
    workerMemoController.text = workerMemo;
    update();
  }

  void editButtonAction() async {
    isEditing ? await _modifyWorkerInfo(selectedIndex) : await _insertWorker();
    FetchData.fetchAllData();
  }

  void refreshAction() {
    workerNameController.text = '';
    workerNumController.text = '';
    workerMemoController.text = '';
    searchWorkerDetailTextContoller.text = '';
    isEditing = false;
    fetchWorkerInfo();
  }

  Future<void> updateWorkerDelete(int index) async {
    int hid = filteredWorkerList[index].hid!;
    workerNameController.text = '';
    workerNumController.text = '';
    workerMemoController.text = '';
    isEditing = false;
    await dbHelper.deleteWorker(hid);
    fetchWorkerInfo();
  }

  Future<void> updateHstarFromWorkerList(int index) async {
    bool isStared = filteredWorkerList[index].hstar == 1 ? false : true;
    int hid = filteredWorkerList[index].hid!;

    await dbHelper.toggleWorkerStarStatus(hid, isStared);
    fetchWorkerInfo();
  }

  Future<void> updateHstar({required int hid, required int hstar}) async {
    bool isStared = hstar == 1 ? false : true;
    await dbHelper.toggleWorkerStarStatus(hid, isStared);
    fetchWorkCost();
  }

  /// 엑셀파일 추출 및 전송
  Future<void> exportAndSendWorkCostToExcel(context) async {
    List<List<dynamic>> detailCsvData = [];
    List<List<dynamic>> totalCsvData = [];

    // 쿼리 실행하여 결과 가져오기
    List<Map<String, dynamic>> detailQueryResult =
        await dbHelper.getWorkCostDetailsForCsv(dateTimeRange);

    List<Map<String, dynamic>> totalQueryResult =
        await dbHelper.getWorkCostTotalsForCsv(dateTimeRange);

    if (detailQueryResult.isEmpty) {
      Get.snackbar('알림', '추출할 데이터가 없습니다.');
      return;
    }

    // 헤더 행 추가
    detailCsvData.add(detailQueryResult.first.keys.toList());
    totalCsvData.add(totalQueryResult.first.keys.toList());

    // 데이터 행 추가
    for (Map<String, dynamic> row in detailQueryResult) {
      detailCsvData.add(row.values.toList());
    }

    for (Map<String, dynamic> row in totalQueryResult) {
      totalCsvData.add(row.values.toList());
    }

    // 엑셀 파일 생성
    var excel = Excel.createExcel();
    Sheet totalSheet = excel['총계'];
    Sheet detailSheet = excel['세부사항'];

    try {
      excel.delete('Sheet1');
    } catch (e) {
      //
    }

    // CSV 데이터를 엑셀 시트에 추가
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
    for (int i = 0; i < totalCsvData.length; i++) {
      List row = totalCsvData[i];
      for (int j = 0; j < row.length; j++) {
        totalSheet.updateCell(
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
        '${appDocDir.path}/인건비 총계 (${formatDateTimeRangeToString(dateTimeRange)}).xlsx';

    // 엑셀 파일 저장
    var bytes = excel.encode();
    File excelFile = File(excelFilePath);
    await excelFile.writeAsBytes(bytes!);

    // 엑셀 파일 공유
    await Share.shareXFiles(
      [XFile(excelFile.path)],
      subject: '인건비 총계 (${formatDateTimeRangeToString(dateTimeRange)})',
    ).then((result) {
      if (result.status == ShareResultStatus.success) {
        Get.dialog(saveDialog(text: '공유되었습니다.'));
      }
    }).catchError((error) {
      Get.dialog(saveDialog(text: '공유에 실패했습니다.\n다시 시도해주세요.'));
    });
  }

  // Worker 한 명의 모든 정보 리턴
  WorkCostData processWorkCostData(String uniqueHuman) {
    var splitHuman = uniqueHuman.split('#');
    var hname = splitHuman[0].split(':')[1];
    var hnumber = splitHuman[1].split(':')[1];

    final tempList = isIncomplete
        ? totalWorkCostList.where((element) => element.wcomplete == 0).toList()
        : totalWorkCostList;

    final filteredList = tempList
        .where((element) =>
            'name:${element.hname}#number:${element.hnumber}' == uniqueHuman)
        .toList();

    if (filteredList.isEmpty) {
      return WorkCostData(
          pcomplete: 1,
          hname: hname,
          hnumber: hnumber,
          hid: 0,
          hstar: 0,
          totalPrice: 0,
          incompletePrice: 0,
          filteredList: []);
    }

    int hid = filteredList[0].hid;
    int hstar = filteredList[0].hstar;
    int totalPrice = filteredList.fold(0, (sum, item) => sum + item.price);
    int incompletePrice = filteredList.fold(
      0,
      (sum, item) => item.wcomplete == 0 ? sum + item.price : sum,
    );
    return WorkCostData(
        pcomplete: 1,
        hname: hname,
        hnumber: hnumber,
        hid: hid,
        hstar: hstar,
        totalPrice: totalPrice,
        incompletePrice: incompletePrice,
        filteredList: filteredList);
  }

  ///////////////////////
  // Slidable 닫기 위한 메소드
  ///////////////////////
  void registerSlidable(BuildContext context) {
    if (!slidableContexts.contains(context)) {
      slidableContexts.add(context);
    }
  }

  void registerExpantionTile(int hid, ExpansionTileController controller) {
    expansionTileControllerMap[hid] = controller;
  }

  void closeAllSliders() {
    for (var context in List.from(slidableContexts)) {
      try {
        Slidable.of(context)?.close();
      } catch (e) {
        // debugPrint(e.toString());
      }
    }
    slidableContexts.clear(); // 모든 컨텍스트 제거
  }

  void collapseAllExpansionTiles() {
    expansionTileControllerMap.forEach((key, value) {
      try {
        value.collapse();
      } catch (e) {
        // debugPrint(e.toString());
      }
    });
    // update();
  }
}

class WorkCostData {
  final String hname;
  final String hnumber;
  final int hid;
  final int hstar;
  final int totalPrice;
  final int pcomplete;
  final int incompletePrice;
  bool isExpanded = false;
  final List<TotalWorkCostModel> filteredList;

  WorkCostData({
    required this.hname,
    required this.hnumber,
    required this.hid,
    required this.pcomplete,
    required this.hstar,
    required this.totalPrice,
    required this.incompletePrice,
    required this.filteredList,
  });
}

/// value: check 상태
/// price: 선택된 항목 금액
/// hid: 선택된 항목의 hid
class CheckboxData {
  bool isSelected;
  final int price;
  final int hid;

  CheckboxData({
    required this.isSelected,
    required this.price,
    required this.hid,
  });
}
