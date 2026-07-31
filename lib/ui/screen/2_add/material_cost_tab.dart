import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/material_name_history_providers.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/theme/app_theme_colors.dart';
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

  static const _directInputLabel = '직접입력';

  void _selectPreset(String name, AddCostViewModel vm) {
    setState(() => _selectedPreset = name);
    if (name == _directInputLabel) {
      vm.mNameController.clear();
      vm.mNameFocus.requestFocus();
      return;
    }
    vm.mNameController.text = name;
    vm.mNameController.selection = TextSelection.fromPosition(
      TextPosition(offset: vm.mNameController.text.length),
    );
    vm.mPriceFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final fieldH = context.rs(46);
    final btnH = context.rs(44);
    final gap = context.rsi(10);

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
                SizedBox(height: gap),
                _categoryDropdownSearch(context, ref),
                SizedBox(height: gap),
                SizedBox(
                  height: fieldH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: AddTextField(
                          tController: vm.mNameController,
                          focusNode: vm.mNameFocus,
                          onSubmitted: (value) => vm.mPriceFocus.requestFocus(),
                          labelText: '자재 이름',
                          keyboardType: TextInputType.text,
                          isPrice: false,
                          height: fieldH,
                          witdh: double.infinity,
                          compact: true,
                          omitBottomMargin: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          readOnly: false,
                        ),
                      ),
                      SizedBox(width: context.rsi(8)),
                      Expanded(
                        flex: 6,
                        child: AddTextField(
                          tController: vm.mPriceController,
                          focusNode: vm.mPriceFocus,
                          labelText: '금액',
                          keyboardType: TextInputType.number,
                          onSubmitted: (value) =>
                              vm.addMaterialCostList(context),
                          isPrice: true,
                          height: fieldH,
                          witdh: double.infinity,
                          compact: true,
                          omitBottomMargin: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          readOnly: false,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.rsi(8)),
                _MaterialRecentNameChips(
                  selectedCategory: state.selectedCategory,
                  selectedPreset: _selectedPreset,
                  onSelect: (name) => _selectPreset(name, vm),
                ),
                SizedBox(height: gap),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(
                    bottom:
                        keyboardInset > 0 ? keyboardInset + context.rsi(8) : 0,
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
                SizedBox(height: context.rsi(8)),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final itemStyle = tt.bodySmall?.copyWith(fontSize: 13);

    return SizedBox(
      height: context.rs(42),
      child: DropdownSearch<String>(
        items: categoryList,
        onChanged: (value) {
          if (value == null) return;
          vm.categoryChangeAction(value);
          setState(() => _selectedPreset = _directInputLabel);
        },
        selectedItem: state.selectedCategory,
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: '카테고리',
            labelStyle: tt.labelSmall,
            floatingLabelStyle: tt.labelSmall,
            hintStyle: itemStyle,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.rsi(10),
              vertical: context.rsi(8),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: false,
          menuProps: MenuProps(
            backgroundColor: cs.surface,
          ),
        ),
      ),
    );
  }
}

/// 카테고리별 최근 자재명 칩 — 담기 시 로컬 저장 (최대 10).
class _MaterialRecentNameChips extends ConsumerWidget {
  const _MaterialRecentNameChips({
    required this.selectedCategory,
    required this.selectedPreset,
    required this.onSelect,
  });

  final String? selectedCategory;
  final String selectedPreset;
  final void Function(String name) onSelect;

  static const _directInputLabel = '직접입력';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = selectedCategory;
    if (category == null ||
        materialPresetExcludedCategories.contains(category)) {
      return const SizedBox.shrink();
    }

    ref.watch(materialNameHistoryProvider);
    final recent = ref
        .read(materialNameHistoryProvider.notifier)
        .namesForCategory(category);
    final items = [_directInputLabel, ...recent];

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final chipLabel = tt.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.0,
      fontWeight: FontWeight.w600,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '최근',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: context.rsi(6)),
        Expanded(
          child: SizedBox(
            height: context.rs(30),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(width: context.rsi(5)),
              itemBuilder: (context, index) {
                final name = items[index];
                final isDirect = name == _directInputLabel;
                final selected = selectedPreset == name;

                return InputChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.symmetric(horizontal: context.rsi(4)),
                  label: Text(
                    name,
                    style: chipLabel?.copyWith(
                      color: selected ? cs.onSecondaryContainer : cs.onSurface,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: cs.secondaryContainer,
                  backgroundColor: cs.appMutedFill,
                  side: BorderSide(
                    color: selected
                        ? cs.secondary
                        : cs.outlineVariant.withValues(alpha: 0.55),
                  ),
                  onPressed: () => onSelect(name),
                  onDeleted: isDirect
                      ? null
                      : () async {
                          await ref
                              .read(materialNameHistoryProvider.notifier)
                              .remove(category, name);
                          if (selectedPreset == name) {
                            onSelect(_directInputLabel);
                          }
                        },
                  deleteIcon: isDirect
                      ? null
                      : Icon(
                          Icons.close_rounded,
                          size: context.rsi(14),
                          color: cs.onSurfaceVariant,
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
