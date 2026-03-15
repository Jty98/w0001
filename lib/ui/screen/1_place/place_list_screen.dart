import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:w0001/controller/add_cost_controller.dart';
import 'package:w0001/controller/place_controller.dart';
import 'package:w0001/controller/place_list_controller.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/ui/screen/1_place/place_screen.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';

class PlaceListScreen extends GetView<PlaceListController> {
  const PlaceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            // onDoubleTap: () => controller.importDB(),
            // onLongPress: () => controller.exportDB(),
            child: const Text('현장 관리'),
          ),
          actions: [
            _buildAppBarIconButton(),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSegmentButton(),
              Expanded(
                child: _buildListView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  GetBuilder<PlaceListController> _buildListView() {
    return GetBuilder<PlaceListController>(
      builder: (controller) => (controller.filteredPlaceList.isEmpty)
          ? Center(
              child: Text(
                '${controller.placeState == PlaceState.incomplete ? '진행중인' : '완료된'} 현장이 없습니다.',
                style: normalStyle,
              ),
            )
          : ListView.builder(
              itemCount: controller.filteredPlaceList.length,
              itemBuilder: (context, index) => _buildPlaceListTile(
                  element: controller.filteredPlaceList[index], index: index),
            ),
    );
  }

  Padding _buildSegmentButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: GetBuilder<PlaceListController>(
        builder: (controller) => CupertinoSlidingSegmentedControl<PlaceState>(
          groupValue: controller.placeState,
          children: const {
            PlaceState.incomplete: Text('진행중'),
            PlaceState.complete: Text('완료'),
          },
          onValueChanged: (value) => controller.stateValueChanged(value),
        ),
      ),
    );
  }

  IconButton _buildAppBarIconButton() {
    return IconButton(
      tooltip: '현장 추가',
      onPressed: () async => await Get.dialog(
        _placeDialog(
          isAdd: true,
          onPressed: () => controller.insertPlace(),
          nameController: controller.placeNameController,
          revenueController: controller.placeRevenueController,
        ),
      ).then((value) => controller.resetTextContoller()),
      icon: const Icon(Icons.add),
    );
  }

  Dialog _placeDialog(
      {VoidCallback? onPressed,
      required bool isAdd,
      TextEditingController? nameController,
      TextEditingController? revenueController}) {
    PlaceListController controller = Get.find<PlaceListController>();
    return Dialog(
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color.fromARGB(255, 243, 243, 243)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                isAdd ? '현장 추가' : '현장 수정',
                style: bigStyle,
              ),
            ),
            AddTextField(
              tController: nameController!,
              labelText: '현장 이름 (필수)',
              isPrice: false,
              readOnly: false,
              onChanged: (value) {
                controller.updateText = '';
                controller.update();
              },
            ),
            AddTextField(
              tController: revenueController!,
              labelText: '선수금',
              isPrice: true,
              keyboardType: TextInputType.number,
              readOnly: false,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GetBuilder<PlaceListController>(
                  builder: (controller) => Text(
                        controller.updateText,
                        style: const TextStyle(color: Colors.red),
                      )),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Get.back();
                    controller.updateText = '';
                    controller.placeRevenueController.text = '0';
                  },
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: onPressed,
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceListTile(
      {required PlaceInfoModel element, required int index}) {
    return Slidable(
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            borderRadius: BorderRadius.circular(10),
            backgroundColor: Colors.green,
            icon: controller.placeState == PlaceState.complete
                ? Icons.autorenew_outlined
                : Icons.check_circle,
            label: controller.placeState == PlaceState.complete
                ? '진행중으로 변경'
                : '완료',
            onPressed: (context) {
              controller.updatePcomplete(index).then((value) {
                FetchData.fetchAllData();
                Get.find<AddCostController>().selectedPlace = null;
              });
            },
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            borderRadius: BorderRadius.circular(10),
            label: '수정',
            icon: Icons.edit,
            backgroundColor: Colors.blue,
            onPressed: (context) {
              TextEditingController nameController =
                  TextEditingController(text: element.pname);
              TextEditingController revenueController = TextEditingController(
                  text: getPrice(
                      price: element.pfirstrevenue, isContainWon: false));
              Get.dialog(
                GetBuilder<PlaceListController>(
                  builder: (controller) => _placeDialog(
                    isAdd: false,
                    nameController: nameController,
                    revenueController: revenueController,
                    onPressed: () => controller
                        .updatePlace(
                            element.pid!,
                            nameController.text,
                            int.tryParse(
                                  revenueController.text
                                      .trim()
                                      .replaceAll(RegExp(r'[,원]'), ''),
                                ) ??
                                -1)
                        .then((value) {
                      FetchData.fetchAllData();
                      Get.find<AddCostController>().selectedPlace = null;
                    }),
                  ),
                ),
              ).then((value) => controller.updateText = '');
            },
          ),
          SlidableAction(
            borderRadius: BorderRadius.circular(10),
            backgroundColor: Colors.red,
            icon: Icons.delete,
            label: '삭제',
            onPressed: (context) => Get.dialog(
              deleteDialog(
                  onPressed: () =>
                      controller.deletePlace(element.pid!).then((value) {
                        FetchData.fetchAllData();
                        Get.find<AddCostController>().selectedPlace = null;
                        Get.back();
                      })),
            ),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Get.to(
          () => PlaceScreen(placeInfo: element),
          binding: BindingsBuilder(
            () {
              Get.put(PlaceController(pid: element.pid!));
            },
          ),
          fullscreenDialog: true,
        ),
        onLongPress: () => Get.dialog(
          pageViewDialog(
            title: element.pname,
            height: 500,
            text: formatDuration(element.pstart, element.pend),
            textStyle: const TextStyle(fontSize: 15),
            children: [
              _buildMainTable(element),
              _buildMaterialTable(element),
            ],
          ),
        ),
        child: Card(
          color: Colors.blueGrey.withOpacity(0.1),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Column(
              children: [
                Text(
                  element.pname,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
              ],
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    formatDuration(element.pstart, element.pend),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('총품수 : '),
                            Text(
                              '총 지출금액 : ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900]),
                            ),
                            const Text('인건비 : '),
                            const Text('미지급(세전) : '),
                            const Text('미지급(세후) : '),
                            const Text('자재비 : '),
                            // const Text('매출액 : '),
                            // const Text('순수익 : '),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${element.workerCount.toString()}품',
                                textAlign: TextAlign.right),
                            Text(
                                getPrice(
                                    price: element.mTotal + element.wTotal),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900])),
                            Text(getPrice(price: element.wTotal),
                                textAlign: TextAlign.right),
                            Text(getPrice(price: element.wIncomplete),
                                textAlign: TextAlign.right),
                            Text(
                                getPrice(
                                  price: element.wIncomplete,
                                  isTaxApply: true,
                                ),
                                textAlign: TextAlign.right),
                            Text(getPrice(price: element.mTotal),
                                textAlign: TextAlign.right),
                            // Text(getPrice(price: element.prevenue),
                            //     textAlign: TextAlign.right),
                            // Text(getPrice(price: element.prevenue - (element.mTotal + element.wTotal)),
                            //     textAlign: TextAlign.right),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainTable(PlaceInfoModel element) {
    List<TableRowModel> mainRows = [
      TableRowModel(label: ' 총 품수', value: '${element.workerCount}품'),
      TableRowModel(
          label: ' 총 수익',
          value: getPrice(
              price: element.pfirstrevenue + element.totalAdditionalRevenue)),
      TableRowModel(
          label: ' 총 지출금액',
          value: getPrice(price: element.mTotal + element.wTotal)),
      TableRowModel(
          label: ' 순 이익',
          value: getPrice(
              price:
                  element.pfirstrevenue - (element.mTotal + element.wTotal))),
      TableRowModel(label: '', value: ''),
      TableRowModel(label: ' 총 인건비', value: getPrice(price: element.wTotal)),
      TableRowModel(label: ' 총 자재비', value: getPrice(price: element.mTotal)),
      TableRowModel(
          label: ' 미지급 인건비', value: getPrice(price: element.wIncomplete)),
    ];

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              '현장 요약',
              style: TextStyle(fontSize: 15),
            ),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey),
          columnWidths: const {
            0: FixedColumnWidth(100.0),
            1: FixedColumnWidth(170.0),
          },
          children: mainRows.map(
            (row) {
              return TableRow(
                children: [
                  TableCell(
                    child: Text(
                      row.label,
                      style: TextStyle(
                          color: row.label.contains('미지급')
                              ? const Color.fromARGB(255, 236, 28, 13)
                              : Colors.black,
                          fontWeight: row.label.contains('합계')
                              ? FontWeight.bold
                              : null),
                    ),
                  ),
                  TableCell(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${row.value}  ',
                        textAlign: row.align,
                        style: TextStyle(
                            color: row.label.contains('미지급')
                                ? const Color.fromARGB(255, 236, 28, 13)
                                : Colors.black,
                            fontWeight: row.label.contains('합계')
                                ? FontWeight.bold
                                : null),
                      ),
                    ),
                  ),
                ],
              );
            },
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildMaterialTable(PlaceInfoModel element) {
    List<TableRowModel> materialRows = categoryList.map((category) {
      final valueGetter = categoryMapping[category];
      if (valueGetter != null) {
        final value = valueGetter(element);
        return TableRowModel(
          label: ' $category',
          value: getPrice(price: value),
        );
      } else {
        return TableRowModel(label: ' $category', value: '');
      }
    }).toList();

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              '자재비 상세',
              style: TextStyle(fontSize: 15),
            ),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey),
          columnWidths: const {
            0: FixedColumnWidth(100.0),
            1: FixedColumnWidth(170.0),
          },
          children: materialRows.map((row) {
            return TableRow(
              children: [
                TableCell(child: Text(' ${row.label}')),
                TableCell(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('${row.value}  ', textAlign: row.align),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class TableRowModel {
  final String label;
  final String value;
  final TextAlign align;

  TableRowModel({
    required this.label,
    required this.value,
    this.align = TextAlign.center,
  });
}
