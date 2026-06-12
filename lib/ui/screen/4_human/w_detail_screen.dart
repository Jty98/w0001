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
import 'package:w0001/util/responsive_layout.dart';

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
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(hname),
            Text(
              formatDateTimeRangeToString(
                workerState.dateTimeRange,
                periodType: workerState.dayState,
              ),
              style: tt.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(10),
              context.rsi(10),
              context.rsi(10),
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompleteSegmentControl(
                    context, ref, detailVm, detailState),
                _buildTaxSegmentControl(context, ref, detailVm, detailState),
              ],
            ),
          ),
          _buildPlaceDropdownSearch(context, ref, detailVm),
          _buildPriceTextBar(context, detailState),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(10)),
              child: detailState.filteredWorkCostList.isEmpty
                  ? const Center(child: Text('조회된 인건비가 없습니다.'))
                  : ListView.separated(
                      separatorBuilder: (context, index) => const Divider(),
                      itemCount: detailState.filteredWorkCostList.length,
                      itemBuilder: (context, index) => workCostCard(
                        context,
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

  Widget _buildPlaceDropdownSearch(BuildContext context, WidgetRef ref, HumanWorkDetailViewModel vm) {
    return Padding(
      padding: EdgeInsets.all(context.rsi(8)),
      child: DropdownSearch<PlaceDropDownModel>(
        asyncItems: (text) =>
            ref.read(workCostUseCaseProvider).getPlacesForWorkCost(hid),
        itemAsString: (item) => item.pname,
        selectedItem: PlaceDropDownModel(pname: '전체 현장', pid: 0),
        dropdownDecoratorProps: const DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(hintText: '현장을 선택해주세요.'),
        ),
        onChanged: (value) {
          if (value == null) return;
          Future(() => vm.fetchWorkCostByHid(value.pid));
        },
      ),
    );
  }

  Widget _buildPriceTextBar(BuildContext context, HumanWorkDetailState state) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      height: context.rs(40),
      padding: EdgeInsets.fromLTRB(
        context.rsi(10),
        context.rsi(10),
        context.rsi(20),
        context.rsi(10),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            state.isTaxApply ? '세 후 :  ' : '세 전 :  ',
            style: tt.labelMedium?.copyWith(
              color: state.isTaxApply ? cs.error : cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            getPrice(price: state.totalPrice, isTaxApply: state.isTaxApply),
            style: tt.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSegmentControl(
    BuildContext context,
    WidgetRef ref,
    HumanWorkDetailViewModel vm,
    HumanWorkDetailState state,
  ) {
    final cs = Theme.of(context).colorScheme;
    return CupertinoSlidingSegmentedControl<TaxState>(
      thumbColor: state.isTaxApply
          ? cs.errorContainer.withValues(alpha: 0.65)
          : cs.primaryContainer.withValues(alpha: 0.65),
      groupValue: state.taxState,
      children: const {
        TaxState.taxOff: Text('세전'),
        TaxState.taxOn: Text('세후'),
      },
      onValueChanged: vm.taxStateValueChanged,
    );
  }

  Widget _buildCompleteSegmentControl(
    BuildContext context,
    WidgetRef ref,
    HumanWorkDetailViewModel vm,
    HumanWorkDetailState state,
  ) {
    final segStyle = Theme.of(context).textTheme.labelMedium;
    return CupertinoSlidingSegmentedControl<CompleteState>(
      groupValue: state.completeState,
      children: {
        CompleteState.whole: Text('전체', style: segStyle),
        CompleteState.incomplete: Text('미지급', style: segStyle),
      },
      onValueChanged: vm.completeStateValueChanged,
    );
  }

  Widget workCostCard(
    BuildContext context,
    HumanWorkDetailState state,
    int index,
  ) {
    final element = state.filteredWorkCostList[index];
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListTile(
      title: Text(
        element.pname,
        style: tt.bodyLarge,
      ),
      subtitle: Text(
        formatDateTimeToStringBySlash(
          DateTime.parse(element.wdate),
        ),
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Text(
        getPrice(price: element.wprice, isTaxApply: state.isTaxApply),
        style: tt.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: element.wcomplete == 0 ? cs.error : null,
        ),
      ),
    );
  }
}
