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

  /// 작은 기기·3분할 세그먼트용 — 글자 크기를 줄이고 한 줄을 유지한다.
  static Widget compactSegmentLabel(
    BuildContext context,
    String text, {
    TextStyle? baseStyle,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    final fontSize = w < 340 ? 9.0 : (w < 380 ? 10.0 : 11.0);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: segmentLabel(
        text,
        style: (baseStyle ?? const TextStyle()).copyWith(fontSize: fontSize),
      ),
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
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      minimumSize: minimumSize,
      side: side,
      textStyle: textStyle,
      tapTargetSize: tapTargetSize,
    );
  }

  /// 큰 숫자도 세그먼트 한 줄 유지 — 9999 초과는 `1.2만` 형식.
  static String compactCount(int n) {
    if (n <= 0) return '';
    if (n < 10000) return '$n';
    if (n < 100000000) {
      final man = n / 10000;
      if (man >= 100) return '${man.round()}만';
      final rounded = (man * 10).round() / 10;
      final text = rounded == rounded.roundToDouble()
          ? '${rounded.toInt()}'
          : rounded.toStringAsFixed(1);
      return '${text}만';
    }
    final eok = n / 100000000;
    if (eok >= 100) return '${eok.round()}억';
    final rounded = (eok * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? '${rounded.toInt()}'
        : rounded.toStringAsFixed(1);
    return '${text}억';
  }

  /// 회원관리 3분할 세그먼트 라벨 — 아이콘 없이, 인원은 괄호·축약.
  static Widget memberTabLabel(
    BuildContext context,
    String title, {
    int? count,
    bool highlightCount = false,
  }) {
    final label =
        count != null && count > 0 ? '$title(${compactCount(count)})' : title;
    return compactSegmentLabel(context, label);
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
