import 'dart:math' as math;

import 'package:flutter/material.dart';

/// [fl_chart] 축·툴팁 글자 크기와 축 [reservedSize]를 플롯 크기·라벨 개수에 맞게 계산.
///
/// 관리자·작업자 대시보드 차트([dashboard_line_charts.dart])에서 공통 사용.
class DashboardChartMetrics {
  DashboardChartMetrics({
    required this.width,
    required this.height,
    required this.labelCount,
    this.hasRightAxis = false,
    this.maxBottomLabelChars = 3,
    this.maxLeftLabelChars = 5,
    this.deviceTextScale = 1.0,
  });

  final double width;
  final double height;
  final int labelCount;
  final bool hasRightAxis;

  /// 하단·좌측 라벨 최대 글자 수 추정 (여백 계산용).
  final int maxBottomLabelChars;
  final int maxLeftLabelChars;

  /// [BuildContext.deviceTextScale] — 차트 축·여백을 기기 비율에 맞춤.
  final double deviceTextScale;

  static const double minAxisFont = 7;
  static const double maxAxisFont = 11;

  int get _n => math.max(1, labelCount);

  double get _safeWidth => width.isFinite && width > 0 ? width : 320;

  double get _safeHeight => height.isFinite && height > 0 ? height : 200;

  double _s(double value) => value * deviceTextScale;

  /// 축 여백 추정에 쓰는 기준 폰트 (순환 참조 방지).
  double get _baselineAxisFont {
    final estPlot = math.max(
      48,
      _safeWidth -
          _estimateLeftReserved(minAxisFont) -
          _estimateRightReserved(minAxisFont),
    );
    final fromSlot = (estPlot / _n) * 0.38;
    final fromHeight = _safeHeight * 0.048;
    return fromSlot.clamp(
        minAxisFont, fromHeight.clamp(minAxisFont, maxAxisFont));
  }

  double _estimateLeftReserved(double font) {
    return _s((maxLeftLabelChars * font * 0.62 + 10).clamp(26, 48));
  }

  double _estimateRightReserved(double font) {
    return hasRightAxis ? _s((font * 3.2 + 8).clamp(26, 40)) : 0;
  }

  double get axisFontSize => _baselineAxisFont * deviceTextScale;

  double get leftReserved => _estimateLeftReserved(axisFontSize);

  double get rightReserved => _estimateRightReserved(axisFontSize);

  double get bottomReserved => _s(
      (math.max(maxBottomLabelChars * axisFontSize * 0.55, axisFontSize * 2.2) +
              8)
          .clamp(20, 34));

  double get plotWidth =>
      math.max(48, _safeWidth - leftReserved - rightReserved);

  double get slotWidth => plotWidth / _n;

  double get tooltipFontSize => (axisFontSize + 1.5).clamp(9, 12);

  /// 좁은 플롯에서 하단 라벨을 건너뛰어 겹침·잘림 방지.
  bool showBottomLabelAt(int index) {
    if (index < 0 || index >= _n) return false;
    if (_n <= 7) return true;
    if (slotWidth >= 22) return true;
    if (slotWidth >= 16) return index.isEven || index == _n - 1;
    return index % 3 == 0 || index == _n - 1;
  }

  /// 차트 축 전용 — 플롯 크기에 맞춘 [fontSize] (앱 [TextScaler]와 별도).
  TextStyle axisStyle(
    ColorScheme cs,
    TextTheme tt, {
    FontWeight weight = FontWeight.w600,
    bool emphasis = false,
  }) {
    final base = tt.labelSmall ?? const TextStyle();
    return base.copyWith(
      fontSize: axisFontSize,
      color:
          emphasis ? cs.onSurface.withValues(alpha: 0.9) : cs.onSurfaceVariant,
      fontWeight: emphasis ? FontWeight.w700 : weight,
    );
  }

  Widget bottomAxisLabel(
    String text, {
    required ColorScheme cs,
    required TextTheme tt,
    bool emphasis = false,
  }) {
    final maxW = math.max(8, slotWidth - 2);
    return Padding(
      padding: EdgeInsets.only(top: _s(4)),
      child: SizedBox(
        width: maxW.toDouble(),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: Text(
            text,
            style: axisStyle(cs, tt, emphasis: emphasis),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Widget leftAxisLabel(
    String text, {
    required ColorScheme cs,
    required TextTheme tt,
    bool emphasis = false,
    EdgeInsetsGeometry? padding,
  }) {
    return Padding(
      padding: padding ?? EdgeInsets.only(right: _s(4)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: axisStyle(cs, tt, emphasis: emphasis),
          maxLines: 1,
        ),
      ),
    );
  }

  Widget rightAxisLabel(
    String text, {
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: _s(4)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: axisStyle(cs, tt, emphasis: true),
          maxLines: 1,
        ),
      ),
    );
  }
}

/// 금액 Y축 눈금 문자열 (억·만 단위 축약).
String dashboardChartMoneyAxisLabel(int value) {
  final iv = value;
  if (iv.abs() >= 100000000) {
    return '${(iv / 100000000).toStringAsFixed(0)}억';
  }
  if (iv.abs() >= 10000) {
    return '${(iv / 10000).toStringAsFixed(0)}만';
  }
  return '$iv';
}

/// 하단 라벨 목록에서 최대 글자 수.
int dashboardChartMaxLabelChars(Iterable<String> labels, {int fallback = 3}) {
  var max = fallback;
  for (final s in labels) {
    max = math.max(max, s.length);
  }
  return max;
}
