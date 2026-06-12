import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/places_api.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_providers.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_inbox_layout.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_read_widgets.dart';
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
  Future<_InboxLoad>? _future;

  late WorkerAnnouncementInboxSegment _segment;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<_InboxLoad> _load() async {
    final uc = ref.read(workerAnnouncementUseCaseProvider);
    final pair = await Future.wait([
      uc.inbox(placeId: null),
      PlacesRemoteApi(AppHttpClient.I).listMine().catchError(
        (_) => const <PlaceRead>[],
      ),
    ]);
    final announcements = pair[0] as List<WorkerAnnouncementRead>;
    final places = pair[1] as List<PlaceRead>;
    final byPid = <int, String>{
      for (final p in places)
        if (p.pid > 0 && p.pname.trim().isNotEmpty) p.pid: p.pname.trim(),
    };
    return _InboxLoad(announcements: announcements, placeNameByPid: byPid);
  }

  String _emptyMessage(WorkerAnnouncementInboxSegment segment) {
    return workerAnnouncementEmptyMessage(segment);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('공지사항')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(12),
              context.rsi(16),
              context.rsi(4),
            ),
            child: SegmentedButton<WorkerAnnouncementInboxSegment>(
              showSelectedIcon: false,
              style: AppSegmentedButton.styleFrom(
                textStyle: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              segments: [
                ButtonSegment(
                  value: WorkerAnnouncementInboxSegment.globalOnly,
                  label: AppSegmentedButton.segmentLabel('전체공지'),
                  tooltip: '전체 공지',
                ),
                ButtonSegment(
                  value: WorkerAnnouncementInboxSegment.placeOnly,
                  label: AppSegmentedButton.segmentLabel('현장공지'),
                  tooltip: '현장 공지',
                ),
              ],
              selected: {_segment},
              onSelectionChanged: (next) {
                setState(() {
                  _segment = next.first;
                });
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(8),
              context.rsi(16),
              context.rsi(10),
            ),
            child: Material(
              color: cs.surfaceContainerLow.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(14),
                  vertical: context.rsi(11),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: cs.primary, size: context.rs(20)),
                    SizedBox(width: context.rsi(10)),
                    Expanded(
                      child: Text(
                        workerAnnouncementSegmentHint(_segment),
                        style: tt.bodySmall?.copyWith(
                          height: 1.4,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<_InboxLoad>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Skeletonizer(
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
                          showPreview: false,
                        ),
                      ),
                    ),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(context.rsi(24)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(snap.error.toString(),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(_reload),
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final raw = snap.data?.announcements ?? const <WorkerAnnouncementRead>[];
                final placeNameByPid = snap.data?.placeNameByPid ?? const <int, String>{};
                final filtered =
                    raw.where((a) => _segment.accepts(a)).toList(growable: false);
                
                final pinnedList = filtered.where((a) => a.isPinned).toList();
                final unpinnedList = filtered.where((a) => !a.isPinned).toList();
                final list = [...pinnedList, ...unpinnedList];
                
                return RefreshIndicator(
                  onRefresh: () async {
                    final f = _load();
                    setState(() => _future = f);
                    await f;
                  },
                  child: list.isEmpty
                      ? CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(context.rsi(24)),
                                  child: Text(
                                    _emptyMessage(_segment),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                            color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding:
                              EdgeInsets.fromLTRB(
                                context.rsi(16),
                                context.rsi(8),
                                context.rsi(16),
                                context.rsi(28),
                              ),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: context.rsi(12)),
                          itemBuilder: (context, i) {
                            final a = list[i];
                            final pid = a.pid;
                            final placeLabel = (!a.isGlobal &&
                                    pid != null &&
                                    pid > 0)
                                ? (placeNameByPid[pid] ?? '현장 #$pid')
                                : null;
                            return Stack(
                              children: [
                                WorkerAnnouncementReadListCard(
                                  item: a,
                                  onTap: () => context.push(
                                    '/announcements/view',
                                    extra: a,
                                  ),
                                  showPreview: false,
                                  placeName: placeLabel,
                                ),
                                if (a.isPinned)
                                  Positioned(
                                    right: context.rsi(12),
                                    bottom: context.rsi(10),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: context.rsi(6),
                                        vertical: context.rsi(2),
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.push_pin,
                                            size: context.rs(13),
                                            color: cs.onPrimaryContainer,
                                          ),
                                          SizedBox(width: context.rsi(3)),
                                          Text(
                                            '최상단고정',
                                            style: tt.labelSmall?.copyWith(
                                              color: cs.onPrimaryContainer,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxLoad {
  const _InboxLoad({
    required this.announcements,
    required this.placeNameByPid,
  });

  final List<WorkerAnnouncementRead> announcements;
  final Map<int, String> placeNameByPid;
}
