import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/4_human/widgets/work_cost_chrome.dart';
import 'package:w0001/ui/screen/4_human/widgets/work_cost_list_body.dart';
import 'package:w0001/ui/screen/4_human/widgets/work_cost_loading_skeleton.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인건비 2단계 — 선택 인력의 항목 목록.
class WorkerWorkCostItemsScreen extends ConsumerStatefulWidget {
  const WorkerWorkCostItemsScreen({
    super.key,
    required this.uniqueHuman,
  });

  final String uniqueHuman;

  @override
  ConsumerState<WorkerWorkCostItemsScreen> createState() =>
      _WorkerWorkCostItemsScreenState();
}

class _WorkerWorkCostItemsScreenState
    extends ConsumerState<WorkerWorkCostItemsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(workerProvider.notifier)
            .ensureWorkCostItemsLoaded(widget.uniqueHuman),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      workerProvider.select(
        (s) => (
          s.completeState,
          s.dateTimeRange,
          s.workCostUsesLegacyList,
          s.workCostPlacePid,
        ),
      ),
      (previous, next) {
        if (previous == next || next.$3) return;
        unawaited(
          ref
              .read(workerProvider.notifier)
              .reloadWorkCostItemsForHuman(widget.uniqueHuman),
        );
      },
    );

    final vm = ref.read(workerProvider.notifier);
    final state = ref.watch(workerProvider);
    final listFilter = state.completeState;
    final data = vm.processWorkCostDataFor(listFilter, widget.uniqueHuman);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final itemsLoading = !state.workCostUsesLegacyList &&
        state.workCostItemsLoadingKey == widget.uniqueHuman;
    final listLoading = state.isWorkCostLoading || itemsLoading;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(
            ref
                .read(workerProvider.notifier)
                .syncSummariesIfPlaceFilterChanged(),
          );
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: context.rs(44),
            titleSpacing: context.rsi(4),
            title: WorkCostHumanAppBarTitle(name: data.hname),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(
                context.rs(data.human != null ? 58 : 24),
              ),
              child: WorkCostHumanAppBarTitle.bottomSection(
                    context: context,
                    human: data.human,
                    subtitle: Text(
                      formatDateTimeRangeToString(
                        state.dateTimeRange,
                        periodType: state.dayState,
                      ),
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                  ) ??
                  const SizedBox.shrink(),
            ),
          ),
          body: Column(
            children: [
              Material(
                color: cs.surface,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.rsi(10),
                          context.rsi(8),
                          context.rsi(10),
                          context.rsi(6),
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
                          context.rsi(6),
                        ),
                        child: WorkCostCompactPlaceFilter(
                          uniqueHumanKey: widget.uniqueHuman,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.rsi(10),
                          0,
                          context.rsi(10),
                          context.rsi(8),
                        ),
                        child: WorkCostCountAmountSummary(
                          unpaidCount: data.incompleteCount,
                          unpaidAmount: data.incompletePrice,
                          paidCount: data.completeCount,
                          paidAmount: data.completePrice,
                          isTaxApply: state.isTaxApply,
                          compact: false,
                          selectionScope: data.filteredList.isEmpty
                              ? null
                              : data.filteredList,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: cs.surface,
                  child: listLoading
                      ? Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: context.rsi(10)),
                          child: const WorkCostItemListSkeleton(),
                        )
                      : data.filteredList.isEmpty
                          ? const Center(child: Text('조회된 인건비가 없습니다.'))
                          : Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.rsi(10),
                              ),
                              child: WorkCostGroupedListBody(
                                filteredList: data.filteredList,
                                listFilter: listFilter,
                                storageScope:
                                    '${listFilter.name}_${widget.uniqueHuman}',
                                scrollable: true,
                              ),
                            ),
                ),
              ),
              WorkCostPaymentFooter(uniqueHumanKey: widget.uniqueHuman),
            ],
          ),
        ),
      ),
    );
  }
}
