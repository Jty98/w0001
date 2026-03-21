import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/date_card_widget.dart';

class WorkCostTab extends ConsumerWidget {
  const WorkCostTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);

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
                humanDropdownSearch(ref),
                IconButton(
                  tooltip: '사람 추가',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AddWorkerDialog(),
                  ).then((_) => vm.clearDialogText()),
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
                  tController: vm.wPriceController,
                  focusNode: vm.wPriceFocus,
                  labelText: '금액',
                  keyboardType: TextInputType.number,
                  isPrice: true,
                  onSubmitted: (value) => vm.addWorkCostList(context),
                  readOnly: false,
                ),
              ],
            ),
            SizedBox(
              height: 35,
              child: TextButton(
                onPressed: (state.selectedPlace == null) ||
                        (state.selectedWorker == null)
                    ? () {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('현장이나 사람을 선택해 주세요.'),
                          ),
                        );
                      }
                    : () => vm.addWorkCostList(context),
                child: const Text(
                  '추가',
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: state.workCostList.length,
                itemBuilder: (context, index) {
                  return tempCostBuilder(ref, context, index, 'work');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget humanDropdownSearch(WidgetRef ref) {
  final state = ref.watch(addCostProvider);
  final vm = ref.read(addCostProvider.notifier);

  return Container(
    width: 230,
    height: 48,
    margin: const EdgeInsets.only(bottom: 7),
    child: DropdownSearch<HumanModel>(
      asyncItems: (text) => ref.read(humanUseCaseProvider).getAllWorkers(),
      itemAsString: (item) => item.hname,
      onChanged: (value) => vm.workerChangeAction(value!),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelStyle: const TextStyle(fontSize: 14),
          hintStyle: const TextStyle(fontSize: 14),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          hintText: '사람 선택',
        ),
      ),
      selectedItem: state.selectedWorker,
      popupProps: PopupProps.menu(
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
  );
}
