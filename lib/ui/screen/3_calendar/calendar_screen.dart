import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:w0001/presentation/controller/calendar_controller.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/calendar/my_calendar.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/total_cost_card.dart';
import 'package:w0001/ui/widget/total_price_bar.dart';

class CalendarScreen extends GetView<CalendarController> {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const CalendarWidget(),
          _buildTotalPriceBar(),
          _buildSelectedCategoryText(),
          Expanded(
            child: _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCategoryText() {
    return GetBuilder<CalendarController>(
      builder: (controller) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          '${controller.selectedFilterType.category} ${getPrice(price: controller.getFilteredListPrice)}',
          style: normalStyle,
        ),
      ),
    );
  }

  Widget _buildListView() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GetBuilder<CalendarController>(
        builder: (controller) => controller.placeCount == 0
            ? const Center(child: Text('조회된 데이터가 없습니다.'))
            : ListView.builder(
                itemCount: controller.placeCount,
                itemBuilder: (context, index) {
                  final placeInfo =
                      controller.getUniquePlaceNameAndComplete()[index];
                  final pname = placeInfo['pname'];
                  final pcomplete = placeInfo['pcomplete'];
                  return Card(
                    color: Colors.blueGrey.withOpacity(0.1),
                    elevation: 0,
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      shape: const Border(),
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      leading: Icon(
                        pcomplete == 0 ? null : Icons.check_box_rounded,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      title: Text(
                        pname,
                        style: normalStyle,
                      ),
                      expandedAlignment: Alignment.centerLeft,
                      children: [
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 10),
                          child: Column(
                            children: [
                              for (var element in controller
                                  .filteredTotalCostList
                                  .where((element) => element.pname == pname)
                                  .toList())
                                Slidable(
                                  closeOnScroll: true,
                                  startActionPane: element.category == 'w'
                                      ? ActionPane(
                                          motion: const DrawerMotion(),
                                          children: [
                                            SlidableAction(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              backgroundColor:
                                                  element.wcomplete == 1
                                                      ? Colors.blue
                                                      : Colors.green,
                                              icon: element.wcomplete == 1
                                                  ? Icons.autorenew_outlined
                                                  : Icons.check_circle,
                                              label: element.wcomplete == 1
                                                  ? '미지급으로 변경'
                                                  : '지급 완료',
                                              onPressed: (context) => controller
                                                  .updateWComplete(
                                                      element.wcomplete,
                                                      element.id)
                                                  .then(
                                                    (value) => Get.dialog(
                                                      saveDialog(
                                                          text:
                                                              '${element.wcomplete == 1 ? '미지급으로' : '완료로'} 변경되었습니다.'),
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        )
                                      : null,
                                  endActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    children: [
                                      SlidableAction(
                                        borderRadius: BorderRadius.circular(10),
                                        backgroundColor: Colors.red,
                                        icon: Icons.delete,
                                        label: '삭제',
                                        onPressed: (context) => Get.dialog(
                                          deleteDialog(
                                            onPressed: () => controller
                                                .deleteCost(element.category,
                                                    element.id)
                                                .then((value) => Get.back()),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: editableCard(
                                      controller, element, context),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  GetBuilder<CalendarController> _buildTotalPriceBar() {
    return GetBuilder<CalendarController>(
        builder: (controller) => TotalPriceBar(
              totalCostList: controller.totalCostList,
              categoryTapCallbacks: controller.categoryTapCallbacks,
            ));
  }

  InkWell editableCard(CalendarController controller, TotalCostModel element,
      BuildContext context) {
    return InkWell(
      onTap: () {
        controller.mNameController.text = element.name;
        controller.dropDownSelectedCategory = element.category;
        controller.mPriceController.text =
            getPrice(price: element.price, isContainWon: false);
        controller.dialogDateTime = DateTime.parse(element.date);
        Get.dialog(
          Dialog(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color.fromARGB(255, 243, 243, 243),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 15),
                    child: Text(
                      '수정',
                      style: bigStyle,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      controller.dialogDateTime = await showDatePickerDialog(
                            context: context,
                            minDate: DateTime(2000),
                            maxDate: DateTime(2099),
                          ) ??
                          controller.dialogDateTime;
                      controller.update();
                    },
                    icon: const Icon(
                      Icons.date_range_outlined,
                      color: Color.fromARGB(255, 117, 154, 193),
                    ),
                    label: GetBuilder<CalendarController>(
                      builder: (controller) => Text(
                        formatDateTimeWeekDayToString(
                            controller.dialogDateTime),
                        style: smalldateStyle,
                      ),
                    ),
                  ),
                  Visibility(
                    visible: element.category == 'w' ? false : true,
                    child: SizedBox(
                      height: 60,
                      width: 230,
                      child: GetBuilder<CalendarController>(
                        builder: (controller) => DropdownSearch(
                          items: categoryList,
                          onChanged: (value) =>
                              controller.categoryChangeAction(value!),
                          selectedItem: element.category,
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 3),
                    child: AddTextField(
                      tController: controller.mNameController,
                      labelText: '항목',
                      isPrice: false,
                      height: 60,
                      keyboardType: TextInputType.text,
                      readOnly: element.category == 'w' ? true : false,
                      onChanged: (value) {
                        controller.alertText = '';
                        controller.update();
                      },
                    ),
                  ),
                  AddTextField(
                    tController: controller.mPriceController,
                    labelText: '금액',
                    isPrice: true,
                    height: 60,
                    keyboardType: TextInputType.number,
                    readOnly: false,
                    onChanged: (value) {
                      controller.alertText = '';
                      controller.update();
                    },
                  ),
                  GetBuilder<CalendarController>(
                    builder: (controller) => Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        controller.alertText,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          controller.alertText = '';
                          Get.back();
                        },
                        child: const Text(
                          '취소',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: () => controller
                            .updateCost(element.category, element.id,
                                controller.dialogDateTime.toString())
                            .then((value) {
                          FetchData.fetchAllData();
                        }),
                        child: const Text('수정'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
      child: TotalCostCard(
        category: element.category,
        name: element.name,
        price: element.price,
        wcomplete: element.wcomplete,
      ),
    );
  }
}
