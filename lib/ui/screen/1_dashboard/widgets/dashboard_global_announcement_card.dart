import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/worker_announcement_providers.dart';

/// 상황판: 작업자 **전체 공지**만 요약 목록 · CRUD 연결 (`manageList` 후 `scope === global`).
class DashboardGlobalAnnouncementCard extends ConsumerStatefulWidget {
  const DashboardGlobalAnnouncementCard({super.key});

  @override
  ConsumerState<DashboardGlobalAnnouncementCard> createState() =>
      DashboardGlobalAnnouncementCardState();
}

class DashboardGlobalAnnouncementCardState
    extends ConsumerState<DashboardGlobalAnnouncementCard> {
  Future<List<WorkerAnnouncementRead>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> reloadPublic() => _reload();

  Future<void> _reload() {
    final fut = ref
        .read(workerAnnouncementUseCaseProvider)
        .manageList()
        .then(
          (list) =>
              list.where((a) => a.isGlobal).toList(growable: false),
        );
    setState(() {
      _future = fut;
    });
    return fut;
  }

  Future<void> _confirmDelete(BuildContext context, WorkerAnnouncementRead a) async {
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
      await _reload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _togglePin(BuildContext context, WorkerAnnouncementRead a) async {
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
      await _reload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('최상단고정 변경 실패: $e')),
        );
      }
    }
  }

  Future<void> _openEdit(BuildContext context, WorkerAnnouncementRead? existing) async {
    await context.push<dynamic>(
      '/dashboard/worker-announcements/edit',
      extra: existing,
    );
    if (mounted) await _reload();
  }

  Future<void> _openView(BuildContext context, WorkerAnnouncementRead a) async {
    await context.push<dynamic>(
      '/announcements/view',
      extra: a,
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(16)),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: ResponsiveLayout.only(
          context,
          left: 14,
          top: 12,
          right: 8,
          bottom: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_outlined,
                    size: context.rsi(22), color: cs.primary),
                rsH(context, 10),
                Expanded(
                  child: Text(
                    '작업자 전체 공지',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.25,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '새 공지',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.add_circle_outline, color: cs.primary),
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
            FutureBuilder<List<WorkerAnnouncementRead>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: ResponsiveLayout.symmetric(context, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            snap.error.toString(),
                            style: tt.bodySmall?.copyWith(color: cs.error),
                          ),
                        ),
                        TextButton(onPressed: _reload, child: const Text('다시')),
                      ],
                    ),
                  );
                }
                if (snap.connectionState != ConnectionState.done) {
                  return Skeletonizer(
                    enabled: true,
                    child: Padding(
                      padding: ResponsiveLayout.symmetric(context, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                top: i == 0 ? 0 : context.rs(8),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('공지 제목 ${i + 1}'),
                                subtitle: Text(
                                  '요약 한 줄이 여기에 표시됩니다.',
                                  style: tt.bodySmall,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                final allItems = snap.data ?? const [];
                if (allItems.isEmpty) {
                  return Padding(
                    padding: ResponsiveLayout.only(context, top: 6, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '등록된 전체 공지가 없습니다.',
                          style:
                              tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        rsV(context, 10),
                        OutlinedButton.icon(
                          onPressed: () => _openEdit(context, null),
                          icon: const Icon(Icons.edit_notifications_outlined),
                          label: const Text('전체 공지 작성'),
                        ),
                      ],
                    ),
                  );
                }

                final pinnedItems = allItems.where((a) => a.isPinned).toList();
                final unpinnedItems = allItems.where((a) => !a.isPinned).toList();
                
                final displayItems = <WorkerAnnouncementRead>[];
                if (pinnedItems.isNotEmpty) {
                  displayItems.add(pinnedItems.first);
                  displayItems.addAll(unpinnedItems.take(2));
                } else {
                  displayItems.addAll(unpinnedItems.take(3));
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < displayItems.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ListTile(
                        dense: true,
                        contentPadding: ResponsiveLayout.symmetric(
                          context,
                          vertical: 2,
                        ),
                        leading: displayItems[i].isPinned
                            ? Icon(
                                Icons.push_pin,
                                size: context.rsi(18),
                                color: cs.primary,
                              )
                            : null,
                        title: Text(
                          displayItems[i].title.isEmpty ? '(제목 없음)' : displayItems[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: displayItems[i].isPinned ? cs.primary : null,
                          ),
                        ),
                        subtitle: displayItems[i].createdAt != null
                            ? Text(
                                '${displayItems[i].createdAt!.year}-${displayItems[i].createdAt!.month.toString().padLeft(2, '0')}-${displayItems[i].createdAt!.day.toString().padLeft(2, '0')}',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              )
                            : null,
                        trailing: PopupMenuButton<String>(
                          tooltip: '작업',
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'view', child: Text('미리보기')),
                            PopupMenuItem(
                              value: 'pin',
                              child: Text(displayItems[i].isPinned ? '최상단고정 해제' : '최상단고정'),
                            ),
                            const PopupMenuItem(value: 'edit', child: Text('수정')),
                            const PopupMenuItem(value: 'del', child: Text('삭제')),
                          ],
                          onSelected: (v) async {
                            final a = displayItems[i];
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
                        onTap: () => _openView(context, displayItems[i]),
                      ),
                    ],
                    if (allItems.length > 3)
                      Padding(
                        padding: EdgeInsets.only(top: context.rs(8)),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              await context.push<dynamic>(
                                '/dashboard/worker-announcements',
                              );
                              if (mounted) await _reload();
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
                                  '전체보기 (${allItems.length - displayItems.length}개 더)',
                                  style: tt.labelMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                rsH(context, 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: context.rsi(14),
                                  color: cs.primary,
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
        ),
      ),
    );
  }
}
