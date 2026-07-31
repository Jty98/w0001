import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/4_human/widgets/work_cost_chrome.dart';
import 'package:w0001/ui/screen/4_human/widgets/work_cost_loading_skeleton.dart';
import 'package:w0001/ui/screen/4_human/work_cost_human_key_codec.dart';
import 'package:w0001/ui/screen/4_human/widgets/work_cost_process_meta.dart'
    show WorkCostHumanBadges;
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:w0001/util/responsive_layout.dart';

Widget _metaChip({
  required BuildContext context,
  required String label,
  IconData? icon,
  bool compact = false,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return AppInsetTile(
    borderRadius: BorderRadius.circular(999),
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
  late final TextEditingController _workCostSearchController;

  ScrollController _scrollFor(CompleteState filter) =>
      filter == CompleteState.incomplete ? _scrollIncomplete : _scrollWhole;

  @override
  void initState() {
    super.initState();
    _scrollWhole = ScrollController()..addListener(_onScrollWhole);
    _scrollIncomplete = ScrollController()..addListener(_onScrollIncomplete);
    final initialQuery = ref.read(workerProvider.notifier).workCostSearchQuery;
    _workCostSearchController = TextEditingController(text: initialQuery);
  }

  void _onScrollWhole() => _onScrollFor(CompleteState.whole);

  void _onScrollIncomplete() => _onScrollFor(CompleteState.incomplete);

  void _onScrollFor(CompleteState filter) {
    final state = ref.read(workerProvider);
    if (state.completeState != filter) return;
    onPagedScrollNearEnd(
      _scrollFor(filter),
      onLoadMore: () =>
          ref.read(workerProvider.notifier).loadMoreWorkCostSummaries(),
    );
  }

  void _scheduleLoadMoreCheck(CompleteState filter) {
    schedulePagedScrollNearEndCheck(
      _scrollFor(filter),
      onLoadMore: () =>
          ref.read(workerProvider.notifier).loadMoreWorkCostSummaries(),
    );
  }

  @override
  void dispose() {
    _workCostSearchController.dispose();
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

    return Scaffold(
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
            child: const WorkCostPeriodToggleBar(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(10),
              0,
              context.rsi(10),
              context.rsi(6),
            ),
            child: const WorkCostFilterBar(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(10),
              0,
              context.rsi(10),
              context.rsi(8),
            ),
            child: const WorkCostCompactPlaceFilter(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: _buildListView(context, ref, vm),
            ),
          ),
          const WorkCostPaymentFooter(),
        ],
      ),
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
    final state = ref.watch(workerProvider);
    final showSkeleton = state.isWorkCostLoading;
    if (showSkeleton) {
      return const WorkCostWorkerListSkeleton();
    }

    if (state.workCostUsesLegacyList) {
      return _buildLegacyHumanList(context, ref, vm, listFilter);
    }

    final summaries = vm.workCostSummariesForCurrentFilter;
    if (summaries.isEmpty) {
      return const Center(child: Text('조회된 인건비가 없습니다.'));
    }

    if (state.completeState == listFilter) {
      _scheduleLoadMoreCheck(listFilter);
    }

    final showFooter = state.completeState == listFilter;
    final itemCount = summaries.length + (showFooter ? 1 : 0);

    return ListView.builder(
      key: ValueKey<String>('work_cost_summaries_${listFilter.name}'),
      controller: _scrollFor(listFilter),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= summaries.length) {
          return PagedListFooter(
            isLoading: state.workCostSummariesIsLoadingMore,
            hasMore: state.workCostSummariesHasMore,
          );
        }
        final summary = summaries[index];
        final workCostData = vm.workCostDataFromSummary(summary);
        return _WorkerWorkCostSummaryCard(
          workCostData: workCostData,
          uniqueHumanKey: summary.uniqueHumanKey,
          listFilter: listFilter,
          vm: vm,
          onTap: () {
            context.push(
              '/work/items/${encodeWorkCostHumanRouteKey(summary.uniqueHumanKey)}',
            );
          },
        );
      },
    );
  }

  Widget _buildLegacyHumanList(
    BuildContext context,
    WidgetRef ref,
    WorkerViewModel vm,
    CompleteState listFilter,
  ) {
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
        return _WorkerWorkCostSummaryCard(
          workCostData: workCostData,
          uniqueHumanKey: uniqueHuman,
          listFilter: listFilter,
          vm: vm,
          onTap: () {
            context.push(
              '/work/items/${encodeWorkCostHumanRouteKey(uniqueHuman)}',
            );
          },
        );
      },
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
            onPressed: () {
              _workCostSearchController.clear();
              vm.clearWorkCostSearch();
            },
            icon: const Icon(Icons.close),
          ),
        ],
        hintText: '검색할 사람의 이름을 입력하세요.',
        controller: _workCostSearchController,
        onChanged: vm.searchWoker,
      ),
    );
  }
}

