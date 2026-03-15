import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:w0001/presentation/controller/human_total_controller.dart';
import 'package:w0001/presentation/controller/worker_controller.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/ui/screen/4_human/human_screen.dart';
import 'package:w0001/ui/screen/4_human/w_detail_screen.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/segment_widget.dart';

class WorkCostScreen extends GetView<WorkerController> {
  const WorkCostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        persistentFooterButtons: [
          workCostFooter(),
        ],
        appBar: AppBar(
          title: const Text('인건비 조회'),
          actions: [
            TextButton(
              onPressed: () => controller.exportAndSendWorkCostToExcel(context),
              child: Image.asset(
                'assets/images/excel_logo.png',
                height: 28,
                width: 28,
              ),
            ),
            IconButton(
              tooltip: '사람 관리',
              onPressed: () {
                Get.to(() => const HumanScreen())?.then(
                  (value) {
                    controller.fetchWorkCost();
                    controller.refreshAction();
                  },
                );
              },
              icon: const Icon(
                Icons.person_search,
                color: Colors.black,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size(MediaQuery.of(context).size.width, 2),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: GetBuilder<WorkerController>(
                builder: (controller) => Text(
                  formatDateTimeRangeToString(controller.dateTimeRange),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey),
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _buildToggleButtons(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCompleteSegmentControl(),
                  _buildTaxSegmentControl(),
                ],
              ),
            ),
            Expanded(
              child: _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  Padding workCostFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GetBuilder<WorkerController>(
        builder: (controller) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('인건비 총금액 :', style: TextStyle(fontSize: 15)),
                const Text('미지급 총금액 :', style: TextStyle(fontSize: 15)),
                Visibility(
                  visible: controller.selectedCount != 0,
                  child: const Text('선택된 금액 :', style: TextStyle(fontSize: 15)),
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  getPrice(
                    price: controller.totalCost,
                    isTaxApply: controller.isTaxApply,
                  ),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  getPrice(
                    price: controller.totalIncompleteCost,
                    isTaxApply: controller.isTaxApply,
                  ),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700]),
                ),
                Visibility(
                  visible: controller.selectedCount != 0,
                  child: Text(
                    getPrice(
                      price: controller.selectedIncompleteCost,
                      isTaxApply: controller.isTaxApply,
                    ),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800]),
                  ),
                ),
              ],
            ),
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
                onPressed: controller.selectedCount == 0
                    ? null
                    : () => controller.updateWorkCostsToComplete(),
                child: const Text(
                  '지급하기',
                  style: size15Style,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  GetBuilder<WorkerController> _buildCompleteSegmentControl() {
    return GetBuilder<WorkerController>(
      builder: (controller) => CupertinoSlidingSegmentedControl<CompleteState>(
        groupValue: controller.completeState,
        children: const {
          CompleteState.whole: Text('전체', style: smallStyle),
          CompleteState.incomplete: Text('미지급', style: smallStyle),
        },
        onValueChanged: (value) => controller.completeStateValueChanged(value),
      ),
    );
  }

  Widget _buildListView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GetBuilder<WorkerController>(
        builder: (controller) => controller.getUniqueHuman().isEmpty
            ? const Center(child: Text('조회된 인건비가 없습니다.'))
            : ListView.builder(
                itemCount: controller.getUniqueHuman().length,
                itemBuilder: (context, index) {
                  final workCostData = controller
                      .processWorkCostData(controller.getUniqueHuman()[index]);
                  return Slidable(
                    closeOnScroll: true,
                    // startActionPane: ActionPane(
                    //   motion: const DrawerMotion(),
                    //   children: [
                    //     SlidableAction(
                    //       borderRadius: BorderRadius.circular(10),
                    //       backgroundColor: Colors.green,
                    //       icon: Icons.payment,
                    //       label: '모두 지급',
                    //       onPressed: (context) =>
                    //           controller.updateWorkCostsToComplete(
                    //               workCostData.filteredList),
                    //     ),
                    //   ],
                    // ),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      children: [
                        SlidableAction(
                          borderRadius: BorderRadius.circular(10),
                          backgroundColor: Colors.blue,
                          icon: Icons.search,
                          label: '상세보기',
                          onPressed: (context) => Get.to(
                              () => WorkCostDetailScreen(
                                  hname: workCostData.hname),
                              binding: BindingsBuilder(() {
                            Get.put(
                              HumanTotalController(hid: workCostData.hid),
                            );
                          })),
                        ),
                      ],
                    ),
                    child: Builder(builder: (context) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        controller.registerSlidable(context);
                      });
                      return WorkerExpansionTile(
                        isIncomplete: controller.isIncomplete,
                        workCostData: workCostData,
                        controller: controller,
                        child: _buildGroupListView(
                            workCostData.filteredList, controller),
                      );
                    }),
                  );
                },
              ),
      ),
    );
  }

  GroupedListView<TotalWorkCostModel, String> _buildGroupListView(
      List<TotalWorkCostModel> filteredList, WorkerController controller) {
    return GroupedListView(
      order: GroupedListOrder.DESC,
      padding: const EdgeInsets.only(top: 5),
      shrinkWrap: true,
      elements: filteredList,
      groupBy: (element) => element.date,
      groupSeparatorBuilder: (value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 55, vertical: 2),
        child: Text(
          value,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
      ),
      itemBuilder: (context, element) => _buildListTile(element, controller),
    );
  }

  Widget _buildListTile(
      TotalWorkCostModel element, WorkerController controller) {
    return Slidable(
      startActionPane: controller.isIncomplete
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  // onPressed: null,
                  autoClose: true,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor:
                      element.wcomplete == 1 ? Colors.blue : Colors.green,
                  icon: element.wcomplete == 1
                      ? Icons.autorenew_outlined
                      : Icons.check_circle,
                  label: element.wcomplete == 1 ? '미지급으로 변경' : '지급 완료',
                  onPressed: (context) => controller
                      .updateWComplete(element.wcomplete, element.wid)
                      .then(
                        (value) => Get.dialog(
                          saveDialog(
                              text:
                                  '${element.wcomplete == 1 ? '미지급으로' : '완료로'} 변경되었습니다.'),
                        ),
                      ),
                ),
              ],
            ),
      child: Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.registerSlidable(context);
        });
        return Row(
          children: [
            GetBuilder<WorkerController>(
              builder: (controller) {
                controller.initializeCheckboxState(
                    element.wid, element.price, element.hid);
                return Checkbox(
                  side: BorderSide(
                    color: element.wcomplete == 1
                        ? Colors.grey[400]!
                        : Colors.blue[700]!,
                    width: 2,
                  ),
                  value: controller.checkboxStates[element.wid]?.isSelected ??
                      false,
                  onChanged: element.wcomplete == 1
                      ? null
                      : (value) {
                          controller.toggleCheckboxState(element.wid);
                        },
                );
              },
            ),
            Expanded(
              child: Card(
                color: Colors.blueGrey.withOpacity(0.1),
                elevation: 0,
                child: ListTile(
                  dense: true,
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: element.pname,
                          style: const TextStyle(fontSize: 15),
                        ),
                        TextSpan(
                          text: element.pcomplete == 1 ? ' [완]' : '',
                          style: const TextStyle(
                              color: Colors.black45, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  trailing: Text(
                    getPrice(
                        price: element.price,
                        isTaxApply: controller.isTaxApply),
                    style: TextStyle(
                        fontSize: 14,
                        color: element.wcomplete == 0
                            ? Colors.red[700]
                            : Colors.black),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  GetBuilder<WorkerController> _buildTaxSegmentControl() {
    return GetBuilder<WorkerController>(
      builder: (controller) => CupertinoSlidingSegmentedControl<TaxState>(
        groupValue: controller.taxState,
        thumbColor: controller.isTaxApply
            ? const Color.fromARGB(255, 248, 213, 210)
            : const Color.fromARGB(255, 171, 202, 251),
        children: const {
          TaxState.taxOff: Text(
            '세전',
            style: smallStyle,
          ),
          TaxState.taxOn: Text(
            '세후',
            style: smallStyle,
          ),
        },
        onValueChanged: (value) => controller.taxStateValueChanged(value),
      ),
    );
  }

  SizedBox _buildToggleButtons(BuildContext context) {
    return SizedBox(
      height: 30,
      child: GetBuilder<WorkerController>(
        builder: (controller) => ToggleButtons(
          borderColor: const Color.fromARGB(255, 177, 176, 176),
          selectedBorderColor: const Color.fromARGB(255, 177, 176, 176),
          borderWidth: 1,
          // selectedColor: Colors.black,
          borderRadius: BorderRadius.circular(5),
          textStyle: bold14Style,
          isSelected: controller.toggleState,
          onPressed: (index) {
            controller.selectToggleButton(index, context).then((value) {
              controller.closeAllSliders();
              controller.collapseAllExpansionTiles();
            });
          },
          children: [
            toggleWidget(
              // width: 100,
              width: (MediaQuery.of(context).size.width - 28) / 3,
              child: const Text('기간 선택'),
              icon: Icon(
                Icons.calendar_month,
                color: controller.dayState == DayTpye.range
                    ? const Color.fromARGB(255, 5, 5, 5)
                    : const Color.fromARGB(255, 106, 116, 149),
              ),
            ),
            toggleWidget(
              // width: 50,
              width: (MediaQuery.of(context).size.width - 28) / 3,
              child: const Text('전체 기간'),
            ),
            toggleWidget(
              // width: 50,
              width: (MediaQuery.of(context).size.width - 28) / 3,
              child: const Text('이번 달'),
            ),
          ],
        ),
      ),
    );
  }

  Padding buildDateTimeRangeText() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GetBuilder<WorkerController>(
        builder: (controller) => Text(
          formatDateTimeRangeToString(controller.dateTimeRange),
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey),
        ),
      ),
    );
  }

  Container _buildSearchBar() {
    return Container(
      height: 45,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SearchBar(
        leading: const Icon(
          Icons.search,
          size: 30,
        ),
        trailing: [
          IconButton(
            onPressed: () => controller.resetSearchText(),
            icon: const Icon(Icons.close),
          ),
        ],
        hintText: '검색할 사람의 이름을 입력하세요.',
        controller: controller.searchWorkerTextContoller,
        onChanged: (value) => controller.searchWoker(value),
      ),
    );
  }
}

// expansionTile의 Icon rotate를 위해 Stateful 사용
class WorkerExpansionTile extends StatefulWidget {
  final WorkCostData workCostData;
  final WorkerController controller;
  final Widget child;
  final bool isIncomplete;

  const WorkerExpansionTile({
    super.key,
    required this.workCostData,
    required this.controller,
    required this.child,
    required this.isIncomplete,
  });

  @override
  State<WorkerExpansionTile> createState() => _WorkerExpansionTileState();
}

class _WorkerExpansionTileState extends State<WorkerExpansionTile> {
  bool _isExpanded = false;
  ExpansionTileController expansionTileController = ExpansionTileController();
  @override
  void initState() {
    super.initState();
    widget.controller.registerExpantionTile(
        widget.workCostData.hid, expansionTileController);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.withOpacity(0.1),
      child: ExpansionTile(
        controller: expansionTileController,
        onExpansionChanged: (value) {
          setState(() {
            _isExpanded = value;
          });
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        shape: const Border(),
        title: Text(
          widget.workCostData.hname,
          style: bigStyle,
        ),
        subtitle: Text(widget.workCostData.hnumber),
        dense: true,
        leading: IconButton(
          onPressed: () => widget.controller
              .updateHstar(
                  hid: widget.workCostData.hid,
                  hstar: widget.workCostData.hstar)
              .then((value) {
            widget.controller.fetchWorkerInfo();
          }),
          icon: (widget.workCostData.hstar == 0)
              ? const Icon(
                  Icons.star_border,
                  color: Colors.grey,
                )
              : const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 전체 금액
                Text(
                  '${getPrice(
                    price: widget.workCostData.totalPrice,
                    isTaxApply: widget.controller.isTaxApply,
                  )} ',
                  style: bold14Style,
                ),
                Visibility(
                  visible: widget.controller
                          .incompleteCostByHid(widget.workCostData.hid) !=
                      0,
                  child: Text(
                    '${getPrice(
                      price: widget.controller
                          .incompleteCostByHid(widget.workCostData.hid),
                      isTaxApply: widget.controller.isTaxApply,
                    )} ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more_rounded),
            ),
          ],
        ),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
