import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_providers.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_read_widgets.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 상황판: 작업자 **전체 공지**만 요약 목록 · CRUD 연결.
class DashboardGlobalAnnouncementCard extends ConsumerStatefulWidget {
  const DashboardGlobalAnnouncementCard({super.key, this.embedded = false});

  /// [ManagementDashboardSectionShell] 안에서는 헤더·외곽 카드 생략.
  final bool embedded;

  @override
  ConsumerState<DashboardGlobalAnnouncementCard> createState() =>
      DashboardGlobalAnnouncementCardState();
}

class DashboardGlobalAnnouncementCardState
    extends ConsumerState<DashboardGlobalAnnouncementCard> {
  static const _dashboardPagedQuery = WorkerAnnouncementPagedQuery(
    source: WorkerAnnouncementPagedSource.manage,
    scopeFilter: WorkerAnnouncementPagedScopeFilter.globalOnly,
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref
        .read(
            workerAnnouncementPagedListProvider(_dashboardPagedQuery).notifier)
        .reload(silent: false));
  }

  Future<void> reloadPublic() => ref
      .read(workerAnnouncementPagedListProvider(_dashboardPagedQuery).notifier)
      .reload(silent: false);

  void _refreshFromCache() => unawaited(reloadPublic());

  Future<void> _confirmDelete(
      BuildContext context, WorkerAnnouncementRead a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 공지 삭제'),
        content: Text('「${a.title.isEmpty ? '(제목 없음)' : a.title}」을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(workerAnnouncementUseCaseProvider).delete(a.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제했습니다.')),
      );
      _refreshFromCache();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _togglePin(
      BuildContext context, WorkerAnnouncementRead a) async {
    try {
      if (a.isPinned) {
        await ref.read(workerAnnouncementUseCaseProvider).unpin(a.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최상단고정을 해제했습니다.')),
        );
      } else {
        await ref.read(workerAnnouncementUseCaseProvider).pin(a.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공지를 최상단고정했습니다.')),
        );
      }
      await reloadPublic();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('최상단고정 변경 실패: $e')),
        );
      }
    }
  }

  Future<void> _openEdit(
    BuildContext context,
    WorkerAnnouncementRead? existing,
  ) async {
    final changed = await context.push<bool>(
      '/dashboard/worker-announcements/edit',
      extra: existing,
    );
    if (mounted && changed == true) _refreshFromCache();
  }

  /// 섹션 헤더 [+] 버튼 등 외부에서 새 공지 작성 화면을 연다.
  void openCreate() {
    if (!mounted) return;
    unawaited(_openEdit(context, null));
  }

  Future<void> _openView(BuildContext context, WorkerAnnouncementRead a) async {
    await context.push<dynamic>(
      '/announcements/view',
      extra: a,
    );
  }

  Widget _announcementTile(BuildContext context, WorkerAnnouncementRead a) {
    final cs = Theme.of(context).colorScheme;

    return WorkerAnnouncementReadListCard(
      item: a,
      previewMaxLen: 64,
      trailing: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert_rounded,
          color: cs.onSurfaceVariant,
        ),
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'view', child: Text('미리보기')),
          PopupMenuItem(
            value: 'pin',
            child: Text(a.isPinned ? '최상단고정 해제' : '최상단고정'),
          ),
          const PopupMenuItem(value: 'edit', child: Text('수정')),
          const PopupMenuItem(value: 'del', child: Text('삭제')),
        ],
        onSelected: (v) async {
          if (v == 'view') {
            await _openView(context, a);
          } else if (v == 'pin') {
            await _togglePin(context, a);
          } else if (v == 'edit') {
            await _openEdit(context, a);
          } else if (v == 'del') {
            await _confirmDelete(context, a);
          }
        },
      ),
      onTap: () => _openEdit(context, a),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final paged =
        ref.watch(workerAnnouncementPagedListProvider(_dashboardPagedQuery));
    final allItems =
        paged.items.where((a) => a.isGlobal).toList(growable: false);
    final loading =
        paged.initialLoading && paged.items.isEmpty && paged.error == null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: context.rsi(18),
                color: cs.onSurfaceVariant,
              ),
              rsH(context, 8),
              Expanded(
                child: Text(
                  '작업자 전체 공지',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              IconButton(
                tooltip: '새 공지',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.add_circle_outline,
                  size: context.rsi(20),
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () => _openEdit(context, null),
              ),
            ],
          ),
          rsV(context, 4),
          Text(
            '가입 작업자 전원에게 보이는 공지입니다.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          rsV(context, 10),
        ],
        if (paged.error != null && allItems.isEmpty)
          Padding(
            padding: ResponsiveLayout.symmetric(context, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    paged.error.toString(),
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
                TextButton(
                  onPressed: () => reloadPublic(),
                  child: const Text('다시'),
                ),
              ],
            ),
          )
        else if (loading)
          Skeletonizer(
            enabled: true,
            child: Padding(
              padding: ResponsiveLayout.symmetric(context, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) SizedBox(height: context.rsi(8)),
                    WorkerAnnouncementReadListCard(
                      item: WorkerAnnouncementRead(
                        id: i,
                        scope: WorkerAnnouncementScope.global,
                        title: '공지 제목 ${i + 1}',
                        blocks: const [
                          WorkerAnnouncementTextBlock('본문 미리보기'),
                        ],
                        createdAt: DateTime.now(),
                      ),
                      onTap: () {},
                    ),
                  ],
                ],
              ),
            ),
          )
        else if (allItems.isEmpty)
          Padding(
            padding: ResponsiveLayout.only(context, top: 6, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '등록된 전체 공지가 없습니다.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                rsV(context, 10),
                OutlinedButton.icon(
                  onPressed: () => _openEdit(context, null),
                  icon: const Icon(Icons.edit_notifications_outlined),
                  label: const Text('전체 공지 작성'),
                ),
              ],
            ),
          )
        else
          Builder(
            builder: (context) {
              final pinnedItems = allItems.where((a) => a.isPinned).toList();
              final unpinnedItems = allItems.where((a) => !a.isPinned).toList();

              final displayItems = <WorkerAnnouncementRead>[];
              if (pinnedItems.isNotEmpty) {
                displayItems.add(pinnedItems.first);
                displayItems.addAll(unpinnedItems.take(2));
              } else {
                displayItems.addAll(unpinnedItems.take(3));
              }

              final totalGlobal = paged.totalCount ?? allItems.length;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < displayItems.length; i++) ...[
                    if (i > 0) SizedBox(height: context.rsi(8)),
                    _announcementTile(context, displayItems[i]),
                  ],
                  if (totalGlobal > displayItems.length)
                    Padding(
                      padding: EdgeInsets.only(top: context.rs(8)),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            await context.push<dynamic>(
                              '/dashboard/worker-announcements',
                            );
                            if (mounted) _refreshFromCache();
                          },
                          style: TextButton.styleFrom(
                            padding: ResponsiveLayout.symmetric(
                              context,
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '전체보기 (${totalGlobal - displayItems.length}개 더)',
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              rsH(context, 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: context.rsi(16),
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );

    if (widget.embedded) return body;

    return Material(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(14)),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: ResponsiveLayout.only(
          context,
          left: 14,
          top: 12,
          right: 10,
          bottom: 12,
        ),
        child: body,
      ),
    );
  }
}
