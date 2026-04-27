import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/material_name_presets.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/date_card_widget.dart';

class MaterialCostTab extends ConsumerStatefulWidget {
  const MaterialCostTab({super.key});

  @override
  ConsumerState<MaterialCostTab> createState() => _MaterialCostTabState();
}

class _MaterialCostTabState extends ConsumerState<MaterialCostTab> {
  String _selectedPreset = '직접입력';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SelectDateButton(),
                const SizedBox(height: 10),
                _categoryDropdownSearch(ref),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: AddTextField(
                        tController: vm.mNameController,
                        focusNode: vm.mNameFocus,
                        onSubmitted: (value) => vm.mPriceFocus.requestFocus(),
                        labelText: '자재 이름',
                        keyboardType: TextInputType.text,
                        isPrice: false,
                        height: 52,
                        witdh: double.infinity,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        readOnly: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: AddTextField(
                        tController: vm.mPriceController,
                        focusNode: vm.mPriceFocus,
                        labelText: '금액',
                        keyboardType: TextInputType.number,
                        onSubmitted: (value) => vm.addMaterialCostList(context),
                        isPrice: true,
                        height: 52,
                        witdh: double.infinity,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        readOnly: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _MaterialNamePresetButtons(
                  selectedCategory: state.selectedCategory,
                  selectedPreset: _selectedPreset,
                  onSelect: (name) {
                    setState(() => _selectedPreset = name);
                    if (name == '직접입력') {
                      vm.mNameController.clear();
                      vm.mNameFocus.requestFocus();
                      return;
                    }
                    vm.mNameController.text = name;
                    vm.mNameController.selection = TextSelection.fromPosition(
                      TextPosition(offset: vm.mNameController.text.length),
                    );
                    vm.mPriceFocus.requestFocus();
                  },
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(
                    bottom: keyboardInset > 0 ? keyboardInset + 8 : 0,
                  ),
                  child: SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                      label: const Text('담기'),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: state.materialCostList.length,
            itemBuilder: (context, index) =>
                tempCostBuilder(ref, context, index, 'material'),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _categoryDropdownSearch(WidgetRef ref) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);

    return SizedBox(
      height: 52,
      child: DropdownSearch<String>(
        items: categoryList,
        onChanged: (value) {
          if (value == null) return;
          vm.categoryChangeAction(value);
          setState(() => _selectedPreset = '직접입력');
        },
        selectedItem: state.selectedCategory,
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelStyle: const TextStyle(fontSize: 14),
            hintStyle: const TextStyle(fontSize: 14),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            hintText: '카테고리 선택',
          ),
        ),
      ),
    );
  }
}

class _MaterialNamePresetButtons extends StatelessWidget {
  const _MaterialNamePresetButtons({
    required this.selectedCategory,
    required this.selectedPreset,
    required this.onSelect,
  });

  final String? selectedCategory;
  final String selectedPreset;
  final void Function(String name) onSelect;

  @override
  Widget build(BuildContext context) {
    final category = selectedCategory;
    if (category == null || materialPresetExcludedCategories.contains(category)) {
      return const SizedBox.shrink();
    }
    final presets = materialNamePresetsByCategory[category];
    if (presets == null || presets.isEmpty) return const SizedBox.shrink();
    final items = ['직접입력', ...presets.take(10)];

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$category 대표 자재',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (name) => ChoiceChip(
                    selected: selectedPreset == name,
                    label: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selectedPreset == name
                            ? cs.onPrimaryContainer
                            : cs.onSurface,
                      ),
                    ),
                    selectedColor: cs.primaryContainer,
                    side: BorderSide(
                      color: selectedPreset == name
                          ? cs.primary
                          : cs.outlineVariant.withValues(alpha: 0.7),
                    ),
                    onSelected: (_) => onSelect(name),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
