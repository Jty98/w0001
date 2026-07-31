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

/// 목록 카드 우측 상단 고정 표시.
class WorkerAnnouncementPinnedIcon extends StatelessWidget {
  const WorkerAnnouncementPinnedIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      Icons.push_pin_rounded,
      size: context.rs(15),
      color: cs.primary,
    );
  }
}

/// 현장 공지 목록: [WorkerAnnouncementReadListCard]와 동일 레이아웃 (본문 미리보기 없음).
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
    return WorkerAnnouncementReadListCard(
      item: item,
      onTap: onTap,
      trailing: trailing,
      showPreview: false,
    );
  }
}

/// 수신함·현장·관리 목록용 공지 카드.
class WorkerAnnouncementReadListCard extends StatelessWidget {
  const WorkerAnnouncementReadListCard({
    super.key,
    required this.item,
    required this.onTap,
    this.trailing,
    this.showPreview = true,
    this.previewMaxLen = 72,
    this.placeName,
  });

  final WorkerAnnouncementRead item;
  final VoidCallback onTap;
  final Widget? trailing;

  /// false면 본문 미리보기 박스 생략 (제목만 있는 목록).
  final bool showPreview;

  /// [showPreview]일 때 본문 미리보기 최대 글자 수.
  final int previewMaxLen;

  /// 현장 공지일 때 표시할 현장명(선택). 없으면 표시하지 않음.
  final String? placeName;

  static int _previewCodecMaxLen(BuildContext context, int configured) {
    if (context.isCompactDevice) {
      return (configured * 1.6).round().clamp(configured, 140);
    }
    return configured.clamp(64, 120);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final preview = showPreview
        ? WorkerAnnouncementQuillCodec.blocksPlainTextPreview(
            item.blocks,
            maxLen: _previewCodecMaxLen(context, previewMaxLen),
          )
        : '';
    final previewLabel =
        preview.isNotEmpty ? preview : (showPreview ? '(내용 없음)' : '');
    final previewMaxLines = context.isCompactDevice ? 3 : 2;
    final previewStyle = tt.bodySmall?.copyWith(
      height: 1.25,
      color: preview.isEmpty
          ? cs.onSurfaceVariant.withValues(alpha: 0.72)
          : cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final previewLinePx = MediaQuery.textScalerOf(context).scale(
          previewStyle?.fontSize ?? 12,
        ) *
        (previewStyle?.height ?? 1.25);
    final previewBoxMinHeight =
        previewLinePx * previewMaxLines + context.rsi(12);
    final title = item.title.isEmpty ? '(제목 없음)' : item.title;
    final placeLabel = (placeName ?? '').trim();
    final dateStyle = tt.labelSmall?.copyWith(
      color: cs.onSurfaceVariant.withValues(alpha: 0.75),
      fontWeight: FontWeight.w500,
      height: 1.1,
    );
    final hasTrailing = trailing != null;
    final hasPinned = item.isPinned;
    final actionReserve = context.rsi(
      (hasTrailing ? 36 : 0) +
          (hasPinned ? 18 : 0) +
          (hasTrailing && hasPinned ? 4 : 0),
    );
    final hPad = context.rsi(12);
    final vPad = context.rsi(10);

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
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasPinned || hasTrailing)
                    SizedBox(height: context.rsi(18)),
                  if (!item.isGlobal && placeLabel.isNotEmpty) ...[
                    Text(
                      placeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: context.rsi(3)),
                  ],
                  Padding(
                    padding: EdgeInsets.only(right: actionReserve),
                    child: Text(
                      title,
                      maxLines: context.isCompactDevice ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                        letterSpacing: -0.3,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (showPreview) ...[
                    SizedBox(height: context.rsi(5)),
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        minHeight: previewBoxMinHeight,
                      ),
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
                      alignment: Alignment.centerLeft,
                      child: Text(
                        previewLabel,
                        maxLines: previewMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: previewStyle,
                      ),
                    ),
                  ],
                  if (item.createdAt != null) ...[
                    SizedBox(height: context.rsi(6)),
                    Text(
                      formatWorkerAnnouncementYmd(item.createdAt!),
                      textAlign: TextAlign.right,
                      style: dateStyle,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasPinned || hasTrailing)
            Positioned(
              top: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  top: context.rsi(2),
                  right: context.rsi(0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPinned) const WorkerAnnouncementPinnedIcon(),
                    if (hasPinned && hasTrailing)
                      SizedBox(width: context.rsi(2)),
                    if (hasTrailing)
                      Theme(
                        data: Theme.of(context).copyWith(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: trailing!,
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
