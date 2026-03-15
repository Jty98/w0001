import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:w0001/presentation/controller/add_cost_controller.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/date_card_widget.dart';

Widget workCostTab(context) {
  AddCostController controller = Get.find<AddCostController>();
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Center(
      child: Column(
        children: [
          const SelectDateButton(),
          Row(
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 250) / 2,
              ),
              humanDropdownSearch(),
              IconButton(
                tooltip: '사람 추가',
                onPressed: () => Get.dialog(
                  addWorkerDialog(controller),
                ).then((value) => controller.clearDialogText()),
                icon: Icon(
                  Icons.person_add_alt_1,
                  color: Colors.blue[700],
                  size: 25,
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 250) / 2,
              ),
              AddTextField(
                tController: controller.wPriceController,
                focusNode: controller.wPriceFocus,
                labelText: '금액',
                keyboardType: TextInputType.number,
                isPrice: true,
                onSubmitted: (value) => controller.addWorkCostList(context),
                readOnly: false,
              ),
            ],
          ),
          SizedBox(
            height: 35,
            child: TextButton(
              onPressed: (controller.selectedPlace == null) ||
                      (controller.selectedWorker == null)
                  ? () => Get.snackbar('알림', '현장이나 사람을 선택해 주세요.', snackPosition: SnackPosition.BOTTOM)
                  : () => controller.addWorkCostList(context),
              child: const Text(
                '추가',
              ),
            ),
          ),
          Expanded(
            child: GetBuilder<AddCostController>(
              builder: (controller) => ListView.builder(
                  itemCount: controller.workCostList.length,
                  itemBuilder: (context, index) {
                    return tempCostBuilder(controller, index, 'work');
                  }),
            ),
          ),
        ],
      ),
    ),
  );
}

Container humanDropdownSearch() {
  return Container(
    width: 230,
    height: 48,
    margin: const EdgeInsets.only(bottom: 7),
    child: GetBuilder<AddCostController>(
      builder: (controller) => DropdownSearch<HumanModel>(
        asyncItems: (text) => DbHelper().getAllWorkers(),
        itemAsString: (item) => item.hname,
        onChanged: (value) => controller.workerChangeAction(value!),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelStyle: const TextStyle(fontSize: 14),
            hintStyle: const TextStyle(fontSize: 14),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: '사람 선택',
          ),
        ),
        selectedItem: controller.selectedWorker,
        popupProps: PopupProps.menu(
          // itemBuilder: (context, item, isSelected) => Center(
          //   child: ListTile(
          //     titleTextStyle: const TextStyle(
          //         fontWeight: FontWeight.bold,
          //         color: Colors.black,
          //         fontSize: 15),
          //     subtitleTextStyle:
          //         const TextStyle(color: Colors.black54, fontSize: 13),
          //     title: Text(item.hname),
          //     subtitle: Text(item.hnumber),
          //   ),
          // ),
          emptyBuilder: (context, searchEntry) => const Center(
            child: Text('검색 결과 없음'),
          ),
          showSearchBox: true,
          showSelectedItems: false,
          searchFieldProps: TextFieldProps(
            controller: TextEditingController(),
            decoration: const InputDecoration(
              constraints: BoxConstraints(maxHeight: 40),
              hintText: '사람을 검색하세요.',
              isDense: true,
              hintStyle: TextStyle(fontSize: 13),
              labelStyle: TextStyle(fontSize: 13),
              border: OutlineInputBorder(gapPadding: 100),
            ),
          ),
          searchDelay: Duration.zero,
        ),
      ),
    ),
  );
}
