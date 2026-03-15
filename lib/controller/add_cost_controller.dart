import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:w0001/controller/worker_controller.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';

class AddCostController extends GetxController {
  var hNameController = TextEditingController();
  var hNumController = TextEditingController();
  var hMemoController = TextEditingController();
  var mNameController = TextEditingController();
  FocusNode mNameFocus = FocusNode();
  var mPriceController = TextEditingController();
  FocusNode mPriceFocus = FocusNode();
  var wPriceController = TextEditingController();
  FocusNode wPriceFocus = FocusNode();

  List<MaterialCostModel> materialCostList = [];
  List<WorkCostModel> workCostList = [];
  bool get isAllEmpty => workCostList.isEmpty && materialCostList.isEmpty;
  DbHelper dbHelper = DbHelper();
  DateTime selectDay = DateTime.now();
  String alertText = '';

  // 선택된 인부 hid 저장용
  PlaceModel? selectedPlace;
  HumanModel? selectedWorker;
  String? selectedCategory;

  void placeChangeAction(context, PlaceModel value) {
    selectedPlace = value;
    try {
      FocusScope.of(context).unfocus();
    } catch (e) {
      return;
    }
    update();
  }

  void workerChangeAction(HumanModel value) {
    selectedWorker = value;
    wPriceFocus.requestFocus();
  }

  void categoryChangeAction(String value) {
    selectedCategory = value;
    mNameFocus.requestFocus();
  }

  void clearDialogText() {
    alertText = '';
    hMemoController.text = '';
    hNameController.text = '';
    hNumController.text = '';
    // hNum2Controller.text = '';
  }

  Future<void> insertWorker() async {
    String hName = hNameController.text.trim();
    String hNum = hNumController.text.trim();
    // String hNum2 = hNum2Controller.text.trim();
    String? hMemo =
        hMemoController.text.isEmpty ? null : hMemoController.text.trim();
    List<HumanModel> workerInfoList = await dbHelper.getAllWorkers();

    alertText = '';
    if (hName.isEmpty) {
      alertText = '이름을 입력해주세요.';
      update();
      return;
    } else if (workerInfoList
        .where((element) => element.hname == hName)
        .toList()
        .isNotEmpty) {
      alertText = '중복된 이름입니다.';
      update();
      return;
    } else {
      alertText = '';
      HumanModel worker = HumanModel(
        hname: hName,
        hnumber: hNum,
        hmemo: hMemo,
        hstar: 0,
        hdelete: 0,
      );
      await dbHelper.addWorker(worker);
      Get.find<WorkerController>().fetchWorkerInfo();
      hNameController.text = '';
      hNumController.text = '';
      hMemoController.text = '';
      Get.back();
    }
  }

  Future<void> changeDateTime(BuildContext context) async {
    selectDay = await showDatePickerDialog(
          context: context,
          minDate: DateTime(2000),
          maxDate: DateTime(2099),
          centerLeadingDate: true,
        ) ??
        selectDay;
    update();
  }

  addMaterialCostList(context) {
    String mpriceString = mPriceController.text.trim();
    mpriceString = mpriceString.replaceAll(RegExp(r'[,원]'), '');
    int? mprice = int.tryParse(mpriceString);
    String mname = mNameController.text.trim();

    if (selectedPlace == null) {
      Get.closeAllSnackbars();
      Get.snackbar('알림', '현장을 선택해주세요.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (selectedCategory == null) {
      Get.snackbar('알림', '카테고리를 선택해주세요.', snackPosition: SnackPosition.BOTTOM);
      return;
    } else if (mname.isEmpty || mprice == null) {
      Get.closeAllSnackbars();
      Get.snackbar('알림', '모든 항목을 입력해주세요.', snackPosition: SnackPosition.BOTTOM);
    } else {
      var model = MaterialCostModel(
        mcategory: selectedCategory!,
        pname: selectedPlace!.pname,
        mpid: selectedPlace!.pid,
        mname: mname,
        mdate: selectDay.toString(),
        mprice: mprice,
      );
      materialCostList.add(model);
      mNameController.text = '';
      mPriceController.text = '';
      FocusScope.of(context).unfocus();
      update();
    }
  }

  void addWorkCostList(context) {
    String wpriceString = wPriceController.text.trim();
    wpriceString = wpriceString.replaceAll(RegExp(r'[,원]'), '');
    int? wprice = int.tryParse(wpriceString);

    if (selectedPlace == null) {
      Get.closeAllSnackbars();
      Get.snackbar('알림', '현장을 선택해주세요.', snackPosition: SnackPosition.BOTTOM);
    } else if (selectedWorker == null) {
      Get.closeAllSnackbars();
      Get.snackbar('알림', '사람을 선택해주세요.', snackPosition: SnackPosition.BOTTOM);
      return;
    } else if (wprice == null) {
      Get.closeAllSnackbars();
      Get.snackbar('알림', '금액을 입력해주세요.', snackPosition: SnackPosition.BOTTOM);
      return;
    } else {
      WorkCostModel workCost = WorkCostModel(
        wcomplete: 0,
        wdate: selectDay.toString(),
        hname: selectedWorker!.hname,
        wprice: wprice,
        wpid: selectedPlace!.pid!,
        whid: selectedWorker!.hid,
        pname: selectedPlace!.pname,
      );
      workCostList.add(workCost);
      wPriceController.text = '';
      FocusScope.of(context).unfocus();
      update();
    }
  }

  Future<void> deleteMaterialList(int index) async {
    materialCostList.removeAt(index);
    update();
  }

  Future<void> deleteWorkList(int index) async {
    workCostList.removeAt(index);
    update();
  }

  Future<void> insertCostLists(context) async {
    bool isMaterialCostSuccess = false;
    bool isWorkCostSuccess = false;

    if (materialCostList.isNotEmpty) {
      isMaterialCostSuccess = await dbHelper.addMaterialCosts(materialCostList);
    }

    if (workCostList.isNotEmpty) {
      isWorkCostSuccess = await dbHelper.addWorkCosts(workCostList);
    }

    if (!isMaterialCostSuccess && !isWorkCostSuccess) {
      return;
    } else {
      Get.closeAllSnackbars();
      FetchData.fetchAllData();
      FocusScope.of(context).unfocus();
      String message = '';

      if (isMaterialCostSuccess && isWorkCostSuccess) {
        message = '인건비 및 자재비가 저장되었습니다.';
      } else if (isMaterialCostSuccess) {
        message = '자재비가 저장되었습니다.';
      } else {
        message = '인건비가 저장되었습니다.';
      }

      await Get.dialog(saveDialog(text: message));
      clearAllLists();
    }
  }

  void clearAllLists() {
    materialCostList = [];
    workCostList = [];
    update();
  }

  void showClearDialog() {
    Get.dialog(
      deleteDialog(
        content: '모두 비우시겠습니까?',
        onPressed: () {
          clearAllLists();
          Get.back();
        },
      ),
    );
  }
}
