import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/segment_widget.dart';

class WorkCostScreen extends ConsumerWidget {
  const WorkCostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        persistentFooterButtons: [
          _workCostFooter(context, ref),
        ],
        appBar: AppBar(
          title: const Text('인건비 조회'),
          actions: [
            TextButton(
              onPressed: () => vm.exportAndSendWorkCostToExcel(context),
              child: Image.asset(
                'assets/images/excel_logo.png',
                height: 28,
                width: 28,
              ),
            ),
            IconButton(
              tooltip: '사람 관리',
              onPressed: () {
                context.push('/work/human').then((_) async {
                  if (!context.mounted) return;
                  await vm.fetchWorkCost();
                  vm.refreshAction();
                });
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
              child: Text(
                formatDateTimeRangeToString(
                    ref.watch(workerProvider).dateTimeRange),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(ref, vm),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _buildToggleButtons(context, ref, vm),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCompleteSegmentControl(ref, vm),
                  _buildTaxSegmentControl(ref, vm),
                ],
              ),
            ),
            Expanded(
              child: _buildListView(context, ref, vm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workCostFooter(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('인건비 총금액 :', style: TextStyle(fontSize: 15)),
              const Text('미지급 총금액 :', style: TextStyle(fontSize: 15)),
              Visibility(
                visible: state.selectedCount != 0,
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
                  price: vm.totalCost,
                  isTaxApply: state.isTaxApply,
                ),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                getPrice(
                  price: vm.totalIncompleteCost,
                  isTaxApply: state.isTaxApply,
                ),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700]),
              ),
              Visibility(
                visible: state.selectedCount != 0,
                child: Text(
                  getPrice(
                    price: vm.selectedIncompleteCost,
                    isTaxApply: state.isTaxApply,
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
              onPressed: state.selectedCount == 0
                  ? null
                  : () => vm.updateWorkCostsToComplete(context),
              child: const Text(
                '지급하기',
                style: size15Style,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteSegmentControl(WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
    return CupertinoSlidingSegmentedControl<CompleteState>(
      groupValue: state.completeState,
      children: const {
        CompleteState.whole: Text('전체', style: smallStyle),
        CompleteState.incomplete: Text('미지급', style: smallStyle),
      },
      onValueChanged: vm.completeStateValueChanged,
    );
  }

  Widget _buildListView(
      BuildContext context, WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: vm.getUniqueHuman().isEmpty
          ? const Center(child: Text('조회된 인건비가 없습니다.'))
          : ListView.builder(
              itemCount: vm.getUniqueHuman().length,
              itemBuilder: (context, index) {
                final workCostData =
                    vm.processWorkCostData(vm.getUniqueHuman()[index]);
                return Slidable(
                  closeOnScroll: true,
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        borderRadius: BorderRadius.circular(10),
                        backgroundColor: Colors.blue,
                        icon: Icons.search,
                        label: '상세보기',
                        onPressed: (_) {
                          context.push(
                            '/work/detail/${workCostData.hid}'
                            '?name=${Uri.encodeComponent(workCostData.hname)}',
                          );
                        },
                      ),
                    ],
                  ),
                  child: Builder(builder: (ctx) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      vm.registerSlidable(ctx);
                    });
                    return WorkerExpansionTile(
                      ref: ref,
                      isIncomplete: state.isIncomplete,
                      workCostData: workCostData,
                      vm: vm,
                      child: _buildGroupListView(
                          workCostData.filteredList, ref, vm),
                    );
                  }),
                );
              },
            ),
    );
  }

  GroupedListView<TotalWorkCostModel, String> _buildGroupListView(
    List<TotalWorkCostModel> filteredList,
    WidgetRef ref,
    WorkerViewModel vm,
  ) {
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
      itemBuilder: (context, element) =>
          _buildListTile(context, ref, element, vm),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    WidgetRef ref,
    TotalWorkCostModel element,
    WorkerViewModel vm,
  ) {
    final state = ref.watch(workerProvider);
    return Slidable(
      startActionPane: state.isIncomplete
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  autoClose: true,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor:
                      element.wcomplete == 1 ? Colors.blue : Colors.green,
                  icon: element.wcomplete == 1
                      ? Icons.autorenew_outlined
                      : Icons.check_circle,
                  label: element.wcomplete == 1 ? '미지급으로 변경' : '지급 완료',
                  onPressed: (slidableCtx) async {
                    await vm.updateWComplete(element.wcomplete, element.wid);
                    if (!slidableCtx.mounted) return;
                    await showDialog<void>(
                      context: slidableCtx,
                      builder: (_) => saveDialog(
                        text:
                            '${element.wcomplete == 1 ? '미지급으로' : '완료로'} 변경되었습니다.',
                      ),
                    );
                  },
                ),
              ],
            ),
      child: Builder(builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          vm.registerSlidable(ctx);
        });
        return Row(
          children: [
            Consumer(
              builder: (context, ref, _) {
                final st = ref.watch(workerProvider);
                return Checkbox(
                  side: BorderSide(
                    color: element.wcomplete == 1
                        ? Colors.grey[400]!
                        : Colors.blue[700]!,
                    width: 2,
                  ),
                  value: st.checkboxStates[element.wid]?.isSelected ?? false,
                  onChanged: element.wcomplete == 1
                      ? null
                      : (value) {
                          ref
                              .read(workerProvider.notifier)
                              .toggleCheckboxState(element.wid);
                        },
                );
              },
            ),
            Expanded(
              child: Card(
                color: Colors.blueGrey.withValues(alpha: 0.1),
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
                        isTaxApply: state.isTaxApply),
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

  Widget _buildTaxSegmentControl(WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
    return CupertinoSlidingSegmentedControl<TaxState>(
      groupValue: state.taxState,
      thumbColor: state.isTaxApply
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
      onValueChanged: vm.taxStateValueChanged,
    );
  }

  Widget _buildToggleButtons(
      BuildContext context, WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
    return SizedBox(
      height: 30,
      child: ToggleButtons(
        borderColor: const Color.fromARGB(255, 177, 176, 176),
        selectedBorderColor: const Color.fromARGB(255, 177, 176, 176),
        borderWidth: 1,
        borderRadius: BorderRadius.circular(5),
        textStyle: bold14Style,
        isSelected: state.toggleState,
        onPressed: (index) {
          vm.selectToggleButton(index, context).then((_) {
            vm.closeAllSliders();
            vm.collapseAllExpansionTiles();
          });
        },
        children: [
          toggleWidget(
            width: (MediaQuery.of(context).size.width - 28) / 3,
            child: const Text('기간 선택'),
            icon: Icon(
              Icons.calendar_month,
              color: state.dayState == DayTpye.range
                  ? const Color.fromARGB(255, 5, 5, 5)
                  : const Color.fromARGB(255, 106, 116, 149),
            ),
          ),
          toggleWidget(
            width: (MediaQuery.of(context).size.width - 28) / 3,
            child: const Text('전체 기간'),
          ),
          toggleWidget(
            width: (MediaQuery.of(context).size.width - 28) / 3,
            child: const Text('이번 달'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(WidgetRef ref, WorkerViewModel vm) {
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
            onPressed: () => vm.resetSearchText(),
            icon: const Icon(Icons.close),
          ),
        ],
        hintText: '검색할 사람의 이름을 입력하세요.',
        controller: vm.searchWorkerTextContoller,
        onChanged: vm.searchWoker,
      ),
    );
  }
}

class WorkerExpansionTile extends StatefulWidget {
  const WorkerExpansionTile({
    super.key,
    required this.ref,
    required this.workCostData,
    required this.vm,
    required this.child,
    required this.isIncomplete,
  });

  final WidgetRef ref;
  final WorkCostData workCostData;
  final WorkerViewModel vm;
  final Widget child;
  final bool isIncomplete;

  @override
  State<WorkerExpansionTile> createState() => _WorkerExpansionTileState();
}

class _WorkerExpansionTileState extends State<WorkerExpansionTile> {
  bool _isExpanded = false;
  final ExpansionTileController expansionTileController =
      ExpansionTileController();

  @override
  void initState() {
    super.initState();
    widget.vm.registerExpantionTile(
        widget.workCostData.hid, expansionTileController);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.ref.watch(workerProvider);

    return Card(
      color: Colors.blueGrey.withValues(alpha: 0.1),
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
          onPressed: () => widget.vm
              .updateHstar(
                  hid: widget.workCostData.hid,
                  hstar: widget.workCostData.hstar)
              .then((_) {
            widget.vm.fetchWorkerInfo();
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
                Text(
                  '${getPrice(
                    price: widget.workCostData.totalPrice,
                    isTaxApply: state.isTaxApply,
                  )} ',
                  style: bold14Style,
                ),
                Visibility(
                  visible: widget.vm
                          .incompleteCostByHid(widget.workCostData.hid) !=
                      0,
                  child: Text(
                    '${getPrice(
                      price: widget.vm
                          .incompleteCostByHid(widget.workCostData.hid),
                      isTaxApply: state.isTaxApply,
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
