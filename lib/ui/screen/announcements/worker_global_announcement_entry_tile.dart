import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 — 전체 공지 수신함(`/announcements/inbox?filter=global`)으로 이동하는 진입 카드.
class WorkerGlobalAnnouncementEntryTile extends StatelessWidget {
  const WorkerGlobalAnnouncementEntryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cs.outline.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/announcements/inbox?filter=global'),
        child: Padding(
          padding: ResponsiveLayout.symmetric(
            context,
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                color: cs.primary,
                size: context.rsi(26),
              ),
              rsH(context, 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '전체 공지',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    rsV(context, 2),
                    Text(
                      '전체 공지를 확인하려면 누르세요',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
