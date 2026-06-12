import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/widget/work_cost_delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/ui/widget/segment_widget.dart';
import 'package:w0001/util/worker_skills_display.dart';
import 'package:w0001/ui/screen/4_human/widgets/work_cost_process_meta.dart'
    show WorkCostRoleChip;
import 'package:w0001/util/responsive_layout.dart';

Widget _metaChip({
  required BuildContext context,
  required String label,
  IconData? icon,
  bool compact = false,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
    ),
    child: Padding(
      padding: ResponsiveLayout.symmetric(
        context,
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: context.rsi(compact ? 12 : 14),
              color: cs.onSurfaceVariant,
            ),
            rsH(context, compact ? 4 : 6),
          ],
          Text(
            label,
            style: (compact ? tt.labelSmall : tt.labelMedium)?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              height: 1.0,
            ),
          ),
        ],
      ),
    ),
  );
}

class WorkCostScreen extends ConsumerStatefulWidget {
  const WorkCostScreen({super.key});

  @override
  ConsumerState<WorkCostScreen> createState() => _WorkCostScreenState();
}

class _WorkCostScreenState extends ConsumerState<WorkCostScreen> {
  late final ScrollController _scrollWhole;
  late final ScrollController _scrollIncomplete;

  ScrollController _scrollFor(CompleteState filter) =>
      filter == CompleteState.incomplete ? _scrollIncomplete : _scrollWhole;

  @override
  void initState() {
    super.initState();
    _scrollWhole = ScrollController();
    _scrollIncomplete = ScrollController();
  }

