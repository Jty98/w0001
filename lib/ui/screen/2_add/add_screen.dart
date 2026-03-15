import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:w0001/controller/add_cost_controller.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/ui/screen/2_add/material_cost_tab.dart';
import 'package:w0001/ui/screen/2_add/work_cost_tab.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/round_text_field.dart';

class AddScreen extends GetView<AddCostController> {
  const AddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          persistentFooterButtons: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: GetBuilder<AddCostController>(
                builder: (controller) => Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('인건비 ${controller.workCostList.length}건',
                            style: size15Style),
                        Text('자재비 ${controller.materialCostList.length}건',
                            style: size15Style),
                      ],
                    ),
                    IconButton(
                      onPressed: controller.isAllEmpty
                          ? null
                          : () => controller.showClearDialog(),
                      icon: Icon(
                        size: 18,
                        Icons.cancel,
                        color: controller.isAllEmpty ? Colors.grey[400] : Colors.red,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 35,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: controller.workCostList.isEmpty &&
                                controller.materialCostList.isEmpty
                            ? null
                            : () => controller.insertCostLists(context),
                        child: const Text(
                          '저장하기',
                          style: size15Style,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
          appBar: AppBar(
            title: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: GetBuilder<AddCostController>(
                builder: (controller) => placeDropdown(controller, context),
              ),
            ),
            toolbarHeight: 60,
            bottom: const TabBar(
              padding: EdgeInsets.symmetric(vertical: 5),
              labelPadding: EdgeInsets.symmetric(vertical: 5),
              tabs: [
                Text(
                  '인건비',
                  style: normalStyle,
                ),
                Text(
                  '자재비',
                  style: normalStyle,
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              workCostTab(context),
              materialCostTab(context),
            ],
          ),
        ),
      ),
    );
  }
}

Dialog addWorkerDialog(controller) {
  return Dialog(
    child: GetBuilder<AddCostController>(
      builder: (controller) => Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10), color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 15),
              child: Text(
                '사람 추가',
                style: bigStyle,
              ),
            ),
            RoundTextField(
              controller: controller.hNameController,
              onChanged: (value) {
                controller.alertText = '';
                controller.update();
              },
              labelText: '이름 (필수)',
            ),
            const SizedBox(
              height: 5,
            ),
            RoundTextField(
              controller: controller.hNumController,
              onChanged: (value) {
                controller.alertText = '';
                controller.update();
              },
              labelText: '주민등록번호(선택)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(
              height: 5,
            ),
            RoundTextField(
              controller: controller.hMemoController,
              onChanged: (value) {
                controller.alertText = '';
                controller.update();
              },
              labelText: '메모 (선택)',
              height: 150,
              maxLines: 3,
              maxLength: 50,
            ),
            Text(
              controller.alertText,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: Colors.red),
                    )),
                const SizedBox(
                  width: 20,
                ),
                TextButton(
                  onPressed: () => controller.insertWorker(),
                  child: const Text('확인'),
                ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget placeDropdown(AddCostController controller, BuildContext context) {
  return SizedBox(
    height: 54,
    child: DropdownSearch<PlaceModel>(
      asyncItems: (text) => DbHelper().getIncompletePlaces(),
      itemAsString: (item) => item.pname,
      popupProps: PopupProps.menu(
        emptyBuilder: (context, searchEntry) =>
            const Center(child: Text('진행중인 현장이 없습니다.')),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        textAlign: TextAlign.center,
        baseStyle: const TextStyle(
          fontSize: 18,
          color: Colors.black,
        ),
        dropdownSearchDecoration: InputDecoration(
          isDense: true,
          hintStyle: const TextStyle(color: Colors.red, fontSize: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          hintText: '현장을 선택해 주세요.',
        ),
      ),
      onChanged: (value) => controller.placeChangeAction(context, value!),
      selectedItem: controller.selectedPlace,
    ),
  );
}

Widget tempCostBuilder(
    AddCostController controller, int index, String costType) {
  List costList = costType == 'material'
      ? controller.materialCostList.reversed.toList()
      : controller.workCostList.reversed.toList();
  return Slidable(
    closeOnScroll: true,
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
              onPressed: () => costType == 'material'
                  ? controller
                      .deleteMaterialList(index)
                      .then((value) => Get.back())
                  : controller
                      .deleteWorkList(index)
                      .then((value) => Get.back()),
            ),
          ),
        ),
      ],
    ),
    child: Card(
      child: SizedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Text(
                formatDateTimeWeekDayToString(
                  DateTime.parse(
                    costType == 'material'
                        ? costList[index].mdate
                        : costList[index].wdate,
                  ),
                ),
                style: blueTitleStyle,
              ),
            ),
            const Divider(height: 0),
            ListTile(
              dense: true,
              title: costType == 'material'
                  ? Row(
                      children: [
                        Text(
                          '[${costList[index].mcategory}] ',
                          style: category2Style,
                        ),
                        Expanded(
                          child: Text(
                            costList[index].mname,
                            style: normalStyle,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      costList[index].hname!,
                      style: normalStyle,
                    ),
              subtitle: Text(
                costList[index].pname ?? '',
                style: categoryStyle,
              ),
              trailing: Text(
                getPrice(
                    price: costType == 'material'
                        ? costList[index].mprice
                        : costList[index].wprice),
                style: normalStyle,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
