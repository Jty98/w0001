import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/total_cost_card.dart';
import 'package:w0001/ui/widget/total_price_bar.dart';
import 'package:w0001/ui/widget/segment_widget.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';

class PlaceCostScreen extends ConsumerWidget {
  final PlaceInfoModel placeInfo;
  const PlaceCostScreen({super.key, required this.placeInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placeDetailProvider(placeInfo.pid!));
    final vm = ref.read(placeDetailProvider(placeInfo.pid!).notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(placeInfo.pname),
        centerTitle: true,
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                vm.exportAndSharePlaceInfoToExcel(placeInfo.pname),
            icon: Image.asset(
              'assets/images/excel_logo.png',
              height: 28,
              width: 28,
            ),
          ),
          IconButton(
            // visualDensity: VisualDensity.comfortable,
            onPressed: () async {
              // Always push absolute nested route to avoid "page not found"
              // when current location isn't exactly `/place/detail`.
              await context.push('/place/detail/revenue', extra: placeInfo);
              if (!context.mounted) return;
              vm.clearRevenuePickedOnLeaveRevenueScreen();
            },
            icon: Image.asset(
              'assets/images/add_money.png',
              height: 28,
              width: 28,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size(MediaQuery.of(context).size.width, 45),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
            child: Column(
              children: [
                Text(
                  formatDateTimeRangeToString(state.dateTimeRange),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 5),
                _selectDurationButtons(context, state, vm),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          TotalPriceBar(
            totalCostList: vm.rangeFilterList,
            categoryTapCallbacks: {
              for (final type in FilterType.values)
                type.category: (category) => vm.changeFilterType(type),
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '${state.selectedFilterType.category} ${getPrice(price: vm.selectedPrice)}',
              style: const TextStyle(fontSize: 17),
            ),
          ),
          Expanded(child: expenseList(context, state, vm)),
        ],
      ),
    );
  }

  Row _selectDurationButtons(
    BuildContext context,
    PlaceDetailState state,
    PlaceDetailViewModel vm,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 30,
          child: ToggleButtons(
            borderWidth: 1,
            borderColor: const Color.fromARGB(255, 177, 176, 176),
            selectedBorderColor: const Color.fromARGB(255, 177, 176, 176),
            textStyle: bold14Style,
            borderRadius: BorderRadius.circular(5),
            isSelected: state.toggleState,
            onPressed: (index) {
              vm.changeDateTimeRange(index, context);
            },
            children: [
              toggleWidget(
                width: (MediaQuery.of(context).size.width - 25) / 3,
                height: 24,
                child: const Text('기간 선택'),
                icon: Icon(
                  Icons.calendar_month,
                  color: state.selectedDayType == DayTpye.range
                      ? const Color.fromARGB(255, 5, 5, 5)
                      : const Color.fromARGB(255, 106, 116, 149),
                ),
              ),
              toggleWidget(
                height: 24,
                width: (MediaQuery.of(context).size.width - 25) / 3,
                child: const Text('전체 기간'),
              ),
              toggleWidget(
                height: 24,
                width: (MediaQuery.of(context).size.width - 25) / 3,
                child: const Text('이번 달'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget expenseList(context, PlaceDetailState state, PlaceDetailViewModel vm) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: vm.filteredTotalCostList.isEmpty
          ? const Center(child: Text('지출 내역이 없습니다.'))
          : GroupedListView(
              physics: const AlwaysScrollableScrollPhysics(),
              elements: vm.filteredTotalCostList,
              order: GroupedListOrder.DESC,
              groupBy: (element) => element.getDay,
              groupSeparatorBuilder: (value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              itemBuilder: (context, element) =>
                  paymentList(context, element, state, vm),
            ),
    );
  }

  Widget paymentList(
    context,
    TotalCostModel element,
    PlaceDetailState state,
    PlaceDetailViewModel vm,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Slidable(
      closeOnScroll: true,
      startActionPane: element.category == 'w'
          ? ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  autoClose: true,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: element.wcomplete == 1
                      ? (cs.primaryContainer)
                      : (Colors.green[600] ?? Colors.green),
                  icon: element.wcomplete == 1
                      ? Icons.autorenew_outlined
                      : Icons.check_circle,
                  label: element.wcomplete == 1 ? '미지급으로 변경' : '지급 완료',
                  onPressed: (slidableCtx) => vm
                      .updateWComplete(element.wcomplete, element.id)
                      .then((_) {
                        if (!slidableCtx.mounted) return;
                        showDialog<void>(
                          context: slidableCtx,
                          builder: (_) => saveDialog(
                            text:
                                '${element.wcomplete == 1 ? '미지급으로' : '완료로'} 변경되었습니다.',
                          ),
                        );
                      }),
                ),
              ],
            )
          : null,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            autoClose: true,
            borderRadius: BorderRadius.circular(10),
            backgroundColor: Colors.red,
            icon: Icons.delete,
            label: '삭제',
            onPressed: (slidableCtx) => showDialog<void>(
              context: slidableCtx,
              builder: (dialogCtx) => deleteDialog(
                onPressed: () => vm
                    .deleteCost(element.category, element.id)
                    .then((value) {
                  FetchData.fetchAllData();
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                }),
              ),
            ),
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          return InkWell(
            onTap: () {
              vm.dropDownCategoryChangeAction(element.category);
              vm.mNameController.text = element.name;
              vm.mPriceController.text =
                  getPrice(price: element.price, isContainWon: false);
              vm.setDialogDateTime(DateTime.parse(element.date));

              showDialog<void>(
                context: context,
                builder: (dialogCtx) =>
                    editCostDialog(element, dialogCtx, state, vm),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TotalCostCard(
              category: element.category,
              name: element.name,
              price: element.price,
              wcomplete: element.wcomplete,
              ),
            ),
          );
        },
      ),
    );
  }

  Dialog editCostDialog(
    TotalCostModel element,
    context,
    PlaceDetailState state,
    PlaceDetailViewModel vm,
  ) {
    return Dialog(
      child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color.fromARGB(255, 243, 243, 243),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 15),
                child: Text(
                  '수정',
                  style: bigStyle,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePickerDialog(
                        context: context,
                        minDate: DateTime(2000),
                        maxDate: DateTime(2099),
                      ) ?? state.dialogDateTime;
                  vm.setDialogDateTime(picked);
                },
                icon: const Icon(
                  Icons.date_range_outlined,
                  color: Color.fromARGB(255, 117, 154, 193),
                ),
                label: Text(
                  formatDateTimeWeekDayToString(state.dialogDateTime),
                  style: smalldateStyle,
                ),
              ),
              Visibility(
                visible: element.category == 'w' ? false : true,
                child: SizedBox(
                  height: 60,
                  width: 230,
                  child: DropdownSearch(
                      items: categoryList,
                      onChanged: (value) =>
                          vm.dropDownCategoryChangeAction(value!),
                      selectedItem: element.category,
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 3),
                child: AddTextField(
                  tController: vm.mNameController,
                  labelText: '항목',
                  isPrice: false,
                  height: 60,
                  keyboardType: TextInputType.text,
                  readOnly: element.category == 'w' ? true : false,
                  onChanged: (value) {},
                ),
              ),
              AddTextField(
                tController: vm.mPriceController,
                labelText: '금액',
                isPrice: true,
                height: 60,
                keyboardType: TextInputType.number,
                readOnly: false,
                onChanged: (value) {},
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  state.alertText,
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
                    onPressed: () => vm
                        .updateCost(
                          element.category,
                          element.id,
                          state.dialogDateTime.toString(),
                        )
                        .then((value) => FetchData.fetchAllData()),
                    child: const Text('수정'),
                  ),
                ],
              )
            ],
          ),
        ),
    );
  }
}
