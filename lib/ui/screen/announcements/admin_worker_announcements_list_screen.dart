import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_providers.dart';
import 'package:w0001/ui/screen/announcements/admin_worker_announcement_edit_screen.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_inbox_layout.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_list_filters.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_read_widgets.dart';
import 'package:w0001/ui/screen/announcements/worker_announcements_inbox_screen.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 관리자: 공지 목록·삭제·편집 진입 (전체 / 현장 구분).
class AdminWorkerAnnouncementsListScreen extends ConsumerStatefulWidget {
  const AdminWorkerAnnouncementsListScreen({super.key});

  @override
  ConsumerState<AdminWorkerAnnouncementsListScreen> createState() =>
      _AdminWorkerAnnouncementsListScreenState();
}

class _AdminWorkerAnnouncementsListScreenState
    extends ConsumerState<AdminWorkerAnnouncementsListScreen> {
  late final ScrollController _scroll;
  var _segment = WorkerAnnouncementInboxSegment.globalOnly;
  var _placeState = PlaceState.incomplete;
  int? _filterPlaceId;
  String? _filterPlaceName;
  final _placeNames = WorkerAnnouncementPlaceNameResolver();

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
  }

  WorkerAnnouncementPagedQuery get _pagedQuery => WorkerAnnouncementPagedQuery(
        source: WorkerAnnouncementPagedSource.manage,
        placeId: _segment == WorkerAnnouncementInboxSegment.placeOnly
            ? _filterPlaceId
            : null,
        scopeFilter: scopeFilterForSegment(
          _segment,
          source: WorkerAnnouncementPagedSource.manage,
          placeId: _filterPlaceId,
        ),
        placeComplete: placeCompleteForPagedQuery(
          segment: _segment,
          placeState: _placeState,
          placeId: _filterPlaceId,
        ),
      );

  Future<void> _syncPlaceNames(List<WorkerAnnouncementRead> items) async {
    await _placeNames.ensureForAnnouncements(items);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    onPagedScrollNearEnd(
      _scroll,
      onLoadMore: () => ref
          .read(workerAnnouncementPagedListProvider(_pagedQuery).notifier)
          .loadMore(),
    );
  }

  Future<void> _reloadPaged({bool silent = false}) => ref
      .read(workerAnnouncementPagedListProvider(_pagedQuery).notifier)
      .reload(silent: silent);

  void _refreshFromCache() => unawaited(_reloadPaged(silent: true));

  Future<void> _confirmDelete(WorkerAnnouncementRead a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지 삭제'),
        content: Text('「${a.title.isEmpty ? '(제목 없음)' : a.title}」을(를) 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ref.read(workerAnnouncementUseCaseProvider).delete(a.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제했습니다.')),
        );
        _refreshFromCache();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _togglePin(WorkerAnnouncementRead a) async {
    try {
      if (a.isPinned) {
        await ref.read(workerAnnouncementUseCaseProvider).unpin(a.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최상단고정을 해제했습니다.')),
          );
        }
      } else {
        await ref.read(workerAnnouncementUseCaseProvider).pin(a.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('공지를 최상단고정했습니다.')),
          );
        }
      }
      _reloadPaged(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('최상단고정 변경 실패: $e')),
        );
      }
    }
  }

  AdminWorkerAnnouncementEditExtra _editExtra(WorkerAnnouncementRead a) {
    if (a.isGlobal) return AdminWorkerAnnouncementEditExtra(existing: a);
    final pid = a.pid;
    if (pid == null || pid <= 0) {
      return AdminWorkerAnnouncementEditExtra(existing: a);
    }
    return AdminWorkerAnnouncementEditExtra(
      existing: a,
      placeAnchor: PlaceAnnouncementEditAnchor(
        pid: pid,
        displayName: _placeNames.labelFor(pid),
      ),
    );
  }

  Widget _announcementTile(
    BuildContext context,
    WorkerAnnouncementRead a, {
    String? placeNameOnCard,
  }) {
    final cs = Theme.of(context).colorScheme;

    return WorkerAnnouncementReadListCard(
      item: a,
      previewMaxLen: 64,
      placeName: placeNameOnCard,
      trailing: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert_rounded,
          color: cs.onSurfaceVariant,
        ),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'pin',
            child: Text(a.isPinned ? '최상단고정 해제' : '최상단고정'),
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
        onSelected: (v) async {
          if (v == 'pin') {
            await _togglePin(a);
          } else if (v == 'edit') {
            final changed = await context.push<bool>(
              '/dashboard/worker-announcements/edit',
              extra: _editExtra(a),
            );
            if (mounted && changed == true) _refreshFromCache();
          } else if (v == 'del') {
            await _confirmDelete(a);
          }
        },
      ),
      onTap: () async {
        final changed = await context.push<bool>(
          '/dashboard/worker-announcements/edit',
          extra: _editExtra(a),
        );
        if (mounted && changed == true) _refreshFromCache();
      },
    );
  }

  List<Widget> _buildSectionedList(
    BuildContext context,
    List<WorkerAnnouncementListSection> sections,
  ) {
    final children = <Widget>[];
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      if (section.headerTitle != null) {
        children.add(
          workerAnnouncementSectionHeader(
            context,
            title: section.headerTitle!,
            itemCount: section.items.length,
          ),
        );
      }
      for (var i = 0; i < section.items.length; i++) {
        final a = section.items[i];
        final showPlaceChip = section.headerTitle == null &&
            !a.isGlobal &&
            a.pid != null &&
            a.pid! > 0;
        final placeLabel =
            showPlaceChip ? (_placeNames.labelFor(a.pid!)) : null;
        if (children.isNotEmpty) {
          children.add(SizedBox(height: context.rsi(12)));
        }
        children.add(
          _announcementTile(context, a, placeNameOnCard: placeLabel),
        );
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final paged = ref.watch(workerAnnouncementPagedListProvider(_pagedQuery));
    if (paged.items.isNotEmpty) {
      unawaited(_syncPlaceNames(paged.items));
    }
    final announcements = filterAnnouncementsForPlaceTab(
      items: paged.items,
      segment: _segment,
      placeState: _placeState,
      resolver: _placeNames,
    );
    final sections = buildWorkerAnnouncementListSections(
      announcements: announcements,
      placeNameByPid: _placeNames.names,
      segment: _segment,
      groupByPlace: _filterPlaceId == null,
    );
    final blocking =
        paged.initialLoading && paged.items.isEmpty && paged.error == null;

    return Scaffold(
      appBar: AppBar(title: const Text('작업자 공지 관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await context.push<bool>(
            '/dashboard/worker-announcements/edit',
          );
          if (mounted && changed == true) _refreshFromCache();
        },
        icon: const Icon(Icons.edit_notifications_outlined),
        label: const Text('새 공지'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkerAnnouncementInboxScopeSegment(
            value: _segment,
            onChanged: (next) {
              setState(() {
                _segment = next;
                if (_segment == WorkerAnnouncementInboxSegment.globalOnly) {
                  _filterPlaceId = null;
                  _filterPlaceName = null;
                }
              });
            },
          ),
          if (_segment == WorkerAnnouncementInboxSegment.placeOnly) ...[
            WorkerAnnouncementPlaceCompleteSegment(
              value: _placeState,
              onChanged: (next) {
                setState(() {
                  _placeState = next;
                  _filterPlaceId = null;
                  _filterPlaceName = null;
                });
              },
            ),
            WorkerAnnouncementPlaceSearchBar(
              selectedPlaceId: _filterPlaceId,
              selectedPlaceName: _filterPlaceName,
              placeState: _placeState,
              onChanged: (placeId, placeName, placePcomplete) {
                setState(() {
                  _filterPlaceId = placeId;
                  _filterPlaceName = placeName;
                  if (placeId != null && placeName != null) {
                    _placeNames.remember(
                      placeId,
                      placeName,
                      pcomplete: placePcomplete,
                    );
                  }
                });
              },
            ),
          ],
          Expanded(
            child: blocking
                ? Skeletonizer(
                    enabled: true,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(16),
                        context.rsi(8),
                        context.rsi(16),
                        context.rsi(28),
                      ),
                      children: [
                        workerAnnouncementSectionHeader(
                          context,
                          title: '○○ 현장',
                          itemCount: 2,
                        ),
                        SizedBox(height: context.rsi(12)),
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) SizedBox(height: context.rsi(12)),
                          WorkerAnnouncementReadListCard(
                            item: WorkerAnnouncementRead(
                              id: i,
                              scope: i == 0
                                  ? WorkerAnnouncementScope.global
                                  : WorkerAnnouncementScope.place,
                              pid: i == 0 ? null : 1,
                              title: '공지 제목 ${i + 1}',
                              blocks: const [
                                WorkerAnnouncementTextBlock('본문'),
                              ],
                            ),
                            onTap: () {},
                            showPreview: false,
                          ),
                        ],
                      ],
                    ),
                  )
                : paged.error != null && announcements.isEmpty
                    ? Center(
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
                                onPressed: () => _reloadPaged(),
                                child: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : AppRefreshIndicator(
                        onRefresh: () => _reloadPaged(),
                        child: sections.isEmpty
                            ? CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: Padding(
                                        padding:
                                            EdgeInsets.all(context.rsi(24)),
                                        child: Text(
                                          workerAnnouncementEmptyMessage(
                                            _segment,
                                            placeState: _placeState,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: tt.bodyLarge?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                controller: _scroll,
                                padding: EdgeInsets.fromLTRB(
                                  context.rsi(16),
                                  context.rsi(4),
                                  context.rsi(16),
                                  context.rsi(100),
                                ),
                                children: [
                                  ..._buildSectionedList(
                                    context,
                                    sections,
                                  ),
                                  PagedListFooter(
                                    isLoading: paged.isLoadingMore,
                                    hasMore: paged.hasMore,
                                  ),
                                ],
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
