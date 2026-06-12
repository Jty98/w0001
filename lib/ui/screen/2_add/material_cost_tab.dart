import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/material_name_presets.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/date_card_widget.dart';
import 'package:w0001/util/responsive_layout.dart';

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
    final fieldH = context.rs(52);
    final btnH = context.rs(44);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(12),
        context.rsi(10),
        context.rsi(12),
        0,
      ),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SelectDateButton(),
                SizedBox(height: context.rsi(10)),
                _categoryDropdownSearch(context, ref),
                SizedBox(height: context.rsi(5)),
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
                        height: fieldH,
                        witdh: double.infinity,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        readOnly: false,
                      ),
                    ),
                    SizedBox(width: context.rsi(8)),
                    Expanded(
                      flex: 4,
                      child: AddTextField(
                        tController: vm.mPriceController,
                        focusNode: vm.mPriceFocus,
                        labelText: '금액',
                        keyboardType: TextInputType.number,
                        onSubmitted: (value) => vm.addMaterialCostList(context),
                        isPrice: true,
                        height: fieldH,
                        witdh: double.infinity,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        readOnly: false,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rsi(6)),
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
                    bottom: keyboardInset > 0
                        ? keyboardInset + context.rsi(8)
                        : 0,
                  ),
                  child: SizedBox(
                    height: btnH,
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
                SizedBox(height: context.rsi(6)),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: state.materialCostList.length,
            itemBuilder: (context, index) =>
                tempCostBuilder(ref, context, index, 'material'),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.rsi(16))),
        ],
      ),
    );
  }

  Widget _categoryDropdownSearch(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: context.rs(52),
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
            labelStyle: tt.bodyMedium,
            hintStyle: tt.bodyMedium,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.rsi(12),
              vertical: context.rsi(12),
            ),
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
    if (category == null ||
        materialPresetExcludedCategories.contains(category)) {
      return const SizedBox.shrink();
    }
    final presets = materialNamePresetsByCategory[category];
    if (presets == null || presets.isEmpty) return const SizedBox.shrink();
    final items = ['직접입력', ...presets.take(10)];

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.rsi(10),
        context.rsi(8),
        context.rsi(10),
        context.rsi(10),
      ),
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
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: context.rsi(8)),
          Wrap(
            spacing: context.rsi(6),
            runSpacing: context.rsi(6),
            children: items
                .map(
                  (name) => ChoiceChip(
                    selected: selectedPreset == name,
                    label: Text(
                      name,
                      style: tt.labelSmall?.copyWith(
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
