import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';

enum AppRefreshIndicatorPlacement {
  center,
  top,
}

/// 앱 공통 당겨서 새로고침 인디케이터.
///
/// 기본 [RefreshIndicator] 동작은 유지하고, 실제 새로고침 수행 중에는
/// 해머 애니메이션 인디케이터를 오버레이로 표시한다.
class AppRefreshIndicator extends StatefulWidget {
  const AppRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.enabled = true,
    this.color,
    this.backgroundColor,
    this.strokeWidth,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticsLabel,
    this.semanticsValue,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.indicatorSize = 84,
    this.placement = AppRefreshIndicatorPlacement.top,
    this.minPullDistance = 76,
    this.previewTriggerDistance = 26,
  });

  final Widget child;
  final RefreshCallback onRefresh;
  final bool enabled;
  final Color? color;
  final Color? backgroundColor;
  final double? strokeWidth;
  final double displacement;
  final double edgeOffset;
  final ScrollNotificationPredicate notificationPredicate;
  final String? semanticsLabel;
  final String? semanticsValue;
  final RefreshIndicatorTriggerMode triggerMode;
  final double indicatorSize;
  final AppRefreshIndicatorPlacement placement;
  final double minPullDistance;
  final double previewTriggerDistance;

  /// 현재 컨텍스트가 [AppRefreshIndicator] 하위에 있고,
  /// pull-to-refresh 수행 중인지 여부.
  static bool isRefreshing(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_AppRefreshStateScope>();
    return scope?.isRefreshing ?? false;
  }

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator> {
  bool _refreshing = false;
  bool _pullPreviewVisible = false;
  int _refreshCycle = 0;
  bool _trackingPull = false;
  double _activePullDistance = 0;
  double _lastPullDistance = 0;

  void _trackPullDistance(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) return;
    if (notification.metrics.axis != Axis.vertical) return;
    if (notification.metrics.extentBefore > 0) {
      if (_pullPreviewVisible && !_refreshing) {
        setState(() => _pullPreviewVisible = false);
      }
      return;
    }

    if (notification is ScrollStartNotification) {
      _trackingPull = true;
      _activePullDistance = 0;
      if (_pullPreviewVisible && !_refreshing) {
        setState(() => _pullPreviewVisible = false);
      }
      return;
    }
    if (notification is OverscrollNotification && _trackingPull) {
      if (notification.overscroll < 0) {
        _activePullDistance += notification.overscroll.abs();
      } else if (notification.overscroll > 0) {
        _activePullDistance =
            (_activePullDistance - notification.overscroll).clamp(0, 10000);
      }
      final shouldShowPreview = !_refreshing &&
          _activePullDistance >= widget.previewTriggerDistance;
      if (shouldShowPreview != _pullPreviewVisible) {
        setState(() => _pullPreviewVisible = shouldShowPreview);
      }
      return;
    }
    if (notification is ScrollUpdateNotification && _trackingPull) {
      final delta = notification.scrollDelta;
      if (delta != null && delta < 0) {
        _activePullDistance += delta.abs();
      } else if (delta != null && delta > 0) {
        _activePullDistance = (_activePullDistance - delta).clamp(0, 10000);
      }
      final shouldShowPreview = !_refreshing &&
          _activePullDistance >= widget.previewTriggerDistance;
      if (shouldShowPreview != _pullPreviewVisible) {
        setState(() => _pullPreviewVisible = shouldShowPreview);
      }
      return;
    }
    if (notification is ScrollEndNotification) {
      _lastPullDistance = _activePullDistance;
      _trackingPull = false;
      _activePullDistance = 0;
      if (!_refreshing && _pullPreviewVisible) {
        setState(() => _pullPreviewVisible = false);
      }
    }
  }

  void _onStatusChange(RefreshIndicatorStatus? status) {
    if (status == RefreshIndicatorStatus.drag ||
        status == RefreshIndicatorStatus.armed) {
      if (_refreshing) return;
      final shouldShow = _trackingPull &&
          _activePullDistance >= widget.previewTriggerDistance;
      if (shouldShow != _pullPreviewVisible) {
        setState(() => _pullPreviewVisible = shouldShow);
      }
      return;
    }
    if (status == RefreshIndicatorStatus.canceled || status == null) {
      if (_pullPreviewVisible || _refreshing) {
        setState(() {
          _pullPreviewVisible = false;
          _refreshing = false;
        });
      }
      return;
    }
    if (status == RefreshIndicatorStatus.done && _pullPreviewVisible) {
      setState(() => _pullPreviewVisible = false);
    }
  }

  bool _strictTopEdgePredicate(ScrollNotification notification) {
    _trackPullDistance(notification);
    if (!widget.notificationPredicate(notification)) return false;
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    // 상단에서 당겨서 새로고침할 때만 트리거되도록 제한한다.
    return metrics.extentBefore <= 0;
  }

  Future<void> _handleRefresh() async {
    if (_refreshing) return;
    final pulledDistance = _trackingPull ? _activePullDistance : _lastPullDistance;
    if (pulledDistance < widget.minPullDistance) {
      if (_pullPreviewVisible) {
        setState(() => _pullPreviewVisible = false);
      }
      return;
    }
    setState(() {
      _refreshCycle += 1;
      _refreshing = true;
      _pullPreviewVisible = false;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _pullPreviewVisible = false;
          _trackingPull = false;
          _activePullDistance = 0;
          _lastPullDistance = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return _AppRefreshStateScope(
        isRefreshing: false,
        child: widget.child,
      );
    }
    final alignment = widget.placement == AppRefreshIndicatorPlacement.top
        ? Alignment.topCenter
        : Alignment.center;
    final verticalPadding = widget.placement == AppRefreshIndicatorPlacement.top
        ? widget.edgeOffset + (widget.displacement * 0.18)
        : 0.0;
    final showIndicator = _refreshing || _pullPreviewVisible;
    Widget indicatorBadge({required bool animate}) {
      final cs = Theme.of(context).colorScheme;
      final badgeSize = widget.indicatorSize * 0.76;
      final hammerSize = widget.indicatorSize * (animate ? 0.9 : 0.84);
      return Container(
        key: ValueKey<String>(
          '${animate ? 'loading' : 'preview'}_$_refreshCycle',
        ),
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHigh.withValues(alpha: 0.68),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.26),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: HammerLoadingIndicator(
          size: hammerSize,
          animate: animate,
        ),
      );
    }

    return _AppRefreshStateScope(
      isRefreshing: _refreshing,
      child: Stack(
        children: [
          RefreshIndicator.noSpinner(
            onRefresh: _handleRefresh,
            onStatusChange: _onStatusChange,
            notificationPredicate: _strictTopEdgePredicate,
            semanticsLabel: widget.semanticsLabel,
            semanticsValue: widget.semanticsValue,
            triggerMode: widget.triggerMode,
            child: widget.child,
          ),
          IgnorePointer(
            ignoring: true,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: alignment,
                child: Padding(
                  padding: EdgeInsets.only(top: verticalPadding),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: showIndicator
                        ? indicatorBadge(animate: _refreshing)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRefreshStateScope extends InheritedWidget {
  const _AppRefreshStateScope({
    required this.isRefreshing,
    required super.child,
  });

  final bool isRefreshing;

  @override
  bool updateShouldNotify(_AppRefreshStateScope oldWidget) {
    return oldWidget.isRefreshing != isRefreshing;
  }
}
