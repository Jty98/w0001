import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 공정표 차트 레이아웃 — 디자인 dp(390 기준). [BuildContext]로 기기 스케일.
abstract final class ProcessScheduleChartDim {
  static const double _leftColW = 118;
  static const double _headerH = 48;
  static const double _cellW = 52;
  static const double _cellH = 46;
  static const double _segmentRadius = 14;

  static const double viewerMinScale = 0.22;
  static const double viewerMaxScale = 3.2;

  static double leftColW(BuildContext context) => context.rs(_leftColW);

  static double headerH(BuildContext context) => context.rs(_headerH);

  static double cellW(BuildContext context) => context.rs(_cellW);

  static double cellH(BuildContext context) => context.rs(_cellH);

  static double segmentRadius(BuildContext context) =>
      context.rs(_segmentRadius);
}
