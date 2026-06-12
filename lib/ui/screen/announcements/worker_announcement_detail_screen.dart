import 'package:flutter/material.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_blocks_display.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_read_widgets.dart';
import 'package:w0001/util/responsive_layout.dart';

class WorkerAnnouncementDetailScreen extends StatelessWidget {
  const WorkerAnnouncementDetailScreen({super.key, required this.item});

  final WorkerAnnouncementRead item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = item.title.isEmpty ? '(제목 없음)' : item.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.rsi(18),
            context.rsi(16),
            context.rsi(18),
            context.rsi(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: cs.surfaceContainerLow.withValues(alpha: 0.85),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rsi(14),
                    vertical: context.rsi(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.createdAt != null) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_rounded,
                                    size: context.rs(18),
                                    color: cs.tertiary,
                                  ),
                                  SizedBox(width: context.rsi(8)),
                                  Text(
                                    '등록일 ${formatWorkerAnnouncementYmd(item.createdAt!)}',
                                    style: tt.bodySmall?.copyWith(
                                      color:
                                          cs.onSurface.withValues(alpha: 0.88),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.rsi(22)),
              Text(
                title,
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  letterSpacing: -0.35,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: context.rsi(16)),
              Row(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: context.rs(20),
                    color: cs.primary,
                  ),
                  SizedBox(width: context.rsi(8)),
                  Text(
                    '공지 내용',
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rsi(10)),
              Material(
                color: cs.surface.withValues(alpha: 0.96),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: cs.outline.withValues(alpha: 0.3),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rsi(16),
                    vertical: context.rsi(14),
                  ),
                  child: WorkerAnnouncementBlocksDisplay(blocks: item.blocks),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