  @override
  void dispose() {
    _scrollWhole.dispose();
    _scrollIncomplete.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                height: context.rs(28),
                width: context.rs(28),
              ),
            ),
            IconButton(
              tooltip: '인력 관리',
              onPressed: () async {
                await vm.fetchWorkerInfo();
                if (!context.mounted) return;
                await context.push('/work/human');
                if (!context.mounted) return;
                await vm.fetchWorkCost();
                vm.refreshAction();
              },
              icon: Icon(
                Icons.person_search,
                color: cs.onSurface,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size(MediaQuery.of(context).size.width, context.rs(2)),
            child: Padding(
              padding: EdgeInsets.only(bottom: context.rsi(5)),
              child: Text(
                formatDateTimeRangeToString(
                  ref.watch(workerProvider).dateTimeRange,
                  periodType: ref.watch(workerProvider).dayState,
                ),
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(context, ref, vm),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(10),
                0,
                context.rsi(10),
                context.rsi(10),
              ),
              child: _buildToggleButtons(context, ref, vm),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(10),
                0,
                context.rsi(10),
                context.rsi(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCompleteSegmentControl(context, ref, vm),
                  _buildTaxSegmentControl(context, ref, vm),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final labelStyle = tt.bodyMedium;
    final valueBold = tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rsi(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('인건비 총금액 :', style: labelStyle),
              Text('미지급 총금액 :', style: labelStyle),
              Visibility(
                visible: state.selectedCount != 0,
                child: Text('선택된 금액 :', style: labelStyle),
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
                style: valueBold,
              ),
              Text(
                getPrice(
                  price: vm.totalIncompleteCost,
                  isTaxApply: state.isTaxApply,
                ),
                style: valueBold?.copyWith(color: cs.error),
              ),
              Visibility(
                visible: state.selectedCount != 0,
                child: Text(
                  getPrice(
                    price: vm.selectedIncompleteCost,
                    isTaxApply: state.isTaxApply,
                  ),
                  style: valueBold?.copyWith(color: cs.primary),
                ),
              ),
            ],
          ),
          SizedBox(
            height: context.rs(35),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: state.selectedCount == 0
                  ? null
                  : () => vm.updateWorkCostsToComplete(context),
              child: Text('지급하기', style: tt.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteSegmentControl(
      BuildContext context, WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
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

  Widget _buildListView(
      BuildContext context, WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rsi(10)),
      child: IndexedStack(
        index: state.completeState == CompleteState.incomplete ? 1 : 0,
        children: [
          _buildWorkCostListFor(
            context: context,
            ref: ref,
            vm: vm,
            listFilter: CompleteState.whole,
          ),
          _buildWorkCostListFor(
            context: context,
            ref: ref,
            vm: vm,
            listFilter: CompleteState.incomplete,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkCostListFor({
    required BuildContext context,
    required WidgetRef ref,
    required WorkerViewModel vm,
    required CompleteState listFilter,
  }) {
    final cs = Theme.of(context).colorScheme;
    final humans = vm.getUniqueHumanFor(listFilter);
    if (humans.isEmpty) {
      return const Center(child: Text('조회된 인건비가 없습니다.'));
    }

    return ListView.builder(
      key: ValueKey<String>('work_cost_list_${listFilter.name}'),
      controller: _scrollFor(listFilter),
      itemCount: humans.length,
      itemBuilder: (context, index) {
        final uniqueHuman = humans[index];
        final workCostData = vm.processWorkCostDataFor(listFilter, uniqueHuman);
        return Slidable(
          key: ValueKey<String>('${listFilter.name}_$uniqueHuman'),
          closeOnScroll: true,
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                borderRadius: BorderRadius.circular(10),
                backgroundColor: cs.primary,
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
              key: ValueKey<String>('exp_${listFilter.name}_$uniqueHuman'),
              ref: ref,
              listFilter: listFilter,
              uniqueHuman: uniqueHuman,
              isIncomplete: listFilter == CompleteState.incomplete,
              workCostData: workCostData,
              vm: vm,
              child: _buildGroupListView(
                context,
                workCostData.filteredList,
                ref,
                vm,
                listFilter: listFilter,
                storageScope: '${listFilter.name}_$uniqueHuman',
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildGroupListView(
    BuildContext context,
    List<TotalWorkCostModel> filteredList,
    WidgetRef ref,
    WorkerViewModel vm, {
    required CompleteState listFilter,
    required String storageScope,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // ExpansionTile PageStorage(bool)와 내부 ListView 스크롤 복원(double) 충돌 방지.
    return PageStorage(
      bucket: PageStorageBucket(),
      child: GroupedListView<TotalWorkCostModel, String>(
      key: ValueKey<String>('work_cost_grouped_$storageScope'),
      order: GroupedListOrder.DESC,
      padding: EdgeInsets.only(top: context.rsi(5)),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      elements: filteredList,
      groupBy: (element) => element.date,
      groupSeparatorBuilder: (value) {
        final ymd = normalizeToIsoDateString(value);
        final d = DateTime.tryParse(ymd);
        final label = d != null ? formatDateTimeToKorean(d) : ymd;
        final compact = ResponsiveLayout.isCompact(MediaQuery.sizeOf(context));
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(compact ? 32 : 48),
            vertical: context.rsi(2),
          ),
          child: Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurface),
          ),
        );
      },
      itemBuilder: (context, element) => _buildListTile(
            context,
            ref,
            element,
            vm,
            listFilter: listFilter,
          ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    WidgetRef ref,
    TotalWorkCostModel element,
    WorkerViewModel vm, {
    required CompleteState listFilter,
  }) {
    final state = ref.watch(workerProvider);
    final cs = Theme.of(context).colorScheme;
    final isPaid = element.wcomplete == 1;
    final isIncompleteTab = listFilter == CompleteState.incomplete;
    final compact = ResponsiveLayout.isCompact(MediaQuery.sizeOf(context));

    return Slidable(
      startActionPane: isIncompleteTab
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              extentRatio: compact ? 0.18 : 0.22,
              children: [
                CustomSlidableAction(
                  onPressed: (slidableCtx) async {
                    await vm.updateWComplete(element.wcomplete, element.wid);
                    if (!slidableCtx.mounted) return;
                    await showDialog<void>(
                      context: slidableCtx,
                      builder: (_) => saveDialog(
                        text: isPaid ? '미지급으로 변경되었습니다.' : '지급 완료로 변경되었습니다.',
                      ),
                    );
                  },
                  backgroundColor: isPaid ? cs.primary : cs.tertiary,
                  foregroundColor: isPaid ? cs.onPrimary : cs.onTertiary,
                  padding: EdgeInsets.zero,
                  child: Icon(
                    isPaid ? Icons.autorenew_rounded : Icons.check_circle_rounded,
                    size: 22,
                  ),
                ),
              ],
            ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: compact ? 0.24 : 0.28,
        children: [
          CustomSlidableAction(
            onPressed: (slidableCtx) {
              _showEditWorkCostDialog(slidableCtx, ref, element, vm);
            },
            backgroundColor: cs.secondaryContainer,
            foregroundColor: cs.onSecondaryContainer,
            padding: EdgeInsets.zero,
            child: const Icon(Icons.edit_outlined, size: 20),
          ),
          CustomSlidableAction(
            onPressed: (slidableCtx) async {
              final pwdid = await vm.placeWorkDayPwdidFor(element);
              if (!slidableCtx.mounted) return;
              final choice = await showWorkCostDeleteDialog(
                slidableCtx,
                placeName: element.pname,
                workerName: element.hname,
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
                wid: element.wid,
                pwdid: choice == WorkCostDeleteChoice.costAndWorkDay
                    ? pwdid
                    : null,
              );
            },
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            padding: EdgeInsets.zero,
            child: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ],
      ),
      child: Builder(builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          vm.registerSlidable(ctx);
        });
        return Padding(
          padding: EdgeInsets.only(bottom: context.rsi(6)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final st = ref.watch(workerProvider);
                  if (isPaid) {
                    return Padding(
                      padding: EdgeInsets.only(
                        left: context.rsi(2),
                        right: context.rsi(4),
                        top: context.rsi(10),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: context.rs(20),
                        color: cs.primary,
                      ),
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: context.rsi(6)),
                    child: Checkbox(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: cs.primary, width: 2),
                      value:
                          st.checkboxStates[element.wid]?.isSelected ?? false,
                      onChanged: (_) {
                        ref
                            .read(workerProvider.notifier)
                            .toggleCheckboxState(element.wid);
                      },
                    ),
                  );
                },
              ),
              Expanded(
                child: _WorkCostListItemCard(
                  element: element,
                  isTaxApply: state.isTaxApply,
                  isPaid: isPaid,
                  completedAtLabel: element.wcompletedAt != null
                      ? _formatCompletedAt(element.wcompletedAt!)
                      : null,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _formatCompletedAt(String completedAt) {
    try {
      final dt = DateTime.parse(completedAt);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return completedAt;
    }
  }

  Future<void> _showEditWorkCostDialog(
    BuildContext context,
    WidgetRef ref,
    TotalWorkCostModel element,
    WorkerViewModel vm,
  ) async {
    final priceFormatter = CurrencyTextInputFormatter.currency(
      decimalDigits: 0,
      symbol: '',
    );
    final priceController = TextEditingController(
      text: element.price > 0
          ? priceFormatter.formatDouble(element.price.toDouble())
          : '',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: const Text('금액 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '현장: ${element.pname}',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              SizedBox(height: ctx.rsi(4)),
              Text(
                '날짜: ${element.date}',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              SizedBox(height: ctx.rsi(16)),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  priceFormatter,
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: const InputDecoration(
                  labelText: '금액',
                  isDense: true,
                  border: OutlineInputBorder(),
                  suffixText: '원',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final priceStr = priceController.text
                    .trim()
                    .replaceAll(RegExp(r'[,원\s]'), '');
                final price = int.tryParse(priceStr);
                if (price == null || price < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('올바른 금액을 입력해 주세요.')),
                  );
                  return;
                }
                
                await vm.updateWorkCostPrice(element.wid, price);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (_) => saveDialog(text: '금액이 수정되었습니다.'),
                );
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    priceController.dispose();
  }

  Widget _buildTaxSegmentControl(
      BuildContext context, WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
    final cs = Theme.of(context).colorScheme;
    return CupertinoSlidingSegmentedControl<TaxState>(
      groupValue: state.taxState,
      thumbColor: state.isTaxApply
          ? cs.errorContainer.withValues(alpha: 0.65)
          : cs.primaryContainer.withValues(alpha: 0.65),
      children: {
        TaxState.taxOff: Text(
          '세전',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        TaxState.taxOn: Text(
          '세후',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      },
      onValueChanged: vm.taxStateValueChanged,
    );
  }

  Widget _buildToggleButtons(
      BuildContext context, WidgetRef ref, WorkerViewModel vm) {
    final state = ref.watch(workerProvider);
    final cs = Theme.of(context).colorScheme;
    final toggleW =
        (MediaQuery.sizeOf(context).width - context.rs(28)) / 3;
    return SizedBox(
      height: context.rs(30),
      child: ToggleButtons(
        borderColor: cs.outlineVariant,
        selectedBorderColor: cs.outlineVariant,
        borderWidth: 1,
        borderRadius: BorderRadius.circular(5),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
        isSelected: state.toggleState,
        onPressed: (index) {
          vm.selectToggleButton(index, context).then((_) {
            vm.closeAllSliders();
            vm.collapseAllExpansionTiles();
          });
        },
        children: [
          toggleWidget(
            width: toggleW,
            child: const Text('기간 선택'),
            icon: Icon(
              Icons.calendar_month,
              color: state.dayState == DayTpye.range
                  ? cs.onSurface
                  : cs.onSurfaceVariant,
            ),
          ),
          toggleWidget(
            width: toggleW,
            child: const Text('전체 기간'),
          ),
          toggleWidget(
            width: toggleW,
            child: const Text('이번 달'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
      BuildContext context, WidgetRef ref, WorkerViewModel vm) {
    return Container(
      height: context.rs(45),
      margin: EdgeInsets.only(bottom: context.rsi(10)),
      padding: EdgeInsets.symmetric(horizontal: context.rsi(10)),
      child: SearchBar(
        leading: Icon(
          Icons.search,
          size: context.rs(30),
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

Widget _workCostStatusBadge({
  required BuildContext context,
  required bool isPaid,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final label = isPaid ? '지급완료' : '미지급';
  final bg = isPaid ? cs.primary : cs.error;
  final fg = isPaid ? cs.onPrimary : cs.onError;

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: context.rsi(7),
      vertical: context.rsi(3),
    ),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: tt.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: fg,
        height: 1,
      ),
    ),
  );
}

Widget _workCostPlaceDetails({
  required BuildContext context,
  required String pname,
  required int pcomplete,
  required String workrole,
  required Color nameColor,
  required Color completeColor,
}) {
  final tt = Theme.of(context).textTheme;
  final role = workrole.trim();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        pname,
        style: tt.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: nameColor,
          height: 1.25,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      if (pcomplete == 1 || role.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(top: context.rsi(5)),
          child: Wrap(
            spacing: context.rsi(6),
            runSpacing: context.rsi(4),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (pcomplete == 1)
                Text(
                  '[완]',
                  style: tt.labelSmall?.copyWith(
                    color: completeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (role.isNotEmpty) WorkCostRoleChip(label: role),
            ],
          ),
        ),
    ],
  );
}

String? _humanPrimaryRoleLabel(HumanModel human) {
  final skills = resolveHumanSkillsDisplay(human);
  final primary = skills.primary?.trim();
  if (primary != null && primary.isNotEmpty) return primary;
  final rank = human.hdefaultRole.trim();
  if (rank.isNotEmpty) return rank;
  return null;
}

class _WorkCostListItemCard extends StatelessWidget {
  const _WorkCostListItemCard({
    required this.element,
    required this.isTaxApply,
    required this.isPaid,
    this.completedAtLabel,
  });

  final TotalWorkCostModel element;
  final bool isTaxApply;
  final bool isPaid;
  final String? completedAtLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final priceText = getPrice(price: element.price, isTaxApply: isTaxApply);
    final nameColor = isPaid ? cs.onPrimaryContainer : cs.onSurface;
    final completeColor = isPaid
        ? cs.onPrimaryContainer.withValues(alpha: 0.7)
        : cs.onSurfaceVariant;
    final priceStyle = tt.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: isPaid ? cs.primary : cs.error,
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(10),
        vertical: context.rsi(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPaid) ...[
            Container(
              width: context.rs(3),
              height: context.rs(42),
              margin: EdgeInsets.only(top: context.rsi(2)),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            SizedBox(width: context.rsi(8)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _workCostStatusBadge(context: context, isPaid: isPaid),
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.only(left: context.rsi(8)),
                      child: Text(
                        priceText,
                        style: priceStyle,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rsi(6)),
                _workCostPlaceDetails(
                  context: context,
                  pname: element.pname,
                  pcomplete: element.pcomplete,
                  workrole: element.workrole,
                  nameColor: nameColor,
                  completeColor: completeColor,
                ),
                if (isPaid && completedAtLabel != null) ...[
                  SizedBox(height: context.rsi(5)),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: context.rs(12),
                        color: cs.primary.withValues(alpha: 0.85),
                      ),
                      SizedBox(width: context.rsi(4)),
                      Expanded(
                        child: Text(
                          completedAtLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimaryContainer
                                .withValues(alpha: 0.85),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!isPaid) {
      return Card(
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: content,
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.primaryContainer.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: cs.primary.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [
              cs.primary.withValues(alpha: 0.08),
              cs.primaryContainer.withValues(alpha: 0.02),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: content,
      ),
    );
  }
}

class WorkerExpansionTile extends StatefulWidget {
  const WorkerExpansionTile({
    super.key,
    required this.ref,
    required this.listFilter,
    required this.uniqueHuman,
    required this.workCostData,
    required this.vm,
    required this.child,
    required this.isIncomplete,
  });

  final WidgetRef ref;
  final CompleteState listFilter;
  final String uniqueHuman;
  final WorkCostData workCostData;
  final WorkerViewModel vm;
  final Widget child;
  final bool isIncomplete;

  @override
  State<WorkerExpansionTile> createState() => _WorkerExpansionTileState();
}

class _WorkerExpansionTileState extends State<WorkerExpansionTile> {
  late bool _isExpanded;
  var _disposing = false;
  var _syncingFromVm = false;
  final ExpansionTileController expansionTileController =
      ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.vm.isWorkerExpandedFor(
      widget.listFilter,
      widget.uniqueHuman,
    );
    _registerController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExpansionFromVm());
  }

  @override
  void dispose() {
    _disposing = true;
    super.dispose();
  }

  @override
  void didUpdateWidget(WorkerExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uniqueHuman != widget.uniqueHuman ||
        oldWidget.listFilter != widget.listFilter) {
      _registerController();
      _isExpanded = widget.vm.isWorkerExpandedFor(
        widget.listFilter,
        widget.uniqueHuman,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExpansionFromVm());
  }

  void _registerController() {
    widget.vm.registerExpansionTile(
      completeState: widget.listFilter,
      uniqueHuman: widget.uniqueHuman,
      controller: expansionTileController,
    );
  }

  void _syncExpansionFromVm() {
    if (!mounted) return;
    final shouldExpand = widget.vm.isWorkerExpandedFor(
      widget.listFilter,
      widget.uniqueHuman,
    );
    _syncingFromVm = true;
    try {
      if (shouldExpand && !expansionTileController.isExpanded) {
        expansionTileController.expand();
      } else if (!shouldExpand && expansionTileController.isExpanded) {
        expansionTileController.collapse();
      }
    } catch (_) {}
    _syncingFromVm = false;
    if (_isExpanded != shouldExpand) {
      setState(() => _isExpanded = shouldExpand);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.ref.watch(workerProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final compact = ResponsiveLayout.isCompact(MediaQuery.sizeOf(context));
    final wage = getPrice(price: widget.workCostData.hdailyWage);
    final human = widget.workCostData.human ??
        HumanModel(
          hid: widget.workCostData.hid,
          hname: widget.workCostData.hname,
          hnumber: widget.workCostData.hnumber,
          hdailyWage: widget.workCostData.hdailyWage,
          hdefaultRole: widget.workCostData.hdefaultRole,
          hstar: widget.workCostData.hstar,
          hdelete: 0,
        );
    final roleLabel = _humanPrimaryRoleLabel(human);
    final skills = resolveHumanSkillsDisplay(human);
    final extras = skills.extras;
    final totalPrice = getPrice(
      price: widget.workCostData.totalPrice,
      isTaxApply: state.isTaxApply,
    );
    final selectedPrice = widget.listFilter == CompleteState.incomplete &&
            widget.vm.incompleteCostByHid(widget.workCostData.hid) != 0
        ? getPrice(
            price: widget.vm.incompleteCostByHid(widget.workCostData.hid),
            isTaxApply: state.isTaxApply,
          )
        : null;

    return Card(
      color: cs.surfaceContainerLow,
      margin: EdgeInsets.only(bottom: context.rsi(compact ? 4 : 6)),
      child: ExpansionTile(
        controller: expansionTileController,
        onExpansionChanged: (value) {
          if (_disposing || _syncingFromVm) return;
          widget.vm.setWorkerExpandedFor(
            widget.listFilter,
            widget.uniqueHuman,
            value,
          );
          setState(() => _isExpanded = value);
        },
        tilePadding: EdgeInsets.symmetric(
          horizontal: context.rsi(compact ? 6 : 10),
          vertical: context.rsi(compact ? 0 : 2),
        ),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        title: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.workCostData.hname,
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (roleLabel != null) ...[
                    SizedBox(height: context.rsi(3)),
                    WorkCostRoleChip(label: roleLabel),
                  ],
                ],
              )
            : Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.workCostData.hname,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (roleLabel != null) ...[
                    SizedBox(width: context.rsi(6)),
                    WorkCostRoleChip(label: roleLabel),
                  ],
                ],
              ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: context.rsi(compact ? 4 : 6)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metaChip(
                context: context,
                icon: Icons.payments_outlined,
                label: '일당 $wage',
                compact: compact,
              ),
              if (extras.isNotEmpty) ...[
                SizedBox(height: context.rsi(3)),
                Text(
                  '추가 ${extras.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        dense: true,
        leading: IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: context.rs(compact ? 28 : 40),
            minHeight: context.rs(compact ? 28 : 40),
          ),
          onPressed: () => widget.vm
              .updateHstar(
                  hid: widget.workCostData.hid,
                  hstar: widget.workCostData.hstar)
              .then((_) {
            widget.vm.fetchWorkerInfo();
          }),
          icon: (widget.workCostData.hstar == 0)
              ? Icon(
                  Icons.star_border,
                  size: context.rs(compact ? 18 : 24),
                  color: cs.onSurfaceVariant,
                )
              : Icon(
                  Icons.star,
                  size: context.rs(compact ? 18 : 24),
                  color: cs.tertiary,
                ),
        ),
        trailing: SizedBox(
          width: context.rs(compact ? 72 : 88),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        totalPrice,
                        style: (compact ? tt.labelMedium : tt.bodyMedium)
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (selectedPrice != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          selectedPrice,
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more_rounded,
                  size: context.rs(compact ? 20 : 24),
                ),
              ),
            ],
          ),
        ),
        children: [
          Container(
            color: cs.surface,
            padding: EdgeInsets.fromLTRB(
              context.rsi(10),
              context.rsi(5),
              context.rsi(10),
              context.rsi(10),
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
