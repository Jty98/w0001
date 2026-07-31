import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_providers.dart';
import 'package:w0001/ui/screen/announcements/admin_worker_announcement_edit_screen.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_read_widgets.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/navigation/place_navigation.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 특정 현장의 **현장 공지만** (전체 공지는 제외).
///
/// 관리자: 이 화면에서 현장 공지 CRUD 가능.
class PlaceWorkerAnnouncementsScreen extends ConsumerStatefulWidget {
  const PlaceWorkerAnnouncementsScreen({super.key, required this.place});

  final PlaceInfoModel place;

  @override
  ConsumerState<PlaceWorkerAnnouncementsScreen> createState() =>
      _PlaceWorkerAnnouncementsScreenState();
}

class _PlaceWorkerAnnouncementsScreenState
    extends ConsumerState<PlaceWorkerAnnouncementsScreen> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  WorkerAnnouncementPagedQuery _pagedQuery(bool canManage, int pid) {
    final pcomplete = widget.place.pcomplete == 1 ? 1 : 0;
    return WorkerAnnouncementPagedQuery(
      source: canManage
          ? WorkerAnnouncementPagedSource.manage
          : WorkerAnnouncementPagedSource.inbox,
      placeId: pid,
      scopeFilter: WorkerAnnouncementPagedScopeFilter.placeOnly,
      placeComplete: pcomplete,
    );
  }

  void _onScroll() {
    final pid = widget.place.pid;
    if (pid == null) return;
    final canManage =
        ref.read(authSessionProvider).asData?.value?.isManagementRole ?? false;
    onPagedScrollNearEnd(
      _scroll,
      onLoadMore: () => ref
          .read(
            workerAnnouncementPagedListProvider(_pagedQuery(canManage, pid))
                .notifier,
          )
          .loadMore(),
    );
  }

  void _reloadPaged() {
    final pid = widget.place.pid;
    if (pid == null) return;
    final canManage =
        ref.read(authSessionProvider).asData?.value?.isManagementRole ?? false;
    unawaited(
      ref
          .read(
            workerAnnouncementPagedListProvider(_pagedQuery(canManage, pid))
                .notifier,
          )
          .reload(silent: false),
    );
  }

  List<WorkerAnnouncementRead> _sortedForDisplay(
    List<WorkerAnnouncementRead> items,
  ) {
    // 전체공지 제외 — 현장공지만 표시
    final placeOnly = items.where((a) => !a.isGlobal).toList();
    placeOnly.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return placeOnly;
  }

  Future<void> _confirmDelete(
      BuildContext context, WorkerAnnouncementRead a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('현장 공지 삭제'),
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
      _reloadPaged();
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
          const SnackBar(content: Text('고정을 해제했습니다.')),
        );
      } else {
        await ref.read(workerAnnouncementUseCaseProvider).pin(a.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상단에 고정했습니다.')),
        );
      }
      _reloadPaged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('고정 변경 실패: $e')),
        );
      }
    }
  }

  Future<void> _openEditNew(BuildContext context) async {
    final pid = widget.place.pid;
    if (pid == null) return;
    await context.push<dynamic>(
      '/dashboard/worker-announcements/edit',
      extra: AdminWorkerAnnouncementEditExtra(
        placeAnchor: PlaceAnnouncementEditAnchor(
          pid: pid,
          displayName: widget.place.pname,
        ),
      ),
    );
    if (mounted) _reloadPaged();
  }

  Future<void> _openEditExisting(
    BuildContext context,
    WorkerAnnouncementRead a,
  ) async {
    final pid = widget.place.pid;
    if (pid == null) return;
    await context.push<dynamic>(
      '/dashboard/worker-announcements/edit',
      extra: AdminWorkerAnnouncementEditExtra(
        existing: a,
        placeAnchor: PlaceAnnouncementEditAnchor(
          pid: pid,
          displayName: widget.place.pname,
        ),
      ),
    );
    if (mounted) _reloadPaged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pid = widget.place.pid;
    final canManage =
        ref.watch(authSessionProvider).asData?.value?.isManagementRole ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: placeSubrouteBackLeading(context),
        title: Text('${widget.place.pname} · 현장 공지'),
      ),
      floatingActionButton: pid != null && canManage
          ? FloatingActionButton.extended(
              heroTag: 'place_announcements_fab',
              onPressed: () => _openEditNew(context),
              icon: const Icon(Icons.edit_notifications_outlined),
              label: const Text('공지 작성'),
            )
          : null,
      body: pid == null
          ? const Center(child: Text('현장 식별자가 없습니다.'))
          : Builder(
              builder: (context) {
                final paged = ref.watch(
                  workerAnnouncementPagedListProvider(
                      _pagedQuery(canManage, pid)),
                );
                final sortedList = _sortedForDisplay(paged.items);
                final blocking = paged.initialLoading &&
                    paged.items.isEmpty &&
                    paged.error == null;

                if (blocking) {
                  return Skeletonizer(
                    enabled: true,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(16),
                        context.rsi(8),
                        context.rsi(16),
                        context.rsi(28),
                      ),
                      itemCount: 5,
                      itemBuilder: (ctx, i) => Padding(
                        padding: EdgeInsets.only(bottom: context.rsi(12)),
                        child: WorkerAnnouncementReadListCard(
                          item: WorkerAnnouncementRead(
                            id: i,
                            scope: WorkerAnnouncementScope.place,
                            pid: pid,
                            title: '현장 공지 ${i + 1}',
                            blocks: const [
                              WorkerAnnouncementTextBlock('미리보기'),
                            ],
                          ),
                          onTap: () {},
                        ),
                      ),
                    ),
                  );
                }

                if (paged.error != null && paged.items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(context.rsi(24)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            paged.error.toString(),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: context.rsi(16)),
                          FilledButton(
                            onPressed: _reloadPaged,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return AppRefreshIndicator(
                  onRefresh: () async => _reloadPaged(),
                  child: sortedList.isEmpty
                      ? CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(context.rsi(24)),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '이 현장에 등록된 공지가 없습니다.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                      if (canManage) ...[
                                        SizedBox(height: context.rsi(18)),
                                        FilledButton.icon(
                                          onPressed: () =>
                                              _openEditNew(context),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                          label: const Text('현장 공지 작성하기'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(
                            context.rsi(16),
                            context.rsi(8),
                            context.rsi(16),
                            context.rsi(canManage ? 88 : 28),
                          ),
                          itemCount: sortedList.length + 1,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: context.rsi(12)),
                          itemBuilder: (context, i) {
                            if (i >= sortedList.length) {
                              return PagedListFooter(
                                isLoading: paged.isLoadingMore,
                                hasMore: paged.hasMore,
                              );
                            }
                            final a = sortedList[i];
                            if (canManage) {
                              return WorkerAnnouncementReadListCard(
                                item: a,
                                trailing: PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  onSelected: (v) async {
                                    if (v == 'pin') {
                                      await _togglePin(context, a);
                                    } else if (v == 'edit') {
                                      await _openEditExisting(context, a);
                                    } else if (v == 'del') {
                                      await _confirmDelete(context, a);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'pin',
                                      child: Row(
                                        children: [
                                          Icon(
                                            a.isPinned
                                                ? Icons.push_pin
                                                : Icons.push_pin_outlined,
                                            size: 18,
                                            color: cs.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            a.isPinned ? '고정 해제' : '상단 고정',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('수정'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'del',
                                      child: Text('삭제'),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  if (canManage) {
                                    await _openEditExisting(context, a);
                                  } else {
                                    await context.push<dynamic>(
                                      '/announcements/view',
                                      extra: a,
                                    );
                                  }
                                  if (mounted) _reloadPaged();
                                },
                              );
                            }

                            return WorkerAnnouncementReadListCard(
                              item: a,
                              onTap: () => context.push(
                                '/announcements/view',
                                extra: a,
                              ),
                            );
                          },
                        ),
                );
              },
            ),
    );
  }
}
