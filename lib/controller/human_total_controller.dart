import 'package:get/get.dart';
import 'package:w0001/controller/worker_controller.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/workcost_model.dart';

class HumanTotalController extends GetxController {
  final int hid;
  HumanTotalController({required this.hid});

  DbHelper dbHelper = DbHelper();
  List<WorkCost2Model> workCostList = [];
  List<WorkCost2Model> get incompleteWorkCostList =>
      workCostList.where((element) => element.wcomplete == 0).toList();
  List<WorkCost2Model> get filteredWorkCostList =>
      (isIncomplete) ? incompleteWorkCostList : workCostList;
  TotalSegment totalSegment = TotalSegment.place;
  TaxState taxState = TaxState.taxOn;
  bool get isTaxApply => taxState == TaxState.taxOn;
  CompleteState completeState = CompleteState.whole;
  bool get isIncomplete => completeState == CompleteState.incomplete;

  @override
  void onInit() {
    super.onInit();
    fetchWorkCostByHid(0); // hid: 0 => 전체 현장 조회
  }

  Future<void> fetchWorkCostByHid(int pid) async {
    workCostList = await dbHelper.getWorkCostsByPlaceAndDate(
        hid, Get.find<WorkerController>().dateTimeRange, pid);
    update();
  }

  void taxStateValueChanged(value) {
    if (value != null) {
      taxState = value;
    }
    update();
  }

  void completeStateValueChanged(value) {
    if (value != null) {
      completeState = value;
    }
    update();
  }

  int get totalPrice {
    int sum = 0;
    for (var workCost in filteredWorkCostList) {
      sum += workCost.wprice;
    }
    return sum;
  }
}
