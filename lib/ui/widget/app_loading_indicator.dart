import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 앱 공통 데이터 로딩 인디케이터.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size,
    this.label,
    this.hideDuringPullRefresh = true,
  });

  final double? size;
  final String? label;
  final bool hideDuringPullRefresh;

  @override
  Widget build(BuildContext context) {
    if (hideDuringPullRefresh && AppRefreshIndicator.isRefreshing(context)) {
      return const SizedBox.shrink();
    }
    final resolvedSize = size ?? context.rs(88);
    return Center(
      child: HammerLoadingIndicator(
        size: resolvedSize,
        label: label,
      ),
    );
  }
}
