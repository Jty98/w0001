import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/ui/widget/total_price_bar.dart';

class CalendarController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    selectedDay = DateTime.now();
    focusedDay =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    fetchAllEvents();
    _initCategoryTapCallbacks();
    fetchTotalCost();
  }

  DbHelper dbHelper = DbHelper();
  CalendarFormat calendarFormat = CalendarFormat.month;
  late DateTime selectedDay;
  List<TotalCostModel> totalCostList = [];
  List<TotalCostModel> get filteredTotalCostList {
    switch (selectedFilterType) {
      case FilterType.all:
        return totalCostList;
      case FilterType.work:
        return totalCostList
            .where((element) => element.category == 'w')
            .toList()
          ;
      case FilterType.material:
        return totalCostList
            .where((element) => element.category != 'w')
            .toList();
      case FilterType.notPay:
        return totalCostList
            .where((element) => element.wcomplete == 0)
            .toList();
      default:
        return totalCostList
            .where((element) => element.category == selectedFilterType.category)
            .toList();
    }
  }
  late DateTime focusedDay;
  String? dropDownSelectedCategory;
  FilterType selectedFilterType = FilterType.all;
  String alertText = '';
  Map<String, CategoryTapCallback> categoryTapCallbacks = {};
  DateTime dialogDateTime = DateTime.now();
  TextEditingController mNameController = TextEditingController();
  TextEditingController mPriceController = TextEditingController();

  Future<void> fetchAllEvents() async {
    events = await dbHelper.getAllEvents();
    update();
  }

  Map<DateTime, List<String>> events = {
    DateTime.utc(2024, 05, 13): ['현장1'],
    DateTime.utc(2024, 05, 14): ['현장1', '현장2'],
    DateTime.utc(2024, 05, 15): ['현장1'],
  };


  int get getFilteredListPrice {
    int price = 0;
    for(var element in filteredTotalCostList){
      price += element.price;
    }
    return price;
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
    update();
  }

  Future<void> onDaySelected(selectedDay, focusedDay) async {
    this.selectedDay = selectedDay;
    this.focusedDay = selectedDay;
    await fetchTotalCost();
  }

  List<String> getEventsForDay(DateTime day) {
    DateTime selectedDay = DateTime(day.year, day.month, day.day);
    return events[selectedDay] ?? [];
  }

  void changeFormat(format) {
    calendarFormat = format;
    update();
  }

  Future<void> fetchTotalCost() async {
    totalCostList = await dbHelper.getTotalCostsByDate(focusedDay);
    update();
  }

  Future<void> deleteCost(String category, int id) async {
    if (category == 'w') {
      await dbHelper.deleteWorkCost(id);
    } else {
      await dbHelper.deleteMaterialCost(id);
    }
    await fetchTotalCost();
    FetchData.fetchAllData();
    
  }

  get placeCount =>
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

    // pname 기준으로 정렬
    uniquePlaceNameAndComplete.sort((a, b) => a['pname'].compareTo(b['pname']));

    return uniquePlaceNameAndComplete;
  }


  // 비용 수정
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
            mcategory: dropDownSelectedCategory!,
            mprice: price);
        await dbHelper.updateMaterialCostItem(materialCost);
        fetchTotalCost();
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
      await fetchTotalCost();
      FetchData.fetchAllData();
      Get.back();
    }
  }

  Future<void> updateWComplete(int wcomplete, int id) async {
    await dbHelper.toggleWorkCostCompletionStatus(wcomplete, id);
    fetchTotalCost();
    FetchData.fetchAllData();
  }

  categoryChangeAction(String value) {
    dropDownSelectedCategory = value;
  }
}
