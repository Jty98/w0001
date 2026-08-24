import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/work_cost_delete_dialog.dart';
import 'package:w0001/ui/widget/work_unit_price_apply_panel.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/total_cost_card.dart';
import 'package:w0001/ui/widget/total_price_bar.dart';
import 'package:w0001/ui/widget/segment_widget.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/ui/screen/2_add/add_screen.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_models.dart';

class PlaceCostScreen extends ConsumerStatefulWidget {
  final PlaceInfoModel placeInfo;
  const PlaceCostScreen({super.key, required this.placeInfo});

  @override
  ConsumerState<PlaceCostScreen> createState() => _PlaceCostScreenState();
}

enum _PlaceCostPane { ledger, add }

class _PlaceCostScreenState extends ConsumerState<PlaceCostScreen> {
  var _pane = _PlaceCostPane.ledger;

  PlaceInfoModel get placeInfo => widget.placeInfo;

  Future<bool> _showCostDeleteConfirmDialog(
    BuildContext context, {
    required TotalCostModel item,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: Icon(
            Icons.delete_forever_rounded,
            color: cs.error,
            size: context.rs(26),
          ),
          title: const Text('지출 내역 삭제'),
          content: Text(
            '${item.name}\n${item.getDay}\n\n삭제한 내역은 복구할 수 없습니다.',
            style: tt.bodyMedium?.copyWith(
              height: 1.45,
              color: cs.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<T> _runWithHammerLoading<T>({
    required BuildContext context,
    required Future<T> Function() task,
    String message = '처리 중입니다...',
  }) async {
    var shown = false;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (context.mounted) {
      shown = true;
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.14),
        builder: (dialogCtx) => PopScope(
          canPop: false,
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: dialogCtx.rsi(36)),
                padding: EdgeInsets.fromLTRB(
                  dialogCtx.rsi(20),
                  dialogCtx.rsi(16),
                  dialogCtx.rsi(20),
                  dialogCtx.rsi(12),
                ),
                decoration: BoxDecoration(
                  color: Theme.of(dialogCtx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(dialogCtx)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.55),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HammerLoadingIndicator(size: 34),
                    SizedBox(height: dialogCtx.rsi(10)),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    try {
      return await task();
    } finally {
      if (shown) {
        try {
          rootNavigator.pop();
        } catch (_) {
          // Navigator route state changed before pop.
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = ref.watch(authSessionProvider).maybeWhen(
          data: (u) => u != null && !u.role.canEditPlaceLedger,
          orElse: () => false,
        );
    final state = ref.watch(placeDetailProvider(placeInfo.pid!));
    final vm = ref.read(placeDetailProvider(placeInfo.pid!).notifier);
    final showAddPane = !readOnly && _pane == _PlaceCostPane.add;
    final segmentH = readOnly ? 0.0 : context.rs(44);
    final ledgerChromeH = showAddPane ? 0.0 : context.rs(72);
    return Scaffold(
      appBar: AppBar(
        title:
            readOnly ? Text('${placeInfo.pname} · 조회') : Text(placeInfo.pname),
        centerTitle: true,
        actions: [
          if (!readOnly && !showAddPane) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  vm.exportAndSharePlaceInfoToExcel(placeInfo.pname),
              icon: Image.asset(
                'assets/images/excel_logo.png',
                height: context.rs(28),
                width: context.rs(28),
              ),
            ),
            IconButton(
              onPressed: () async {
                await context.push('/place/detail/revenue', extra: placeInfo);
                if (!context.mounted) return;
                vm.clearRevenuePickedOnLeaveRevenueScreen();
              },
              icon: Image.asset(
                'assets/images/add_money.png',
                height: context.rs(28),
                width: context.rs(28),
              ),
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: Size(
            MediaQuery.of(context).size.width,
            segmentH + ledgerChromeH + context.rsi(12),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: context.rsi(10),
              left: context.rsi(10),
              right: context.rsi(10),
            ),
            child: Column(
              children: [
                if (!readOnly) _buildPaneSegment(context),
                if (!showAddPane) ...[
                  if (!readOnly) SizedBox(height: context.rsi(8)),
                  Text(
                    formatDateTimeRangeToString(
                      state.dateTimeRange,
                      periodType: state.selectedDayType,
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: context.rsi(5)),
                  IgnorePointer(
                    ignoring: readOnly,
                    child: Opacity(
                      opacity: readOnly ? 0.65 : 1,
                      child: _selectDurationButtons(context, state, vm),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: showAddPane
          ? AddScreen(embeddedPlace: placeModelForAddCost(placeInfo))
          : Column(
              children: [
                TotalPriceBar(
                  totalCostList: vm.rangeFilterList,
                  categoryTapCallbacks: {
                    for (final type in FilterType.values)
                      type.category: (category) => vm.changeFilterType(type),
                  },
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: context.rsi(10)),
                  child: Text(
                    '${state.selectedFilterType.category} ${getPrice(price: vm.selectedPrice)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(child: expenseList(context, state, vm, readOnly)),
              ],
            ),
    );
  }

  Widget _buildPaneSegment(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<_PlaceCostPane>(
        groupValue: _pane,
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.82),
        thumbColor: cs.surface,
        children: {
          _PlaceCostPane.ledger: Padding(
            padding: EdgeInsets.symmetric(vertical: context.rsi(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: context.rsi(16),
                  color: _pane == _PlaceCostPane.ledger
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
                SizedBox(width: context.rsi(6)),
                Text(
                  '내역',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _pane == _PlaceCostPane.ledger
                        ? cs.onSurface
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _PlaceCostPane.add: Padding(
            padding: EdgeInsets.symmetric(vertical: context.rsi(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: context.rsi(16),
                  color: _pane == _PlaceCostPane.add
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
                SizedBox(width: context.rsi(6)),
                Text(
                  '추가',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _pane == _PlaceCostPane.add
                        ? cs.onSurface
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        },
        onValueChanged: (pane) {
          if (pane == null) return;
          setState(() => _pane = pane);
          if (pane == _PlaceCostPane.add) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final model = placeModelForAddCost(placeInfo);
              final current = ref.read(addCostProvider).selectedPlace;
              if (current?.pid != model.pid) {
                ref.read(addCostProvider.notifier).placeChangeAction(
                      context,
                      model,
                    );
              }
            });
          }
        },
      ),
    );
  }

  Row _selectDurationButtons(
    BuildContext context,
    PlaceDetailState state,
    PlaceDetailViewModel vm,
  ) {
    final tt = Theme.of(context).textTheme;
    final toggleW = (MediaQuery.sizeOf(context).width - context.rs(25)) / 3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: context.rs(30),
          child: ToggleButtons(
            borderWidth: 1,
            borderColor: const Color.fromARGB(255, 177, 176, 176),
            selectedBorderColor: const Color.fromARGB(255, 177, 176, 176),
            textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            borderRadius: BorderRadius.circular(5),
            isSelected: state.toggleState,
            onPressed: (index) {
              vm.changeDateTimeRange(index, context);
            },
            children: [
              toggleWidget(
                width: toggleW,
                height: context.rs(24),
                child: const Text('기간 선택'),
                icon: Icon(
                  Icons.calendar_month,
                  color: state.selectedDayType == DayTpye.range
                      ? const Color.fromARGB(255, 5, 5, 5)
                      : const Color.fromARGB(255, 106, 116, 149),
                ),
              ),
              toggleWidget(
                height: context.rs(24),
                width: toggleW,
                child: const Text('전체 기간'),
              ),
              toggleWidget(
                height: context.rs(24),
                width: toggleW,
                child: const Text('이번 달'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget expenseList(
    BuildContext context,
    PlaceDetailState state,
    PlaceDetailViewModel vm,
    bool readOnly,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isInitialLoading = state.isLoading && state.totalCostList.isEmpty;

    return AppRefreshIndicator(
      enabled: !isInitialLoading,
      onRefresh: () async {
        print('🔄 [금액관리] 당겨서 새로고침 시작');
        await vm.fetchTotalCostFromPlace(forceRefresh: true);
        print('✅ [금액관리] 당겨서 새로고침 완료');
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(12),
          0,
          context.rsi(12),
          context.rsi(10),
        ),
        child: vm.filteredTotalCostList.isEmpty
            ? (state.isLoading && state.totalCostList.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: context.rsi(180)),
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HammerLoadingIndicator(size: 36),
                            SizedBox(height: 10),
                            Text('금액 데이터를 불러오는 중입니다...'),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 160),
                      const Center(child: Text('지출 내역이 없습니다.')),
                      if (!readOnly) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: FilledButton.tonalIcon(
                            onPressed: () {
                              setState(() => _pane = _PlaceCostPane.add);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                final model = placeModelForAddCost(placeInfo);
                                final current =
                                    ref.read(addCostProvider).selectedPlace;
                                if (current?.pid != model.pid) {
                                  ref
                                      .read(addCostProvider.notifier)
                                      .placeChangeAction(context, model);
                                }
                              });
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('금액 추가'),
                          ),
                        ),
                      ],
                    ],
                  ))
            : GroupedListView(
                physics: const AlwaysScrollableScrollPhysics(),
                elements: vm.filteredTotalCostList,
                order: GroupedListOrder.DESC,
                groupBy: (element) => element.getDay,
                groupSeparatorBuilder: (value) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(2),
                        context.rsi(14),
                        context.rsi(2),
                        context.rsi(8),
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rsi(10),
                          vertical: context.rsi(5),
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          value,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.rsi(2)),
                  ],
                ),
                itemBuilder: (context, element) => Padding(
                  padding: EdgeInsets.only(bottom: context.rsi(8)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: paymentList(context, element, state, vm, readOnly),
                  ),
                ),
              ),
      ),
    );
  }

  Widget paymentList(
    BuildContext context,
    TotalCostModel element,
    PlaceDetailState state,
    PlaceDetailViewModel vm,
    bool readOnly,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (readOnly) {
      return Padding(
        padding: EdgeInsets.all(context.rsi(6)),
        child: TotalCostCard(
          category: element.category,
          name: element.name,
          price: element.price,
          wcomplete: element.wcomplete,
        ),
      );
    }
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
                      : cs.tertiary,
                  icon: element.wcomplete == 1
                      ? Icons.autorenew_outlined
                      : Icons.check_circle,
                  label: element.wcomplete == 1 ? '미지급으로 변경' : '지급 완료',
                  onPressed: (slidableCtx) async {
                    try {
                      await _runWithHammerLoading<void>(
                        context: slidableCtx,
                        message: '지급 상태를 변경하는 중입니다...',
                        task: () => vm
                            .updateWComplete(element.wcomplete, element.id)
                            .timeout(const Duration(seconds: 20)),
                      );
                    } catch (_) {
                      if (slidableCtx.mounted) {
                        ScaffoldMessenger.of(slidableCtx).showSnackBar(
                          const SnackBar(
                            content: Text('요청이 지연되고 있습니다. 잠시 후 다시 시도해주세요.'),
                          ),
                        );
                      }
                      return;
                    }
                    FetchData.onDataChanged(
                      DataChangeEvent(DataChangeKind.workCost)
                          .withPid(placeInfo.pid!),
                    );
                    if (!slidableCtx.mounted) return;
                    showDialog<void>(
                      context: slidableCtx,
                      builder: (_) => saveDialog(
                        text:
                            '${element.wcomplete == 1 ? '미지급으로' : '완료로'} 변경되었습니다.',
                      ),
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
              final rootCtx = context;
              if (element.category == 'w') {
                final pwdid = await vm.placeWorkDayPwdidForWorkCost(element);
                if (!mounted) return;
                final choice = await showWorkCostDeleteDialog(
                  rootCtx,
                  placeName: element.pname,
                  workerName: element.name,
                  dateLabel: element.getDay,
                  hasLinkedWorkDay: pwdid != null,
                  workrole: element.workrole,
                );
                if (choice == null ||
                    choice == WorkCostDeleteChoice.cancel ||
                    !mounted) {
                  return;
                }
                try {
                  await _runWithHammerLoading<void>(
                    context: rootCtx,
                    message: '삭제 중입니다...',
                    task: () => vm
                        .deleteWorkCostLinked(
                          wid: element.id,
                          pwdid: choice == WorkCostDeleteChoice.costAndWorkDay
                              ? pwdid
                              : null,
                        )
                        .timeout(const Duration(seconds: 20)),
                  );
                  FetchData.onDataChanged(
                    DataChangeEvent(
                      element.category == 'w'
                          ? DataChangeKind.workCost
                          : DataChangeKind.materialCost,
                    ).withPid(placeInfo.pid!),
                  );
                } catch (_) {
                  if (!rootCtx.mounted) return;
                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                    const SnackBar(
                      content: Text('삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
                    ),
                  );
                }
                return;
              }
              final ok = await _showCostDeleteConfirmDialog(
                rootCtx,
                item: element,
              );
              if (!ok || !mounted) return;
              try {
                await _runWithHammerLoading<void>(
                  context: rootCtx,
                  message: '삭제 중입니다...',
                  task: () => vm
                      .deleteCost(element.category, element.id)
                      .timeout(const Duration(seconds: 20)),
                );
                FetchData.onDataChanged(
                  DataChangeEvent(
                    element.category == 'w'
                        ? DataChangeKind.workCost
                        : DataChangeKind.materialCost,
                  ).withPid(placeInfo.pid!),
                );
              } catch (_) {
                if (!rootCtx.mounted) return;
                ScaffoldMessenger.of(rootCtx).showSnackBar(
                  const SnackBar(
                    content: Text('삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              vm.dropDownCategoryChangeAction(element.category);
              vm.mNameController.text = element.name;
              vm.mPriceController.text =
                  getPrice(price: element.price, isContainWon: false);
              vm.setDialogDateTime(DateTime.parse(element.date));
              vm.clearAlertText();

              showDialog<void>(
                context: context,
                builder: (dialogCtx) => Consumer(
                  builder: (context, ref, _) {
                    final pid = placeInfo.pid!;
                    final dialogState = ref.watch(placeDetailProvider(pid));
                    final dialogVm =
                        ref.read(placeDetailProvider(pid).notifier);
                    return editCostDialog(
                      element,
                      dialogCtx,
                      dialogState,
                      dialogVm,
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
              ),
            ),
          );
        },
      ),
    );
  }

  Dialog editCostDialog(
    TotalCostModel element,
    BuildContext context,
    PlaceDetailState state,
    PlaceDetailViewModel vm,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isWorkCost = element.category == 'w';
    return Dialog(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.rsi(14)),
          color: cs.surface,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(14),
              context.rsi(16),
              context.rsi(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isWorkCost ? '인건비 금액 수정' : '지출 내역 수정',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: context.rsi(4)),
                Text(
                  isWorkCost
                      ? '공수를 고르거나 금액을 직접 수정해 저장하세요.'
                      : '항목/금액을 수정하고 저장하세요.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                SizedBox(height: context.rsi(8)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rsi(12),
                    vertical: context.rsi(12),
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.date_range_outlined,
                        color: cs.primary,
                        size: context.rsi(18),
                      ),
                      SizedBox(width: context.rsi(8)),
                      Expanded(
                        child: Text(
                          formatDateTimeWeekDayToString(state.dialogDateTime),
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isWorkCost) ...[
                  SizedBox(height: context.rsi(8)),
                  SizedBox(
                    height: 60,
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
                ],
                SizedBox(height: context.rsi(8)),
                AddTextField(
                  tController: vm.mNameController,
                  labelText: '항목',
                  isPrice: false,
                  height: 60,
                  keyboardType: TextInputType.text,
                  readOnly: isWorkCost,
                  onChanged: (_) => vm.clearAlertText(),
                ),
                if (isWorkCost) ...[
                  SizedBox(height: context.rsi(10)),
                  WorkUnitPriceApplyPanel(
                    priceController: vm.mPriceController,
                    currentPrice: element.price,
                    workerHid: element.whid,
                    onApplied: vm.clearAlertText,
                  ),
                ],
                SizedBox(height: context.rsi(4)),
                AddTextField(
                  tController: vm.mPriceController,
                  labelText: '금액',
                  isPrice: true,
                  height: 60,
                  keyboardType: TextInputType.number,
                  readOnly: false,
                  onChanged: (_) => vm.clearAlertText(),
                ),
                if (state.alertText.isNotEmpty) ...[
                  SizedBox(height: context.rsi(6)),
                  Text(
                    state.alertText,
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ],
                if (isWorkCost &&
                    element.whid != null &&
                    element.wpid != null &&
                    element.wpid! > 0) ...[
                  SizedBox(height: context.rsi(8)),
                  OutlinedButton.icon(
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      color: cs.error,
                      size: context.rsi(18),
                    ),
                    label: const Text('이 현장 투입 빼기'),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('현장 투입 빼기'),
                          content: Text(
                            '${element.name} · ${element.pname}\n'
                            '${formatDateTimeWeekDayToString(state.dialogDateTime)}\n\n'
                            '이 현장 투입만 제거합니다.\n'
                            '다른 현장 투입이 남아 있으면 인건비(1공수)는 유지됩니다.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('취소'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('현장 빼기'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      try {
                        await vm.unassignSameDayPlaceFromWorkCost(element);
                        if (context.mounted) Navigator.of(context).pop();
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '현장 투입을 빼지 못했습니다. 잠시 후 다시 시도해 주세요.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
                SizedBox(height: context.rsi(8)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                    ),
                    SizedBox(width: context.rsi(8)),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            await vm.updateCost(
                              element.category,
                              element.id,
                              state.dialogDateTime.toString(),
                            );
                            final alert = ref
                                .read(placeDetailProvider(placeInfo.pid!))
                                .alertText;
                            if (alert.isNotEmpty) return;
                            FetchData.onDataChanged(
                              DataChangeEvent(
                                element.category == 'w'
                                    ? DataChangeKind.workCost
                                    : DataChangeKind.materialCost,
                              ).withPid(placeInfo.pid!),
                            );
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '수정에 실패했습니다. 잠시 후 다시 시도해 주세요.',
                                ),
                              ),
                            );
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
      ),
    );
  }
}
