import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_sheet.dart'
    show WorkerGroupedListSheetBody;
import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_utils.dart';
import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_person_tile.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/human_work_assignability.dart';

export 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_utils.dart'
    show initialIndexKeyForName, kKoreanInitialIndex;

/// 금액추가·인력투입(작업지시) 공통 — 초성/역할 필터 바텀시트.
Future<void> showPlaceRecentWorkersGroupedSheet({
  required BuildContext context,
  required List<HumanModel> initialWorkers,
  required Future<void> Function(HumanModel human) onWorkerTap,
  Future<void> Function(HumanModel human)? onRemoveFromList,
  VoidCallback? onWorkersListChanged,
  bool closeSheetOnWorkerTap = true,
}) async {
  if (initialWorkers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이 현장에 기록된 인원이 없습니다.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return _PlaceRecentWorkersGroupedLauncher(
            sheetContext: sheetCtx,
            parentContext: context,
            initialWorkers: initialWorkers,
            scrollController: scrollController,
            onWorkerTap: onWorkerTap,
            onRemoveFromList: onRemoveFromList,
            onWorkersListChanged: onWorkersListChanged,
            closeSheetOnWorkerTap: closeSheetOnWorkerTap,
          );
        },
      );
    },
  );
}

/// 금액추가 탭 — [addCostProvider] 목록을 구독해 갱신합니다.
Future<void> showPlaceRecentWorkersSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final vm = ref.read(addCostProvider.notifier);
  var blocked = const <String>{};
  try {
    blocked = await ref.read(nonAssignableMemberUidsProvider.future);
  } catch (_) {}
  final initial = filterAssignableHumans(
    ref.read(addCostProvider).placeRecentWorkers,
    blockedMemberUids: blocked,
  );
  if (initial.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이 현장에 기록된 인원이 없습니다.')),
    );
    return;
  }

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return Consumer(
            builder: (ctx, ref, _) {
              final state = ref.watch(addCostProvider);
              final blocked =
                  ref.watch(nonAssignableMemberUidsProvider).asData?.value ??
                      const <String>{};
              final all = filterAssignableHumans(
                state.placeRecentWorkers,
                blockedMemberUids: blocked,
              );
              final loading = state.placeRecentWorkersLoading;

              return _PlaceRecentWorkersGroupedLauncher(
                sheetContext: sheetCtx,
                parentContext: context,
                initialWorkers: all,
                isLoading: loading,
                scrollController: scrollController,
                onWorkerTap: (h) async {
                  if (!humanCanBeAssignedToWork(
                    h,
                    blockedMemberUids: blocked,
                  )) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            humanWorkAssignBlockMessage(
                              h,
                              blockedMemberUids: blocked,
                            ),
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  await vm.tapPlaceRecentWorker(context, h);
                },
                onRemoveFromList: (h) async {
                  final hid = h.hid;
                  if (hid == null) return;
                  await vm.deletePlaceRecentWorker(hid);
                },
                closeSheetOnWorkerTap: true,
              );
            },
          );
        },
      );
    },
  );
}

class _PlaceRecentWorkersGroupedLauncher extends StatefulWidget {
  const _PlaceRecentWorkersGroupedLauncher({
    required this.sheetContext,
    required this.parentContext,
    required this.initialWorkers,
    required this.scrollController,
    required this.onWorkerTap,
    this.isLoading = false,
    this.onRemoveFromList,
    this.onWorkersListChanged,
    this.closeSheetOnWorkerTap = true,
  });

  final BuildContext sheetContext;
  final BuildContext parentContext;
  final List<HumanModel> initialWorkers;
  final bool isLoading;
  final ScrollController scrollController;
  final Future<void> Function(HumanModel human) onWorkerTap;
  final Future<void> Function(HumanModel human)? onRemoveFromList;
  final VoidCallback? onWorkersListChanged;
  final bool closeSheetOnWorkerTap;

  @override
  State<_PlaceRecentWorkersGroupedLauncher> createState() =>
      _PlaceRecentWorkersGroupedLauncherState();
}

class _PlaceRecentWorkersGroupedLauncherState
    extends State<_PlaceRecentWorkersGroupedLauncher> {
  late List<HumanModel> _workers;

  @override
  void initState() {
    super.initState();
    _workers = List<HumanModel>.from(widget.initialWorkers);
  }

  @override
  void didUpdateWidget(covariant _PlaceRecentWorkersGroupedLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWorkers != widget.initialWorkers) {
      _workers = List<HumanModel>.from(widget.initialWorkers);
    }
  }

  Future<void> _handleRemove(HumanModel h) async {
    final remove = widget.onRemoveFromList;
    if (remove == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('목록에서 제거'),
        content: Text('${h.hname} 님을 이 현장 목록에서 제거할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(
              '제거',
              style: TextStyle(color: Theme.of(dctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await remove(h);
    if (!mounted) return;
    setState(() {
      _workers.removeWhere((x) => x.hid == h.hid);
    });
    widget.onWorkersListChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중이고 아직 데이터가 없는 경우
    if (widget.isLoading && _workers.isEmpty) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLoadingIndicator(size: 70),
              const SizedBox(height: 10),
              Text(
                '작업자 목록을 불러오는 중...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    if (_workers.isEmpty) {
      return SafeArea(
        child: Center(
          child: Text(
            '이 현장에 기록된 인원이 없습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: WorkerGroupedListSheetBody(
            title:
                '이 현장에서 일했던 인원 (${_workers.length}${widget.isLoading ? '+' : ''})',
            workers: _workers,
            scrollController: widget.scrollController,
            onWorkerTap: (h) async {
              await widget.onWorkerTap(h);
              if (widget.closeSheetOnWorkerTap && widget.sheetContext.mounted) {
                Navigator.of(widget.sheetContext).pop();
              }
            },
            personTileBuilder: (tileCtx, h) => _PlaceRecentWorkerTile(
              human: h,
              onAdd: () async {
                await widget.onWorkerTap(h);
                if (widget.closeSheetOnWorkerTap &&
                    widget.sheetContext.mounted) {
                  Navigator.of(widget.sheetContext).pop();
                }
              },
              onRemoveFromList: widget.onRemoveFromList == null
                  ? null
                  : () => _handleRemove(h),
            ),
          ),
        ),
        // 추가 로딩 인디케이터 (배치 로딩 중)
        if (widget.isLoading && _workers.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const HammerLoadingIndicator(size: 32),
                const SizedBox(width: 12),
                Text(
                  '추가 목록 불러오는 중...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlaceRecentWorkerTile extends StatelessWidget {
  const _PlaceRecentWorkerTile({
    required this.human,
    required this.onAdd,
    this.onRemoveFromList,
  });

  final HumanModel human;
  final VoidCallback onAdd;
  final Future<void> Function()? onRemoveFromList;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final role = human.hdefaultRole.trim();
    return WorkerGroupedPersonTile(
      name: human.hname,
      subtitle: formatWorkerGroupedPersonSubtitle(
        wageLabel: '일당 ${getPrice(price: human.hdailyWage)}',
        role: role,
      ),
      onTap: onAdd,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_circle_outline, color: cs.primary),
          if (onRemoveFromList != null) ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              tooltip: '더보기',
              padding: EdgeInsets.zero,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'remove',
                  child: Text('이 목록에서 제거'),
                ),
              ],
              onSelected: (v) async {
                if (v == 'remove') await onRemoveFromList!();
              },
            ),
          ],
        ],
      ),
    );
  }
}
