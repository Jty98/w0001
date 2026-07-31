import 'dart:async';

import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 짧은 토스트를 하단에서 **위로 쌓아** 표시한다 (큐 대기 없음, 각각 독립 타이머).
final class StackedToastController extends ChangeNotifier {
  StackedToastController._();

  static final StackedToastController instance = StackedToastController._();

  static const maxVisible = 5;
  static const defaultDuration = Duration(milliseconds: 2200);
  static const dedupeWindow = Duration(milliseconds: 400);

  final List<_ToastEntry> _entries = [];
  final Map<String, Timer> _timers = {};
  final Map<String, VoidCallback> _onRemoved = {};
  String? _lastMessage;
  DateTime? _lastShownAt;

  List<_ToastEntry> get entries => List.unmodifiable(_entries);

  String show(
    String message, {
    Duration? duration,
    Color? backgroundColor,
    VoidCallback? onTap,
    bool dismissOnTap = true,
    VoidCallback? onRemoved,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return '';

    final now = DateTime.now();
    if (_lastMessage == trimmed &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < dedupeWindow) {
      return _entries.isNotEmpty ? _entries.last.id : '';
    }
    _lastMessage = trimmed;
    _lastShownAt = now;

    final id = '${now.microsecondsSinceEpoch}_${_entries.length}';
    if (onRemoved != null) {
      _onRemoved[id] = onRemoved;
    }
    _entries.add(
      _ToastEntry(
        id: id,
        message: trimmed,
        backgroundColor: backgroundColor,
        onTap: onTap,
        dismissOnTap: dismissOnTap,
      ),
    );
    while (_entries.length > maxVisible) {
      final removed = _entries.removeAt(0);
      _timers.remove(removed.id)?.cancel();
      _onRemoved.remove(removed.id)?.call();
    }
    notifyListeners();

    _timers[id]?.cancel();
    _timers[id] = Timer(duration ?? defaultDuration, () => dismiss(id));
    return id;
  }

  void dismiss(String id, {bool callRemoved = true}) {
    _timers.remove(id)?.cancel();
    final had = _entries.any((e) => e.id == id);
    if (!had) return;
    _entries.removeWhere((e) => e.id == id);
    if (callRemoved) {
      _onRemoved.remove(id)?.call();
    } else {
      _onRemoved.remove(id);
    }
    notifyListeners();
  }

  void dismissNewest() {
    if (_entries.isEmpty) return;
    dismiss(_entries.last.id);
  }

  void clearAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _onRemoved.clear();
    _lastMessage = null;
    _lastShownAt = null;
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}

final class _ToastEntry {
  const _ToastEntry({
    required this.id,
    required this.message,
    this.backgroundColor,
    this.onTap,
    this.dismissOnTap = true,
  });

  final String id;
  final String message;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool dismissOnTap;
}

/// [MaterialApp.builder] 안 — 라우트보다 안쪽에 두어 [ScaffoldMessenger.of]가
/// [AppScaffoldMessenger]를 먼저 찾도록 한다.
class StackedToastHost extends StatelessWidget {
  const StackedToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        const _StackedToastLayer(),
      ],
    );
  }
}

class _StackedToastLayer extends StatelessWidget {
  const _StackedToastLayer();

  @override
  Widget build(BuildContext context) {
    final controller = StackedToastController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final entries = controller.entries;
        if (entries.isEmpty) return const SizedBox.shrink();

        final bottom =
            MediaQuery.viewPaddingOf(context).bottom + context.rsi(12);
        final horizontal = context.rsi(16);

        return Positioned(
          left: horizontal,
          right: horizontal,
          bottom: bottom,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) SizedBox(height: context.rsi(6)),
                  _StackedToastTile(
                    entry: entries[i],
                    onDismiss: () =>
                        StackedToastController.instance.dismiss(entries[i].id),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StackedToastTile extends StatelessWidget {
  const _StackedToastTile({
    required this.entry,
    required this.onDismiss,
  });

  final _ToastEntry entry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = entry.backgroundColor ?? cs.inverseSurface;
    final fg =
        entry.backgroundColor == null ? cs.onInverseSurface : Colors.white;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: () {
          entry.onTap?.call();
          if (entry.dismissOnTap) onDismiss();
        },
        behavior: HitTestBehavior.opaque,
        child: Material(
          color: bg,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(14),
              vertical: context.rsi(11),
            ),
            child: Text(
              entry.message,
              style: (tt.bodyMedium ?? const TextStyle()).copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

/// 화면 전환 시 남아 있는 토스트를 정리한다.
final class StackedToastNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && route is PageRoute) {
      StackedToastController.instance.clearAll();
    }
  }
}

String snackBarContentText(Widget widget) {
  final buf = StringBuffer();
  _collectWidgetText(widget, buf);
  return buf.toString().trim();
}

void _collectWidgetText(Widget widget, StringBuffer buf) {
  if (widget is Text) {
    if (widget.data != null && widget.data!.isNotEmpty) {
      buf.write(widget.data);
      return;
    }
    final span = widget.textSpan;
    if (span != null) {
      buf.write(span.toPlainText());
      return;
    }
  }
  if (widget is SelectableText) {
    if (widget.data != null && widget.data!.isNotEmpty) {
      buf.write(widget.data);
      return;
    }
    final span = widget.textSpan;
    if (span != null) {
      buf.write(span.toPlainText());
      return;
    }
  }
  if (widget is RichText) {
    buf.write(widget.text.toPlainText());
    return;
  }
  if (widget is Wrap) {
    for (final child in widget.children) {
      if (child is Widget) _collectWidgetText(child, buf);
    }
    return;
  }
  if (widget is Row || widget is Column) {
    final children =
        widget is Row ? widget.children : (widget as Column).children;
    for (final child in children) {
      if (child is Widget) _collectWidgetText(child, buf);
    }
    return;
  }
  if (widget is Padding ||
      widget is Center ||
      widget is Align ||
      widget is Expanded) {
    final dynamic w = widget;
    final child = w.child as Widget?;
    if (child != null) _collectWidgetText(child, buf);
    return;
  }
  if (widget is GestureDetector) {
    final child = widget.child;
    if (child != null) _collectWidgetText(child, buf);
    return;
  }
  if (widget is DefaultTextStyle) {
    _collectWidgetText(widget.child, buf);
    return;
  }
  if (widget is Icon) return;
  if (widget is SizedBox) {
    final child = widget.child;
    if (child != null) _collectWidgetText(child, buf);
  }
}