class _WorkerWorkCostSummaryCard extends ConsumerWidget {
  const _WorkerWorkCostSummaryCard({
    required this.workCostData,
    required this.uniqueHumanKey,
    required this.listFilter,
    required this.vm,
    required this.onTap,
  });

  final WorkCostData workCostData;
  final String uniqueHumanKey;
  final CompleteState listFilter;
  final WorkerViewModel vm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workerProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final compact = ResponsiveLayout.isCompact(MediaQuery.sizeOf(context));
    final human = workCostData.human;
    final wage = getPrice(price: workCostData.hdailyWage);
    final selection = vm.selectionForHuman(
      hid: workCostData.hid,
      uniqueHumanKey: uniqueHumanKey,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(compact ? 6 : 8)),
      child: AppInsetTile(
        borderRadius: BorderRadius.circular(context.rs(12)),
        backgroundColor: selection.hasSelection
            ? cs.primaryContainer.withValues(alpha: 0.22)
            : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(context.rs(12)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(compact ? 10 : 12),
                context.rsi(compact ? 10 : 12),
                context.rsi(compact ? 8 : 10),
                context.rsi(compact ? 10 : 12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppInsetTile(
                    borderRadius: BorderRadius.circular(999),
                    padding: EdgeInsets.all(context.rsi(compact ? 6 : 7)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => vm
                            .updateHstar(
                              hid: workCostData.hid,
                              hstar: workCostData.hstar,
                            )
                            .then((_) => vm.fetchWorkerInfo()),
                        child: Icon(
                          workCostData.hstar == 0
                              ? Icons.star_border_rounded
                              : Icons.star_rounded,
                          size: context.rs(compact ? 18 : 20),
                          color: workCostData.hstar == 0
                              ? cs.onSurfaceVariant
                              : cs.tertiary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.rsi(compact ? 8 : 10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                workCostData.hname,
                                style:
                                    (compact ? tt.titleSmall : tt.titleMedium)
                                        ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  height: 1.15,
                                ),
                                maxLines: 2,
                              ),
                            ),
                            SizedBox(width: context.rsi(4)),
                            _metaChip(
                              context: context,
                              icon: Icons.payments_outlined,
                              label: '기본 일당 $wage',
                              compact: true,
                            ),
                          ],
                        ),
                        if (human != null) ...[
                          SizedBox(height: context.rsi(5)),
                          WorkCostHumanBadges(human: human, dense: true),
                        ],
                        SizedBox(height: context.rsi(8)),
                        WorkCostCountAmountSummary(
                          unpaidCount: workCostData.incompleteCount,
                          unpaidAmount: workCostData.incompletePrice,
                          paidCount: workCostData.completeCount,
                          paidAmount: workCostData.completePrice,
                          isTaxApply: state.isTaxApply,
                        ),
                        if (selection.hasSelection) ...[
                          SizedBox(height: context.rsi(6)),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: context.rs(compact ? 14 : 15),
                                color: cs.primary,
                              ),
                              SizedBox(width: context.rsi(4)),
                              Expanded(
                                child: Text(
                                  '${selection.count}건 선택 · ${getPrice(price: selection.amount, isTaxApply: state.isTaxApply)}',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: context.rsi(4)),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: context.rs(compact ? 22 : 24),
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
