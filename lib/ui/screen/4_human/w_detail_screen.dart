import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/human_work_detail_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';

class WorkCostDetailScreen extends ConsumerWidget {
  const WorkCostDetailScreen({
    super.key,
    required this.hid,
    required this.hname,
  });

  final int hid;
  final String hname;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workerState = ref.watch(workerProvider);
    final detailState = ref.watch(humanWorkDetailProvider(hid));
    final detailVm = ref.read(humanWorkDetailProvider(hid).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(hname),
            Text(
              formatDateTimeRangeToString(workerState.dateTimeRange),
              style: smalldateStyle,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompleteSegmentControl(ref, detailVm, detailState),
                _buildTaxSegmentControl(ref, detailVm, detailState),
              ],
            ),
          ),
          _buildPlaceDropdownSearch(ref, detailVm),
          _buildPriceTextBar(detailState),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: detailState.filteredWorkCostList.isEmpty
                  ? const Center(child: Text('조회된 인건비가 없습니다.'))
                  : ListView.separated(
                      separatorBuilder: (context, index) => const Divider(),
                      itemCount: detailState.filteredWorkCostList.length,
                      itemBuilder: (context, index) => workCostCard(
                        detailState,
                        index,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceDropdownSearch(WidgetRef ref, HumanWorkDetailViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownSearch<PlaceDropDownModel>(
        asyncItems: (text) =>
            ref.read(workCostUseCaseProvider).getPlacesForWorkCost(hid),
        itemAsString: (item) => item.pname,
        selectedItem: PlaceDropDownModel(pname: '전체 현장', pid: 0),
        dropdownDecoratorProps: const DropDownDecoratorProps(
          dropdownSearchDecoration:
              InputDecoration(hintText: '현장을 선택해주세요.'),
        ),
        onChanged: (value) => vm.fetchWorkCostByHid(value!.pid),
      ),
    );
  }

  Widget _buildPriceTextBar(HumanWorkDetailState state) {
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 243, 242, 246),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            state.isTaxApply ? '세 후 :  ' : '세 전 :  ',
            style: state.isTaxApply ? afterTaxStyle : beforeTaxStyle,
          ),
          Text(
            getPrice(
                price: state.totalPrice, isTaxApply: state.isTaxApply),
            style: normalStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSegmentControl(
    WidgetRef ref,
    HumanWorkDetailViewModel vm,
    HumanWorkDetailState state,
  ) {
    return CupertinoSlidingSegmentedControl<TaxState>(
      thumbColor: state.isTaxApply
          ? const Color.fromARGB(255, 248, 213, 210)
          : const Color.fromARGB(255, 171, 202, 251),
      groupValue: state.taxState,
      children: const {
        TaxState.taxOff: Text('세전'),
        TaxState.taxOn: Text('세후'),
      },
      onValueChanged: vm.taxStateValueChanged,
    );
  }

  Widget _buildCompleteSegmentControl(
    WidgetRef ref,
    HumanWorkDetailViewModel vm,
    HumanWorkDetailState state,
  ) {
    return CupertinoSlidingSegmentedControl<CompleteState>(
      groupValue: state.completeState,
      children: const {
        CompleteState.whole: Text('전체', style: smallStyle),
        CompleteState.incomplete: Text('미지급', style: smallStyle),
      },
      onValueChanged: vm.completeStateValueChanged,
    );
  }

  Widget workCostCard(HumanWorkDetailState state, int index) {
    final element = state.filteredWorkCostList[index];
    return ListTile(
      title: Text(
        element.pname,
        style: normalStyle,
      ),
      subtitle: Text(
        formatDateTimeToStringBySlash(
          DateTime.parse(element.wdate),
        ),
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: Text(
        getPrice(price: element.wprice, isTaxApply: state.isTaxApply),
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: element.wcomplete == 0 ? Colors.red : null),
      ),
    );
  }
}
