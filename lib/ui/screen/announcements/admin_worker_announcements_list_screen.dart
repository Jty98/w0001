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
import 'package:w0001/ui/screen/announcements/worker_announcements_inbox_screen.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

class _AdminManageLoad {
  const _AdminManageLoad({
    required this.announcements,
    required this.placeNameByPid,
  });

  final List<WorkerAnnouncementRead> announcements;
  final Map<int, String> placeNameByPid;
}

/// 관리자: 공지 목록·삭제·편집 진입 (전체 / 현장 구분).
class AdminWorkerAnnouncementsListScreen extends ConsumerStatefulWidget {
  const AdminWorkerAnnouncementsListScreen({super.key});

  @override
  ConsumerState<AdminWorkerAnnouncementsListScreen> createState() =>
      _AdminWorkerAnnouncementsListScreenState();
}

class _AdminWorkerAnnouncementsListScreenState
    extends ConsumerState<AdminWorkerAnnouncementsListScreen> {
  Future<_AdminManageLoad>? _future;
  var _segment = WorkerAnnouncementInboxSegment.globalOnly;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<_AdminManageLoad> _load() async {
    final uc = ref.read(workerAnnouncementUseCaseProvider);
    final pair = await Future.wait([
      uc.manageList(),
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
    return _AdminManageLoad(
      announcements: announcements,
      placeNameByPid: byPid,
    );
  }

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
        setState(_reload);
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
      setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('최상단고정 변경 실패: $e')),
        );
      }
    }
  }

  Widget _announcementTile(
    BuildContext context,
    WorkerAnnouncementRead a, {
    String? placeNameOnCard,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        WorkerAnnouncementReadListCard(
          item: a,
          showEndChevron: false,
          showPreview: false,
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
                await context.push<dynamic>(
                  '/dashboard/worker-announcements/edit',
                  extra: a,
                );
                if (mounted) setState(_reload);
              } else if (v == 'del') {
                await _confirmDelete(a);
              }
            },
          ),
          onTap: () async {
            await context.push<dynamic>(
              '/dashboard/worker-announcements/edit',
              extra: a,
            );
            if (mounted) setState(_reload);
          },
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
  }

  List<Widget> _buildSectionedList(
    BuildContext context,
    List<WorkerAnnouncementListSection> sections,
    Map<int, String> placeNameByPid,
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
            icon: section.headerIcon ?? Icons.folder_outlined,
          ),
        );
      }
      for (var i = 0; i < section.items.length; i++) {
        final a = section.items[i];
        final showPlaceChip = section.headerTitle == null &&
            !a.isGlobal &&
            a.pid != null &&
            a.pid! > 0;
        final placeLabel = showPlaceChip
            ? (placeNameByPid[a.pid!] ?? '현장 #${a.pid}')
            : null;
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

    return Scaffold(
      appBar: AppBar(title: const Text('작업자 공지 관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push<dynamic>('/dashboard/worker-announcements/edit');
          if (mounted) setState(_reload);
        },
        icon: const Icon(Icons.edit_notifications_outlined),
        label: const Text('새 공지'),
      ),
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
                setState(() => _segment = next.first);
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(8),
              context.rsi(16),
              context.rsi(8),
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
            child: FutureBuilder<_AdminManageLoad>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Skeletonizer(
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
                          icon: Icons.apartment_rounded,
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
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(context.rsi(24)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(snap.error.toString(), textAlign: TextAlign.center),
                          SizedBox(height: context.rsi(16)),
                          FilledButton(
                            onPressed: () => setState(_reload),
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = snap.data;
                final announcements =
                    data?.announcements ?? const <WorkerAnnouncementRead>[];
                final placeNameByPid = data?.placeNameByPid ?? const <int, String>{};
                final sections = buildWorkerAnnouncementListSections(
                  announcements: announcements,
                  placeNameByPid: placeNameByPid,
                  segment: _segment,
                );

                return RefreshIndicator(
                  onRefresh: () async {
                    final f = _load();
                    setState(() => _future = f);
                    await f;
                  },
                  child: sections.isEmpty
                      ? CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(context.rsi(24)),
                                  child: Text(
                                    workerAnnouncementEmptyMessage(_segment),
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
                          padding: EdgeInsets.fromLTRB(
                            context.rsi(16),
                            context.rsi(4),
                            context.rsi(16),
                            context.rsi(100),
                          ),
                          children: _buildSectionedList(
                            context,
                            sections,
                            placeNameByPid,
                          ),
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
