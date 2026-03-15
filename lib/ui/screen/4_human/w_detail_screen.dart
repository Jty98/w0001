import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:w0001/controller/human_total_controller.dart';
import 'package:w0001/controller/worker_controller.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';



class WorkCostDetailScreen extends GetView<HumanTotalController> {
  final String hname;
  const WorkCostDetailScreen({super.key, required this.hname});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(hname),
            Text(
              formatDateTimeRangeToString(
                  Get.find<WorkerController>().dateTimeRange),
              style: smalldateStyle,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompleteSegmentControl(),
                _buildTaxSegmentControl(),
              ],
            ),
          ),
          _buildPlaceDropdownSearch(),
          _buildPriceTextBar(),
          _buildListView(),
        ],
      ),
    );
  }

  Padding _buildPlaceDropdownSearch() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownSearch<PlaceDropDownModel>(
        asyncItems: (text) =>
            DbHelper().getPlacesForWorkCost(controller.hid),
        itemAsString: (item) => item.pname,
        selectedItem: PlaceDropDownModel(pname: '전체 현장', pid: 0),
        dropdownDecoratorProps: const DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(hintText: '현장을 선택해주세요.'),
        ),
        onChanged: (value) => controller.fetchWorkCostByHid(value!.pid),
      ),
    );
  }

  Expanded _buildListView() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: GetBuilder<HumanTotalController>(
          builder: (controller) {
            if (controller.filteredWorkCostList.isEmpty) {
              return const Center(child: Text('조회된 인건비가 없습니다.'));
            }
            return ListView.separated(
              separatorBuilder: (context, index) => const Divider(),
              itemCount: controller.filteredWorkCostList.length,
              itemBuilder: (context, index) => workCostCard(controller, index),
            );
          },
        ),
      ),
    );
  }

  Container _buildPriceTextBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 243, 242, 246),
      ),
      child: GetBuilder<HumanTotalController>(
        builder: (controller) => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              controller.isTaxApply ? '세 후 :  ' : '세 전 :  ',
              style: controller.isTaxApply ? afterTaxStyle : beforeTaxStyle,
            ),
            Text(
              getPrice(
                  price: controller.totalPrice,
                  isTaxApply: controller.isTaxApply),
              style: normalStyle,
            ),
          ],
        ),
      ),
    );
  }

  GetBuilder<HumanTotalController> _buildTaxSegmentControl() {
    return GetBuilder<HumanTotalController>(
      builder: (controller) => CupertinoSlidingSegmentedControl<TaxState>(
        thumbColor: controller.isTaxApply
            ? const Color.fromARGB(255, 248, 213, 210)
            : const Color.fromARGB(255, 171, 202, 251),
        groupValue: controller.taxState,
        children: const {
          TaxState.taxOff: Text('세전'),
          TaxState.taxOn: Text('세후'),
        },
        onValueChanged: (value) => controller.taxStateValueChanged(value),
      ),
    );
  }

  Widget _buildCompleteSegmentControl() {
    return GetBuilder<HumanTotalController>(
      builder: (controller) => CupertinoSlidingSegmentedControl<CompleteState>(
        groupValue: controller.completeState,
        children: const {
          CompleteState.whole: Text('전체', style: smallStyle),
          CompleteState.incomplete: Text('미지급', style: smallStyle),
        },
        onValueChanged: (value) {
          controller.completeStateValueChanged(value);
          Get.find<HumanTotalController>().update();
        },
      ),
    );
  }

  Widget workCostCard(HumanTotalController controller, int index) {
    WorkCost2Model element = controller.filteredWorkCostList[index];
    return ListTile(
      title: Text(
        element.pname,
        style: normalStyle,
      ),
      subtitle: Text(
        formatDateTimeToStringBySlash(
          DateTime.parse(element.wdate),
        ),
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: Text(
        getPrice(price: element.wprice, isTaxApply: controller.isTaxApply),
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: element.wcomplete == 0 ? Colors.red : null
          ),
      ),
    );
  }
}
