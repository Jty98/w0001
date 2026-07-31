import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_inbox_layout.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_list_filters.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_read_widgets.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 수신함·관리 목록 세그먼트 (`/announcements/inbox?filter=global|place`).
enum WorkerAnnouncementInboxSegment {
  globalOnly,
  placeOnly;

  bool accepts(WorkerAnnouncementRead a) {
    return switch (this) {
      WorkerAnnouncementInboxSegment.globalOnly => a.isGlobal,
      WorkerAnnouncementInboxSegment.placeOnly => !a.isGlobal,
    };
  }

  /// `place`·`site` → 현장공지, 그 외(없음·`global`·`all` 등) → 전체공지.
  static WorkerAnnouncementInboxSegment fromRouteQuery(String? filter) {
    switch (filter) {
      case 'place':
      case 'site':
        return WorkerAnnouncementInboxSegment.placeOnly;
      default:
        return WorkerAnnouncementInboxSegment.globalOnly;
    }
  }
}

/// 전체 공지 + 내가 접근 가능한 현장 공지 수신함.
class WorkerAnnouncementsInboxScreen extends ConsumerStatefulWidget {
  const WorkerAnnouncementsInboxScreen({
    super.key,
    this.initialSegment = WorkerAnnouncementInboxSegment.globalOnly,
  });

  /// [WorkerAnnouncementInboxSegment.fromRouteQuery] 로 넘기면 됩니다.
  final WorkerAnnouncementInboxSegment initialSegment;

  @override
  ConsumerState<WorkerAnnouncementsInboxScreen> createState() =>
      _WorkerAnnouncementsInboxScreenState();
}

class _WorkerAnnouncementsInboxScreenState
    extends ConsumerState<WorkerAnnouncementsInboxScreen> {
  late final ScrollController _scroll;
  late WorkerAnnouncementInboxSegment _segment;
  var _placeState = PlaceState.incomplete;
  int? _filterPlaceId;
  String? _filterPlaceName;
  final _placeNames = WorkerAnnouncementPlaceNameResolver();

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    _scroll = ScrollController()..addListener(_onScroll);
  }

  WorkerAnnouncementPagedQuery get _pagedQuery => WorkerAnnouncementPagedQuery(
        source: WorkerAnnouncementPagedSource.inbox,
        placeId: _segment == WorkerAnnouncementInboxSegment.placeOnly
            ? _filterPlaceId
            : null,
        scopeFilter: scopeFilterForSegment(
          _segment,
          source: WorkerAnnouncementPagedSource.inbox,
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

  Future<void> _reloadPaged() => ref
      .read(workerAnnouncementPagedListProvider(_pagedQuery).notifier)
      .reload(silent: false);

  String _emptyMessage(WorkerAnnouncementInboxSegment segment) {
    return workerAnnouncementEmptyMessage(segment, placeState: _placeState);
  }

  List<Widget> _buildSectionedList(
    BuildContext context,
    List<WorkerAnnouncementListSection> sections,
  ) {
    final children = <Widget>[];
    for (final section in sections) {
      if (section.headerTitle != null) {
        children.add(
          workerAnnouncementSectionHeader(
            context,
            title: section.headerTitle!,
            itemCount: section.items.length,
          ),
        );
      }
      for (final a in section.items) {
        final showPlaceChip = section.headerTitle == null &&
            !a.isGlobal &&
            a.pid != null &&
            a.pid! > 0;
        final placeLabel = showPlaceChip
            ? ((a.placeName?.trim().isNotEmpty ?? false)
                ? a.placeName!.trim()
                : _placeNames.labelFor(a.pid!))
            : null;
        if (children.isNotEmpty) {
          children.add(SizedBox(height: context.rsi(12)));
        }
        children.add(
          WorkerAnnouncementReadListCard(
            item: a,
            onTap: () => context.push('/announcements/view', extra: a),
            previewMaxLen: 64,
            placeName: placeLabel,
          ),
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
    final effectivePlaceNames = <int, String>{..._placeNames.names};
    for (final a in announcements) {
      final pid = a.pid;
      final pname = a.placeName?.trim() ?? '';
      if (pid != null && pid > 0 && pname.isNotEmpty) {
        effectivePlaceNames[pid] = pname;
      }
    }
    final sections = buildWorkerAnnouncementListSections(
      announcements: announcements,
      placeNameByPid: effectivePlaceNames,
      segment: _segment,
      groupByPlace: _filterPlaceId == null,
    );
    final blocking =
        paged.initialLoading && paged.items.isEmpty && paged.error == null;

    return Scaffold(
      appBar: AppBar(title: const Text('공지사항')),
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
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(16),
                        context.rsi(8),
                        context.rsi(16),
                        context.rsi(28),
                      ),
                      itemCount: 6,
                      itemBuilder: (ctx, i) => Padding(
                        padding: EdgeInsets.only(bottom: context.rsi(12)),
                        child: WorkerAnnouncementReadListCard(
                          item: WorkerAnnouncementRead(
                            id: i,
                            scope: WorkerAnnouncementScope.global,
                            title: '공지 제목 ${i + 1}',
                            blocks: const [
                              WorkerAnnouncementTextBlock('본문 미리보기'),
                            ],
                          ),
                          onTap: () {},
                          previewMaxLen: 64,
                        ),
                      ),
                    ),
                  )
                : paged.error != null && paged.items.isEmpty
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
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () => _reloadPaged(),
                                child: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : AppRefreshIndicator(
                        onRefresh: _reloadPaged,
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
                                          _emptyMessage(_segment),
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
                                  context.rsi(8),
                                  context.rsi(16),
                                  context.rsi(28),
                                ),
                                children: [
                                  ..._buildSectionedList(context, sections),
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
