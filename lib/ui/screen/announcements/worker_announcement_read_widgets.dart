import 'package:flutter/material.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/util/responsive_layout.dart';

String formatWorkerAnnouncementYmd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// 현장 공지 목록: 제목 · 등록일 · [trailing]만 (본문 미리보기 없음).
class PlaceWorkerAnnouncementListTile extends StatelessWidget {
  const PlaceWorkerAnnouncementListTile({
    super.key,
    required this.item,
    required this.onTap,
    this.trailing,
  });

  final WorkerAnnouncementRead item;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = item.title.isEmpty ? '(제목 없음)' : item.title;

    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.72),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(12),
          context.rsi(10),
          context.rsi(4),
          context.rsi(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: EdgeInsets.only(
                    right: context.rsi(4),
                    bottom: context.rsi(2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (item.isPinned) ...[
                            Icon(
                              Icons.push_pin,
                              size: context.rs(16),
                              color: cs.primary,
                            ),
                            SizedBox(width: context.rsi(6)),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: -0.25,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.createdAt != null) ...[
                        SizedBox(height: context.rsi(4)),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: context.rs(14),
                              color: cs.onSurfaceVariant,
                            ),
                            SizedBox(width: context.rsi(4)),
                            Text(
                              formatWorkerAnnouncementYmd(item.createdAt!),
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: EdgeInsets.only(
                  left: context.rsi(2),
                  top: context.rsi(2),
                ),
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}

/// 수신함·현장·관리 목록용 공지 카드 (제목 / 본문 미리보기 영역 분리).
class WorkerAnnouncementReadListCard extends StatelessWidget {
  const WorkerAnnouncementReadListCard({
    super.key,
    required this.item,
    required this.onTap,
    this.trailing,
    this.showPreview = true,
    this.showEndChevron = true,
    this.placeName,
  });

  final WorkerAnnouncementRead item;
  final VoidCallback onTap;
  final Widget? trailing;

  /// false면 본문 미리보기 박스 생략 (제목만 있는 목록).
  final bool showPreview;

  /// [trailing]이 없고 true면 오른쪽에 화살표 표시.
  final bool showEndChevron;

  /// 현장 공지일 때 표시할 현장명(선택). 없으면 표시하지 않음.
  final String? placeName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final preview = showPreview
        ? WorkerAnnouncementQuillCodec.blocksPlainTextPreview(item.blocks)
        : '';
    final title = item.title.isEmpty ? '(제목 없음)' : item.title;
    final placeLabel = (placeName ?? '').trim();

    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.72),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rsi(12),
            context.rsi(10),
            context.rsi(8),
            context.rsi(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.createdAt != null ||
                  trailing != null ||
                  (!item.isGlobal && placeLabel.isNotEmpty)) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.createdAt != null)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: context.rs(14),
                              color: cs.onSurfaceVariant,
                            ),
                            SizedBox(width: context.rsi(3)),
                            Flexible(
                              child: Text(
                                formatWorkerAnnouncementYmd(
                                  item.createdAt!,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!item.isGlobal && placeLabel.isNotEmpty) ...[
                      if (item.createdAt != null) SizedBox(width: context.rsi(8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rsi(8),
                          vertical: context.rsi(3),
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          placeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                    if (trailing != null) ...[
                      if (item.createdAt == null) const Spacer(),
                      trailing!,
                    ],
                  ],
                ),
                SizedBox(height: context.rsi(6)),
              ],
              Text(
                title,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                  letterSpacing: -0.3,
                  color: cs.onSurface,
                ),
              ),
              if (preview.isNotEmpty) ...[
                SizedBox(height: context.rsi(6)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    context.rsi(8),
                    context.rsi(6),
                    context.rsi(8),
                    context.rsi(6),
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      height: 1.28,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (showEndChevron && trailing == null) ...[
                SizedBox(height: context.rsi(2)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                      size: context.rs(22),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
