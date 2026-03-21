import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/date_card_widget.dart';

class MaterialCostTab extends ConsumerWidget {
  const MaterialCostTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          const SelectDateButton(),
          categoryDropdownSearch(ref),
          AddTextField(
            tController: vm.mNameController,
            focusNode: vm.mNameFocus,
            onSubmitted: (value) => vm.mPriceFocus.requestFocus(),
            labelText: '자재 이름',
            keyboardType: TextInputType.text,
            isPrice: false,
            readOnly: false,
          ),
          AddTextField(
            tController: vm.mPriceController,
            focusNode: vm.mPriceFocus,
            labelText: '금액',
            keyboardType: TextInputType.number,
            onSubmitted: (value) => vm.addMaterialCostList(context),
            isPrice: true,
            readOnly: false,
          ),
          SizedBox(
            height: 35,
            child: TextButton(
              onPressed: (state.selectedPlace == null) ||
                      (state.selectedCategory == null)
                  ? () {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('현장이나 카테고리를 선택해 주세요.'),
                        ),
                      );
                    }
                  : () => vm.addMaterialCostList(context),
              child: const Text(
                '추가',
                style: normalStyle,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: state.materialCostList.length,
              itemBuilder: (context, index) =>
                  tempCostBuilder(ref, context, index, 'material'),
            ),
          ),
        ],
      ),
    );
  }
}

Widget categoryDropdownSearch(WidgetRef ref) {
  final state = ref.watch(addCostProvider);
  final vm = ref.read(addCostProvider.notifier);

  return Container(
    width: 230,
    height: 48,
    margin: const EdgeInsets.only(bottom: 7),
    child: DropdownSearch<String>(
      items: categoryList,
      onChanged: (value) => vm.categoryChangeAction(value!),
      selectedItem: state.selectedCategory,
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
  );
}
