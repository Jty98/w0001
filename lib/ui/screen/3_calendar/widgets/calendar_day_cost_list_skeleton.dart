import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 캘린더 선택일 현장 목록 로딩 스켈레톤 (컴팩트).
class CalendarDayCostListSkeleton extends StatelessWidget {
  const CalendarDayCostListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      child: ListView(
        padding: ResponsiveLayout.only(context, left: 10, top: 2, right: 10),
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) SizedBox(height: context.rsi(5)),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.rs(12)),
              ),
              child: Padding(
                padding: ResponsiveLayout.symmetric(
                  context,
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('○○아파트 101동'),
                    SizedBox(height: context.rsi(6)),
                    Container(
                      height: context.rs(30),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: cs.surfaceContainerHighest,
                      ),
                    ),
                    SizedBox(height: context.rsi(5)),
                    Container(
                      height: context.rs(68),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: cs.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
