import 'package:flutter/material.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/ui/screen/announcements/worker_announcements_inbox_screen.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 공지 목록 한 구역(섹션 헤더 + 항목).
class WorkerAnnouncementListSection {
  const WorkerAnnouncementListSection({
    required this.items,
    this.headerTitle,
  });

  final String? headerTitle;
  final List<WorkerAnnouncementRead> items;
}

List<WorkerAnnouncementRead> sortWorkerAnnouncementsPinnedFirst(
  Iterable<WorkerAnnouncementRead> items,
) {
  final pinned = <WorkerAnnouncementRead>[];
  final rest = <WorkerAnnouncementRead>[];
  for (final a in items) {
    if (a.isPinned) {
      pinned.add(a);
    } else {
      rest.add(a);
    }
  }
  return [...pinned, ...rest];
}

String workerAnnouncementEmptyMessage(
  WorkerAnnouncementInboxSegment segment, {
  PlaceState placeState = PlaceState.incomplete,
}) {
  return switch (segment) {
    WorkerAnnouncementInboxSegment.globalOnly => '등록된 전체 공지가 없습니다.',
    WorkerAnnouncementInboxSegment.placeOnly =>
      placeState == PlaceState.complete
          ? '완료 현장 공지가 없습니다.'
          : '진행 중 현장 공지가 없습니다.',
  };
}

/// 수신함·관리 목록용 — 세그먼트에 따라 전체 / 현장별 섹션으로 나눈다.
List<WorkerAnnouncementListSection> buildWorkerAnnouncementListSections({
  required List<WorkerAnnouncementRead> announcements,
  required Map<int, String> placeNameByPid,
  required WorkerAnnouncementInboxSegment segment,
  bool groupByPlace = true,
}) {
  final filtered =
      announcements.where((a) => segment.accepts(a)).toList(growable: false);
  if (filtered.isEmpty) return const [];

  if (segment == WorkerAnnouncementInboxSegment.placeOnly && !groupByPlace) {
    return [
      WorkerAnnouncementListSection(
        items: sortWorkerAnnouncementsPinnedFirst(filtered),
      ),
    ];
  }

  final global = filtered.where((a) => a.isGlobal).toList(growable: false);
  final place = filtered.where((a) => !a.isGlobal).toList(growable: false);

  final out = <WorkerAnnouncementListSection>[];

  void addGlobalSection() {
    if (global.isEmpty) return;
    out.add(
      WorkerAnnouncementListSection(
        headerTitle: segment == WorkerAnnouncementInboxSegment.globalOnly
            ? null
            : '전체 공지',
        items: sortWorkerAnnouncementsPinnedFirst(global),
      ),
    );
  }

  void addPlaceSections() {
    if (place.isEmpty) return;
    final byPid = <int, List<WorkerAnnouncementRead>>{};
    for (final a in place) {
      final pid = a.pid;
      if (pid == null || pid <= 0) continue;
      byPid.putIfAbsent(pid, () => []).add(a);
    }
    final pids = byPid.keys.toList(growable: false)
      ..sort((a, b) {
        final na = placeNameByPid[a] ?? '현장 #$a';
        final nb = placeNameByPid[b] ?? '현장 #$b';
        return na.compareTo(nb);
      });
    for (final pid in pids) {
      final items = sortWorkerAnnouncementsPinnedFirst(byPid[pid]!);
      final name = placeNameByPid[pid]?.trim();
      out.add(
        WorkerAnnouncementListSection(
          headerTitle: name != null && name.isNotEmpty ? name : '현장 #$pid',
          items: items,
        ),
      );
    }
  }

  switch (segment) {
    case WorkerAnnouncementInboxSegment.globalOnly:
      addGlobalSection();
    case WorkerAnnouncementInboxSegment.placeOnly:
      addPlaceSections();
  }
  return out;
}

/// 섹션 헤더 (현장명·전체 공지 구분).
Widget workerAnnouncementSectionHeader(
  BuildContext context, {
  required String title,
  required int itemCount,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return Padding(
    padding: EdgeInsets.only(
      top: context.rsi(14),
      bottom: context.rsi(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: cs.onSurface,
            ),
          ),
        ),
        SizedBox(width: context.rsi(8)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(8),
            vertical: context.rsi(3),
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$itemCount건',
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
