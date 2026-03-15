import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:w0001/controller/add_cost_controller.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/date_card_widget.dart';

Widget materialCostTab(context) {
  AddCostController controller = Get.find<AddCostController>();
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Column(
      children: [
        const SelectDateButton(),
        categoryDropdownSearch(),
        AddTextField(
          tController: controller.mNameController,
          focusNode: controller.mNameFocus,
          onSubmitted: (value) => controller.mPriceFocus.requestFocus(),
          labelText: '자재 이름',
          keyboardType: TextInputType.text,
          isPrice: false,
          readOnly: false,
        ),
        AddTextField(
          tController: controller.mPriceController,
          focusNode: controller.mPriceFocus,
          labelText: '금액',
          keyboardType: TextInputType.number,
          onSubmitted: (value) => controller.addMaterialCostList(context),
          isPrice: true,
          readOnly: false,
        ),
        SizedBox(
          height: 35,
          child: GetBuilder<AddCostController>(
            builder: (controller) => TextButton(
              onPressed: (controller.selectedPlace == null) ||
                      (controller.selectedCategory == null)
                  ? () => Get.snackbar('알림', '현장이나 카테고리를 선택해 주세요.', snackPosition: SnackPosition.BOTTOM)
                  : () => controller.addMaterialCostList(context),
              child: const Text(
                '추가',
                style: normalStyle,
              ),
            ),
          ),
        ),
        Expanded(
          child: GetBuilder<AddCostController>(
            builder: (controller) => ListView.builder(
              reverse: false,
              itemCount: controller.materialCostList.length,
              itemBuilder: (context, index) =>
                  tempCostBuilder(controller, index, 'material'),
            ),
          ),
        ),
        // GetBuilder<AddCostController>(
        //   builder: (controller) => Visibility(
        //     visible: controller.materialCostList.isNotEmpty,
        //     child: TextButton(
        //       onPressed: () => controller.insertMaterialCostList(context),
        //       child: const Text(
        //         '저장하기',
        //         style: bigStyle,
        //       ),
        //     ),
        //   ),
        // ),
        // const SizedBox(
        //   height: 10,
        // ),
      ],
    ),
  );
}

Container categoryDropdownSearch() {
  return Container(
    width: 230,
    height: 48,
    margin: const EdgeInsets.only(bottom: 7),
    child: GetBuilder<AddCostController>(
      builder: (controller) => DropdownSearch<String>(
        items: categoryList,
        onChanged: (value) => controller.categoryChangeAction(value!),
        selectedItem: controller.selectedCategory,
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelStyle: const TextStyle(fontSize: 14),
            hintStyle: const TextStyle(fontSize: 14),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            hintText: '카테고리',
          ),
        ),
      ),
    ),
  );
}
