import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:w0001/util/responsive_layout.dart';

/// infinite scroll 목록 하단 — 다음 페이지 로딩 또는 더 불러오기 안내.
class PagedListFooter extends StatelessWidget {
  const PagedListFooter({
    super.key,
    required this.isLoading,
    required this.hasMore,
    this.idleHint = '아래로 스크롤하면 더 불러옵니다',
  });

  final bool isLoading;
  final bool hasMore;
  final String idleHint;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.rs(16)),
        child: const AppLoadingIndicator(size: 52),
      );
    }
    if (!hasMore) return SizedBox(height: context.rs(8));
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rs(20)),
      child: Center(
        child: Text(
          idleHint,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

/// [ScrollController] 하단 근처 도달 시 [onLoadMore] 호출.
void onPagedScrollNearEnd(
  ScrollController controller, {
  required VoidCallback onLoadMore,
  double threshold = 200,
}) {
  if (!controller.hasClients) return;
  final pos = controller.position;
  if (!pos.hasContentDimensions) return;
  // 스크롤 범위가 없으면(한 화면에 다 보임) 자동 loadMore 하지 않음.
  if (pos.maxScrollExtent <= 0) return;
  if (pos.maxScrollExtent - pos.pixels <= threshold) {
    onLoadMore();
  }
}

/// 빌드·목록 갱신 직후 스크롤 가능 여부와 관계없이 하단 근처를 한 번 검사한다.
void schedulePagedScrollNearEndCheck(
  ScrollController controller, {
  required VoidCallback onLoadMore,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    onPagedScrollNearEnd(controller, onLoadMore: onLoadMore);
  });
}
