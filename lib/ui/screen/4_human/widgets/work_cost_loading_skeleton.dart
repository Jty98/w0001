import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인건비 목록(작업자 카드) 로딩 스켈레톤.
class WorkCostWorkerListSkeleton extends StatelessWidget {
  const WorkCostWorkerListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveLayout.isCompact(MediaQuery.sizeOf(context));
    return Skeletonizer(
      enabled: true,
      child: ListView(
        padding: EdgeInsets.only(bottom: context.rsi(8)),
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) SizedBox(height: context.rsi(compact ? 4 : 6)),
            AppInsetTile(
              child: ListTile(
                title: const Text('홍길동'),
                subtitle: const Text('미지급 300,000원 · 지급 150,000원'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 인건비 상세(항목) 목록 로딩 스켈레톤.
class WorkCostItemListSkeleton extends StatelessWidget {
  const WorkCostItemListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveLayout.isCompact(MediaQuery.sizeOf(context));
    return Skeletonizer(
      enabled: true,
      child: ListView(
        padding: EdgeInsets.only(bottom: context.rsi(8)),
        children: [
          for (var i = 0; i < 8; i++) ...[
            if (i > 0) SizedBox(height: context.rsi(compact ? 4 : 6)),
            AppInsetTile(
              child: ListTile(
                leading: const CircleAvatar(child: Text('현')),
                title: const Text('○○아파트 101동'),
                subtitle: const Text('2025-06-01 · 목공'),
                trailing: const Text('150,000원'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
