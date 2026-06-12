import 'package:flutter/material.dart';

/// 앱 공통 [SegmentedButton] — 둥근 사각형(캡슐형 Stadium 아님).
abstract final class AppSegmentedButton {
  AppSegmentedButton._();

  static const double borderRadius = 10;

  static RoundedRectangleBorder get segmentShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      );

  /// 세그먼트 라벨이 좁은 폭에서 두 줄로 깨지지 않게 한다 (아이콘은 별도 배치 권장).
  static Widget segmentLabel(
    String text, {
    TextStyle? style,
  }) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      textAlign: TextAlign.center,
      style: style,
    );
  }

  /// 개별 화면에서 [SegmentedButton.style]을 덮어쓸 때 사용.
  static ButtonStyle styleFrom({
    VisualDensity? visualDensity,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    BorderSide? side,
    TextStyle? textStyle,
    MaterialTapTargetSize? tapTargetSize,
  }) {
    return SegmentedButton.styleFrom(
      shape: segmentShape,
      visualDensity: visualDensity ?? VisualDensity.compact,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      minimumSize: minimumSize,
      side: side,
      textStyle: textStyle,
      tapTargetSize: tapTargetSize,
    );
  }

  static SegmentedButtonThemeData themeData(ColorScheme colorScheme) {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(segmentShape),
        side: WidgetStatePropertyAll(
          BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.65)),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
