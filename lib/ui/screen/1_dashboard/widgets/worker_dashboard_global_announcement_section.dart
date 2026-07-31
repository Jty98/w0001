import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_paged_list_notifier.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_read_widgets.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/worker_dashboard_section_shell.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 대시보드 — 전체 공지 컴팩트 미리보기 (고정 1 + 최신 순 최대 3건).
class WorkerDashboardGlobalAnnouncementSection extends ConsumerWidget {
  const WorkerDashboardGlobalAnnouncementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final paged = ref.watch(workerDashboardGlobalAnnouncementPreviewProvider);
    final allItems = paged.items;
    final displayItems = _previewItems(allItems);
    final totalGlobal = paged.totalCount ?? allItems.length;
    final loading = paged.initialLoading && allItems.isEmpty;

    if (loading) {
      return const SizedBox.shrink();
    }

    return WorkerDashboardSectionShell(
      icon: Icons.campaign_outlined,
      title: '전체 공지',
      subtitle: '회사 전체 공지사항',
      trailing: TextButton(
        onPressed: () => context.push('/announcements/inbox?filter=global'),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(6),
            vertical: context.rsi(2),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          '전체보기',
          style: tt.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: paged.error != null && allItems.isEmpty
          ? Text(
              '공지를 불러오지 못했습니다.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            )
          : displayItems.isEmpty
              ? Text(
                  '등록된 전체 공지가 없습니다.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (var i = 0; i < displayItems.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.35),
                        ),
                      _CompactAnnouncementRow(
                        item: displayItems[i],
                        onTap: () => _openView(context, ref, displayItems[i]),
                      ),
                    ],
                    if (totalGlobal > displayItems.length)
                      Padding(
                        padding: EdgeInsets.only(top: context.rsi(4)),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context
                                .push('/announcements/inbox?filter=global'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              '${totalGlobal - displayItems.length}개 더',
                              style: tt.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  List<WorkerAnnouncementRead> _previewItems(List<WorkerAnnouncementRead> all) {
    final pinned = all.where((a) => a.isPinned).toList();
    final unpinned = all.where((a) => !a.isPinned).toList();
    final out = <WorkerAnnouncementRead>[];
    if (pinned.isNotEmpty) {
      out.add(pinned.first);
      out.addAll(unpinned.take(2));
    } else {
      out.addAll(unpinned.take(3));
    }
    return out;
  }

  Future<void> _openView(
    BuildContext context,
    WidgetRef ref,
    WorkerAnnouncementRead item,
  ) async {
    await context.push<dynamic>('/announcements/view', extra: item);
    if (!context.mounted) return;
    await ref
        .read(workerDashboardGlobalAnnouncementPreviewProvider.notifier)
        .reload(silent: true);
  }
}

class _CompactAnnouncementRow extends StatelessWidget {
  const _CompactAnnouncementRow({
    required this.item,
    required this.onTap,
  });

  final WorkerAnnouncementRead item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = item.title.trim().isEmpty ? '(제목 없음)' : item.title.trim();
    final preview = WorkerAnnouncementQuillCodec.blocksPlainTextPreview(
      item.blocks,
      maxLen: 52,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.rsi(6)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (item.isPinned) ...[
                        const WorkerAnnouncementPinnedIcon(),
                        SizedBox(width: context.rsi(4)),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (preview.isNotEmpty) ...[
                    SizedBox(height: context.rsi(2)),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding:
                  EdgeInsets.only(left: context.rsi(4), top: context.rsi(1)),
              child: Icon(
                Icons.chevron_right_rounded,
                size: context.rs(18),
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
