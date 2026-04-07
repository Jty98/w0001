import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';

class PlaceListScreen extends ConsumerWidget {
  const PlaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placeListProvider);
    final viewModel = ref.read(placeListProvider.notifier);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('현장 관리'),
          actions: [
            _buildAppBarIconButton(context, ref, viewModel, state),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSegmentButton(state, viewModel),
              Expanded(
                child: _buildListView(context, ref, state, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    WidgetRef ref,
    PlaceListState state,
    PlaceListViewModel viewModel,
  ) {
    if (state.filteredPlaceList.isEmpty) {
      final label =
          state.placeState == PlaceState.incomplete ? '진행중인' : '완료된';
      return Center(
        child: Text(
          '$label 현장이 없습니다.',
          style: normalStyle,
        ),
      );
    }

    return ListView.builder(
      itemCount: state.filteredPlaceList.length,
      itemBuilder: (ctx, index) => _buildPlaceListTile(
        context: ctx,
        ref: ref,
        element: state.filteredPlaceList[index],
        index: index,
        viewModel: viewModel,
      ),
    );
  }

  Padding _buildSegmentButton(
    PlaceListState state,
    PlaceListViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: CupertinoSlidingSegmentedControl<PlaceState>(
        groupValue: state.placeState,
        children: const {
          PlaceState.incomplete: Text('진행중'),
          PlaceState.complete: Text('완료'),
        },
        onValueChanged: viewModel.stateValueChanged,
      ),
    );
  }

  Widget _buildAppBarIconButton(
    BuildContext context,
    WidgetRef ref,
    PlaceListViewModel viewModel,
    PlaceListState state,
  ) {
    return IconButton(
      tooltip: '현장 추가',
      onPressed: () async {
        await showDialog<void>(
          context: context,
          builder: (dialogCtx) => _placeDialog(
            isAdd: true,
            onPressed: () async {
              await viewModel.insertPlace();
              final cur = ref.read(placeListProvider);
              if (cur.updateText.isEmpty) {
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                viewModel.resetTextController();
              }
            },
            nameController: viewModel.placeNameController,
            revenueController: viewModel.placeRevenueController,
            state: state,
          ),
        );
        viewModel.resetTextController();
      },
      icon: const Icon(Icons.add),
    );
  }

  Dialog _placeDialog({
    VoidCallback? onPressed,
    required bool isAdd,
    required TextEditingController nameController,
    required TextEditingController revenueController,
    required PlaceListState state,
  }) {
    return Dialog(
      child: Builder(
        builder: (context) {
          final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
          final calendarHeight = MediaQuery.sizeOf(context).height * 0.38;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color.fromARGB(255, 243, 243, 243),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        isAdd ? '현장 추가' : '현장 수정',
                        style: bigStyle,
                      ),
                    ),
                    AddTextField(
                      tController: nameController,
                      labelText: '현장 이름 (필수)',
                      isPrice: false,
                      readOnly: false,
                    ),
                    AddTextField(
                      tController: revenueController,
                      labelText: '선수금',
                      isPrice: true,
                      keyboardType: TextInputType.number,
                      readOnly: false,
                    ),
                    ScrollableCalendarWidget(height: calendarHeight),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        state.updateText,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceListTile({
    required BuildContext context,
    required WidgetRef ref,
    required PlaceInfoModel element,
    required int index,
    required PlaceListViewModel viewModel,
  }) {
    return Slidable(
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            borderRadius: BorderRadius.circular(10),
            backgroundColor: Colors.green,
            icon: element.pcomplete == 1
                ? Icons.autorenew_outlined
                : Icons.check_circle,
            label: element.pcomplete == 1 ? '진행중으로 변경' : '완료',
            onPressed: (context) {
              viewModel.updatePcomplete(index).then((value) {
                FetchData.fetchAllData();
                ref.read(addCostProvider.notifier).clearSelectedPlace();
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
              showDialog<void>(
                context: context,
                builder: (dialogCtx) => _placeDialog(
                  isAdd: false,
                  nameController: nameController,
                  revenueController: revenueController,
                  state: const PlaceListState(
                    placeList: [],
                    filteredPlaceList: [],
                    placeState: PlaceState.incomplete,
                    updateText: '',
                    isLoading: false,
                  ),
                  onPressed: () {
                    final prevenue = int.tryParse(
                          revenueController.text
                              .trim()
                              .replaceAll(RegExp(r'[,원]'), ''),
                        ) ??
                        -1;
                    viewModel
                        .updatePlace(
                          element.pid!,
                          nameController.text,
                          prevenue,
                        )
                        .then((_) {
                      FetchData.fetchAllData();
                      ref.read(addCostProvider.notifier).clearSelectedPlace();
                    });
                  },
                ),
              ).then((value) => viewModel.clearUpdateText());
            },
          ),
          SlidableAction(
            borderRadius: BorderRadius.circular(10),
            backgroundColor: Colors.red,
            icon: Icons.delete,
            label: '삭제',
            onPressed: (slidableCtx) => showDialog<void>(
              context: slidableCtx,
              builder: (dialogCtx) => deleteDialog(
                onPressed: () => viewModel
                    .deletePlace(element.pid!)
                    .then((value) {
                  FetchData.fetchAllData();
                  ref.read(addCostProvider.notifier).clearSelectedPlace();
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                }),
              ),
            ),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/place/detail', extra: element),
        onLongPress: () => showDialog<void>(
          context: context,
          builder: (_) => pageViewDialog(
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
          color: Colors.blueGrey.withValues(alpha: 0.1),
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
