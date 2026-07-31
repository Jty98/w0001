import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장관리(진행중/완료)와 동일한 [CupertinoSlidingSegmentedControl] 톤.
/// 선택 thumb·라벨 대비를 키워 현재 탭이 분명히 보이도록 한다.
class AppSlidingSegment<T extends Object> extends StatelessWidget {
  const AppSlidingSegment({
    super.key,
    required this.value,
    required this.onChanged,
    required this.children,
    this.padding,
    this.dense = false,
    this.expanded = true,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final Map<T, Widget> children;
  final EdgeInsetsGeometry? padding;
  final bool dense;

  /// true면 가로 전체 폭을 균등 분할한다.
  final bool expanded;

  /// 회원관리·인력관리용 — `제목(개수)` 라벨.
  static Widget tabLabel(
    BuildContext context,
    String title, {
    int? count,
    required bool selected,
  }) {
    final cs = Theme.of(context).colorScheme;
    final label = count != null && count > 0
        ? '$title(${AppSegmentedButton.compactCount(count)})'
        : title;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? cs.onSurface : cs.onSurfaceVariant,
            letterSpacing: -0.2,
            height: 1.1,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hPad = context.rsi(dense ? 8 : 12);
    final vPad = context.rsi(dense ? 7 : 10);

    Widget wrapChild(T key, Widget child, {double? minWidth}) {
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth ?? 0),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: DefaultTextStyle.merge(
            style: tt.titleSmall?.copyWith(
              fontWeight: key == value ? FontWeight.w800 : FontWeight.w600,
              color: key == value ? cs.onSurface : cs.onSurfaceVariant,
              letterSpacing: -0.2,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
            child: Center(child: child),
          ),
        ),
      );
    }

    Widget buildControl({double? cellMinWidth}) {
      final resolved = {
        for (final e in children.entries)
          e.key: wrapChild(e.key, e.value, minWidth: cellMinWidth),
      };
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        thumbColor: cs.surface,
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.75),
        padding: EdgeInsets.all(context.rsi(dense ? 3 : 4)),
        children: resolved,
        onValueChanged: (next) {
          if (next != null) onChanged(next);
        },
      );
    }

    return Padding(
      padding: padding ??
          EdgeInsets.fromLTRB(
            context.rsi(16),
            dense ? 0 : context.rsi(12),
            context.rsi(16),
            context.rsi(8),
          ),
      child: expanded
          ? LayoutBuilder(
              builder: (context, constraints) {
                final n = children.length.clamp(1, 100);
                // 컨트롤 내부 패딩을 감안해 셀 최소폭을 잡아 가로 확장.
                final usable = (constraints.maxWidth - context.rsi(8)).clamp(
                  0,
                  double.infinity,
                );
                final cellMin = usable / n;
                return SizedBox(
                  width: double.infinity,
                  child: buildControl(cellMinWidth: cellMin),
                );
              },
            )
          : buildControl(),
    );
  }
}
