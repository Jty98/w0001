import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/ui/screen/2_add/material_cost_tab.dart';
import 'package:w0001/ui/screen/2_add/work_cost_tab.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/round_text_field.dart';

class AddScreen extends ConsumerWidget {
  const AddScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);

    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          persistentFooterButtons: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('인건비 ${state.workCostList.length}건',
                          style: size15Style),
                      Text('자재비 ${state.materialCostList.length}건',
                          style: size15Style),
                    ],
                  ),
                  IconButton(
                    onPressed: state.isAllEmpty
                        ? null
                        : () => vm.showClearDialog(context),
                    icon: Icon(
                      size: 18,
                      Icons.cancel,
                      color: state.isAllEmpty ? Colors.grey[400] : Colors.red,
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
                      onPressed: state.workCostList.isEmpty &&
                              state.materialCostList.isEmpty
                          ? null
                          : () => vm.insertCostLists(context),
                      child: const Text(
                        '저장하기',
                        style: size15Style,
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
          appBar: AppBar(
            title: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: placeDropdown(ref, vm, state, context),
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
              const WorkCostTab(),
              const MaterialCostTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class AddWorkerDialog extends ConsumerWidget {
  const AddWorkerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(addCostProvider.notifier);
    final alertText = ref.watch(addCostProvider).alertText;

    return Dialog(
      child: Container(
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
              controller: vm.hNameController,
              onChanged: (value) => vm.clearWorkerDialogAlert(),
              labelText: '이름 (필수)',
            ),
            const SizedBox(
              height: 5,
            ),
            RoundTextField(
              controller: vm.hNumController,
              onChanged: (value) => vm.clearWorkerDialogAlert(),
              labelText: '주민등록번호(선택)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(
              height: 5,
            ),
            RoundTextField(
              controller: vm.hMemoController,
              onChanged: (value) => vm.clearWorkerDialogAlert(),
              labelText: '메모 (선택)',
              height: 150,
              maxLines: 3,
              maxLength: 50,
            ),
            Text(
              alertText,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: Colors.red),
                    )),
                const SizedBox(
                  width: 20,
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await vm.insertWorker();
                    if (ok && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
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
    );
  }
}

Widget placeDropdown(
  WidgetRef ref,
  AddCostViewModel vm,
  AddCostState state,
  BuildContext context,
) {
  return SizedBox(
    height: 54,
    child: DropdownSearch<PlaceModel>(
      asyncItems: (text) =>
          ref.read(placeUseCaseProvider).getIncompletePlaces(),
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
      onChanged: (value) => vm.placeChangeAction(context, value!),
      selectedItem: state.selectedPlace,
    ),
  );
}

Widget tempCostBuilder(
  WidgetRef ref,
  BuildContext context,
  int index,
  String costType,
) {
  final state = ref.watch(addCostProvider);
  final vm = ref.read(addCostProvider.notifier);

  late final String dateStr;
  late final Widget title;
  late final String pname;
  late final int price;

  if (costType == 'material') {
    final item = state.materialCostList.reversed.toList()[index];
    dateStr = item.mdate;
    title = Row(
      children: [
        Text(
          '[${item.mcategory}] ',
          style: category2Style,
        ),
        Expanded(
          child: Text(
            item.mname,
            style: normalStyle,
          ),
        ),
      ],
    );
    pname = item.pname ?? '';
    price = item.mprice;
  } else {
    final item = state.workCostList.reversed.toList()[index];
    dateStr = item.wdate;
    title = Text(
      item.hname!,
      style: normalStyle,
    );
    pname = item.pname ?? '';
    price = item.wprice;
  }

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
          onPressed: (slidableCtx) => showDialog<void>(
            context: slidableCtx,
            builder: (dialogCtx) => deleteDialog(
              onPressed: () {
                if (costType == 'material') {
                  vm.deleteMaterialList(index);
                } else {
                  vm.deleteWorkList(index);
                }
                Navigator.of(dialogCtx).pop();
              },
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
                formatDateTimeWeekDayToString(DateTime.parse(dateStr)),
                style: blueTitleStyle,
              ),
            ),
            const Divider(height: 0),
            ListTile(
              dense: true,
              title: title,
              subtitle: Text(
                pname,
                style: categoryStyle,
              ),
              trailing: Text(
                getPrice(price: price),
                style: normalStyle,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
