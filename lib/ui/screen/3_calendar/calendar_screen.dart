import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';
import 'package:w0001/ui/screen/3_calendar/widgets/calendar_day_cost_list_skeleton.dart';
import 'package:w0001/ui/screen/3_calendar/widgets/calendar_place_cost_summary_row.dart';
import 'package:w0001/ui/widget/calendar/my_calendar.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/work_cost_delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:w0001/ui/widget/total_cost_card.dart';
import 'package:w0001/ui/widget/total_price_bar.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final ScrollController _listScroll;

  @override
  void initState() {
    super.initState();
    _listScroll = ScrollController()..addListener(_onListScroll);
  }

  void _onListScroll() {
    onPagedScrollNearEnd(
      _listScroll,
      onLoadMore: () => ref.read(calendarProvider.notifier).loadMoreDayCosts(),
    );
  }

  void _scheduleLoadMoreCheck() {
    schedulePagedScrollNearEndCheck(
      _listScroll,
      onLoadMore: () => ref.read(calendarProvider.notifier).loadMoreDayCosts(),
    );
  }

  @override
  void dispose() {
    _listScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = ref.watch(authSessionProvider).maybeWhen(
          data: (u) => u != null && !u.role.canEditCalendarExpenses,
          orElse: () => false,
        );
    return Scaffold(
      body: Column(
        children: [
          const CalendarWidget(),
          _buildTotalPriceBar(ref),
          Expanded(
            child: _buildListView(context, readOnly),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    bool readOnly,
  ) {
    final state = ref.watch(calendarProvider);
    final vm = ref.read(calendarProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (state.dayCostIsLoading && state.totalCostList.isEmpty) {
      return const CalendarDayCostListSkeleton();
    }

    if (vm.placeCount == 0) {
      return Center(
        child: Text(
          '조회된 데이터가 없습니다.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    final places = vm.getUniquePlaceNameAndComplete();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleLoadMoreCheck());

    return Padding(
      padding: ResponsiveLayout.only(context,
          left: 12, top: 4, right: 12, bottom: 8),
      child: ListView.separated(
        controller: _listScroll,
        itemCount: places.length + 1,
        separatorBuilder: (_, __) => SizedBox(height: context.rsi(8)),
        itemBuilder: (context, index) {
          if (index == places.length) {
            return PagedListFooter(
              isLoading: state.dayCostIsLoadingMore,
              hasMore: state.dayCostHasMore,
            );
          }
          return _buildPlaceCard(
            context,
            readOnly,
            vm,
            cs,
            tt,
            state.selectedFilterType,
            places[index],
          );
        },
      ),
    );
  }

  Widget _buildPlaceCard(
    BuildContext context,
    bool readOnly,
    CalendarViewModel vm,
    ColorScheme cs,
    TextTheme tt,
    FilterType selectedFilterType,
    Map<String, dynamic> placeInfo,
  ) {
    final pname = placeInfo['pname'] as String;
    final pcomplete = placeInfo['pcomplete'] as int;
    final summary = vm.placeDayCostSummary(pname);
    final placeItems =
        vm.filteredTotalCostList.where((e) => e.pname == pname).toList();
    final filteredAmount =
        placeItems.fold<int>(0, (sum, element) => sum + element.price);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(context.rs(14)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: cs.primary.withValues(alpha: 0.06),
          highlightColor: cs.primary.withValues(alpha: 0.04),
        ),
        child: ExpansionTile(
          key: PageStorageKey<String>('calendar_place_$pname'),
          initiallyExpanded: false,
          visualDensity: VisualDensity.compact,
          controlAffinity: ListTileControlAffinity.trailing,
          tilePadding: ResponsiveLayout.only(
            context,
            left: 10,
            top: 8,
            right: 4,
            bottom: 8,
          ),
          childrenPadding: ResponsiveLayout.only(
            context,
            left: 10,
            top: 0,
            right: 10,
            bottom: 10,
          ),
          title: SizedBox(
            width: double.infinity,
            child: CalendarPlaceCostSummaryPanel(
              placeName: pname,
              isPlaceComplete: pcomplete != 0,
              summary: summary,
              selectedFilterType: selectedFilterType,
              filteredAmount: filteredAmount,
            ),
          ),
          expandedAlignment: Alignment.centerLeft,
          children: [
            for (var element in placeItems)
              Padding(
                padding: EdgeInsets.only(bottom: context.rs(8)),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: readOnly
                      ? Padding(
                          padding: EdgeInsets.all(context.rsi(6)),
                          child: TotalCostCard(
                            category: element.category,
                            name: element.name,
                            price: element.price,
                            wcomplete: element.wcomplete,
                            wcompletedAt: element.wcompletedAt,
                          ),
                        )
                      : Slidable(
                          closeOnScroll: true,
                          startActionPane: element.category == 'w'
                              ? ActionPane(
                                  motion: const DrawerMotion(),
                                  children: [
                                    SlidableAction(
                                      autoClose: true,
                                      borderRadius: BorderRadius.circular(10),
                                      backgroundColor: element.wcomplete == 1
                                          ? cs.primaryContainer
                                          : cs.tertiary,
                                      icon: element.wcomplete == 1
                                          ? Icons.autorenew_outlined
                                          : Icons.check_circle,
                                      label: element.wcomplete == 1
                                          ? '미지급으로 변경'
                                          : '지급 완료',
                                      onPressed: (slidableCtx) async {
                                        final msg = await vm.updateWComplete(
                                            element.wcomplete, element.id);
                                        if (!slidableCtx.mounted) {
                                          return;
                                        }
                                        await showDialog<void>(
                                          context: slidableCtx,
                                          builder: (_) => saveDialog(text: msg),
                                        );
                                      },
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
                                backgroundColor: cs.error,
                                icon: Icons.delete,
                                label: '삭제',
                                onPressed: (slidableCtx) async {
                                  if (element.category == 'w') {
                                    final pwdid = await vm
                                        .placeWorkDayPwdidForWorkCost(element);
                                    if (!slidableCtx.mounted) return;
                                    final choice =
                                        await showWorkCostDeleteDialog(
                                      slidableCtx,
                                      placeName: element.pname,
                                      workerName: element.name,
                                      dateLabel: element.date,
                                      hasLinkedWorkDay: pwdid != null,
                                      workrole: element.workrole,
                                    );
                                    if (choice == null ||
                                        choice == WorkCostDeleteChoice.cancel ||
                                        !slidableCtx.mounted) {
                                      return;
                                    }
                                    await vm.deleteWorkCostLinked(
                                      wid: element.id,
                                      pwdid: choice ==
                                              WorkCostDeleteChoice
                                                  .costAndWorkDay
                                          ? pwdid
                                          : null,
                                    );
                                    return;
                                  }
                                  await showDialog<void>(
                                    context: slidableCtx,
                                    builder: (dialogCtx) => deleteDialog(
                                      onPressed: () async {
                                        await vm.deleteCost(
                                            element.category, element.id);
                                        if (dialogCtx.mounted) {
                                          Navigator.of(dialogCtx).pop();
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          child: _editableCard(context, element),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalPriceBar(WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final vm = ref.read(calendarProvider.notifier);
    final callbacks = {
      for (final type in FilterType.values)
        type.category: (_) => vm.setFilterType(type),
    };
    return TotalPriceBar(
      totalCostList: state.totalCostList,
      categoryTapCallbacks: callbacks,
      dayTotals: state.dayCostTotals,
      compact: true,
      dense: true,
    );
  }

  Widget _editableCard(
    BuildContext context,
    TotalCostModel element,
  ) {
    final vm = ref.read(calendarProvider.notifier);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        vm.prepareEditDialog(element);
        showDialog<void>(
          context: context,
          builder: (dialogContext) => Consumer(
            builder: (context, ref, _) {
              final dialogState = ref.watch(calendarProvider);
              final dialogVm = ref.read(calendarProvider.notifier);
              final cs = Theme.of(context).colorScheme;
              final tt = Theme.of(context).textTheme;
              return Dialog(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(context.rsi(14)),
                    color: cs.surface,
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.rsi(16),
                      context.rsi(14),
                      context.rsi(16),
                      context.rsi(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '지출 내역 수정',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: context.rsi(4)),
                        Text(
                          '날짜/항목/금액을 수정하고 저장하세요.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: context.rsi(10)),
                        _readOnlyDialogDateCalendar(
                          context,
                          dialogState.dialogDateTime,
                        ),
                        if (element.category != 'w') ...[
                          SizedBox(height: context.rsi(8)),
                          SizedBox(
                            height: 60,
                            child: DropdownSearch<String>(
                              items: categoryList,
                              onChanged: (value) =>
                                  dialogVm.categoryChangeAction(value!),
                              selectedItem:
                                  dialogState.dropDownSelectedCategory,
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: context.rsi(8)),
                        AddTextField(
                          tController: dialogVm.mNameController,
                          labelText: '항목',
                          isPrice: false,
                          height: 60,
                          keyboardType: TextInputType.text,
                          readOnly: element.category == 'w' ? true : false,
                          onChanged: (value) => dialogVm.clearEditAlert(),
                        ),
                        SizedBox(height: context.rsi(4)),
                        AddTextField(
                          tController: dialogVm.mPriceController,
                          labelText: '금액',
                          isPrice: true,
                          height: 60,
                          keyboardType: TextInputType.number,
                          readOnly: false,
                          onChanged: (value) => dialogVm.clearEditAlert(),
                        ),
                        if (dialogState.alertText.isNotEmpty) ...[
                          SizedBox(height: context.rsi(6)),
                          Text(
                            dialogState.alertText,
                            style: tt.bodySmall?.copyWith(color: cs.error),
                          ),
                        ],
                        SizedBox(height: context.rsi(8)),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  dialogVm.clearEditAlert();
                                  Navigator.of(dialogContext).pop();
                                },
                                child: const Text('취소'),
                              ),
                            ),
                            SizedBox(width: context.rsi(8)),
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  final ok = await dialogVm.updateCost(
                                    element.category,
                                    element.id,
                                    dialogState.dialogDateTime.toString(),
                                  );
                                  if (ok && dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                },
                                child: const Text('수정 저장'),
                              ),
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
      },
      child: Padding(
        padding: EdgeInsets.all(context.rsi(6)),
        child: TotalCostCard(
          category: element.category,
          name: element.name,
          price: element.price,
          wcomplete: element.wcomplete,
          wcompletedAt: element.wcompletedAt,
        ),
      ),
    );
  }

  Widget _readOnlyDialogDateCalendar(BuildContext context, DateTime day) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selectedDay = DateTime(day.year, day.month, day.day);
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(context.rsi(12)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        context.rsi(10),
        context.rsi(10),
        context.rsi(10),
        context.rsi(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formatDateTimeWeekDayToString(selectedDay),
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
