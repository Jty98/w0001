import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/date_card_widget.dart';

class MaterialCostTab extends ConsumerWidget {
  const MaterialCostTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          const SelectDateButton(),
          const SizedBox(height: 10),
          categoryDropdownSearch(ref),
          const SizedBox(height: 5),
          AddTextField(
            tController: vm.mNameController,
            focusNode: vm.mNameFocus,
            onSubmitted: (value) => vm.mPriceFocus.requestFocus(),
            labelText: '자재 이름',
            keyboardType: TextInputType.text,
            isPrice: false,
            height: 52,
            witdh: double.infinity,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            readOnly: false,
          ),
          const SizedBox(height: 5),
          AddTextField(
            tController: vm.mPriceController,
            focusNode: vm.mPriceFocus,
            labelText: '금액',
            keyboardType: TextInputType.number,
            onSubmitted: (value) => vm.addMaterialCostList(context),
            isPrice: true,
            height: 52,
            witdh: double.infinity,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            readOnly: false,
          ),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: FilledButton.icon(
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
              icon: const Icon(Icons.add),
              label: const Text('자재 추가'),
            ),
          ),
          const SizedBox(height: 6),
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

  return SizedBox(
    height: 52,
    child: DropdownSearch<String>(
      items: categoryList,
      onChanged: (value) => vm.categoryChangeAction(value!),
      selectedItem: state.selectedCategory,
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelStyle: const TextStyle(fontSize: 14),
          hintStyle: const TextStyle(fontSize: 14),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          hintText: '카테고리 선택',
        ),
      ),
    ),
  );
}
