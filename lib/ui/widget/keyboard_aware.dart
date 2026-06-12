import 'package:flutter/material.dart';

/// [TextField.scrollPadding] — 키보드·하단 탭·툴바를 고려한 여백.
EdgeInsets keyboardScrollPadding(
  BuildContext context, {
  double extra = 24,
}) {
  final bottom = MediaQuery.viewInsetsOf(context).bottom;
  return EdgeInsets.fromLTRB(20, 20, 20, bottom + extra);
}

/// 키보드가 올라올 때 하단 inset을 반영하고, 포커스된 입력란을 자동으로 보이게 한다.
class KeyboardAwareScrollView extends StatefulWidget {
  const KeyboardAwareScrollView({
    super.key,
    this.controller,
    this.padding,
    this.physics,
    this.scrollFocusedAlignment = 0.18,
    this.autoScrollOnFocus = true,
    required this.child,
  });

  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  /// [Scrollable.ensureVisible] 정렬 (0=상단, 1=하단).
  final double scrollFocusedAlignment;

  /// false면 키보드·포커스 시 자동 스크롤 생략 (로그인 등 짧은 폼).
  final bool autoScrollOnFocus;
  final Widget child;

  @override
  State<KeyboardAwareScrollView> createState() =>
      _KeyboardAwareScrollViewState();
}

class _KeyboardAwareScrollViewState extends State<KeyboardAwareScrollView>
    with WidgetsBindingObserver {
  double _lastViewInsetBottom = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.autoScrollOnFocus) return;
    if (FocusManager.instance.primaryFocus?.hasFocus == true) {
      _scheduleScrollFocusedIntoView();
    }
  }

  @override
  void didChangeMetrics() {
    if (!widget.autoScrollOnFocus) {
      _lastViewInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      if (bottom > _lastViewInsetBottom) {
        _scheduleScrollFocusedIntoView();
      }
      _lastViewInsetBottom = bottom;
    });
  }

  void _scheduleScrollFocusedIntoView({
    List<Duration> delays = const [
      Duration.zero,
      Duration(milliseconds: 80),
      Duration(milliseconds: 280),
    ],
  }) {
    void nudge() {
      if (!mounted) return;
      final focus = FocusManager.instance.primaryFocus;
      if (focus == null || !focus.hasFocus) return;
      final ctx = focus.context;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: widget.scrollFocusedAlignment,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    for (final d in delays) {
      if (d == Duration.zero) {
        WidgetsBinding.instance.addPostFrameCallback((_) => nudge());
      } else {
        Future<void>.delayed(d, nudge);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.padding ?? EdgeInsets.zero;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    _lastViewInsetBottom = bottom;

    return SingleChildScrollView(
      controller: widget.controller,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: base.add(EdgeInsets.only(bottom: bottom + 24)),
      child: widget.child,
    );
  }
}

/// 포커스·키보드 표시 시 [Scrollable.ensureVisible]로 입력 영역을 보이게 한다.
mixin KeyboardScrollIntoViewMixin<T extends StatefulWidget> on State<T> {
  @protected
  GlobalKey? get keyboardScrollTargetKey;

  _KeyboardMetricsObserver? _metricsObserver;

  @override
  void initState() {
    super.initState();
    _metricsObserver = _KeyboardMetricsObserver(() {
      if (!mounted) return;
      onKeyboardMetricsChanged();
    });
    WidgetsBinding.instance.addObserver(_metricsObserver!);
  }

  @override
  void dispose() {
    if (_metricsObserver != null) {
      WidgetsBinding.instance.removeObserver(_metricsObserver!);
    }
    super.dispose();
  }

  @protected
  void onKeyboardMetricsChanged() {
    scheduleKeyboardScrollIntoView();
  }

  void scheduleKeyboardScrollIntoView({
    double alignment = 0.12,
    List<Duration> delays = const [
      Duration.zero,
      Duration(milliseconds: 100),
      Duration(milliseconds: 320),
    ],
  }) {
    void nudge() {
      if (!mounted) return;
      final ctx = keyboardScrollTargetKey?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: alignment,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    for (final d in delays) {
      if (d == Duration.zero) {
        WidgetsBinding.instance.addPostFrameCallback((_) => nudge());
      } else {
        Future<void>.delayed(d, nudge);
      }
    }
  }
}

final class _KeyboardMetricsObserver with WidgetsBindingObserver {
  _KeyboardMetricsObserver(this._onMetrics);

  final VoidCallback _onMetrics;

  @override
  void didChangeMetrics() => _onMetrics();
}
