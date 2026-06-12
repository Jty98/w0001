import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_chart_metrics.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

double _axisInterval(double minY, double maxY) {
  final range = maxY - minY;
  if (!range.isFinite || range <= 0) return 1;
  return range / 4;
}

/// 선·점 그래프용 시리즈 한 줄.
class DashboardLineSeries {
  const DashboardLineSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<double> values;
}

/// 금액·건수 등 다축 선 그래프 (곡선 + 점).
class DashboardLineChart extends StatelessWidget {
  const DashboardLineChart({
    super.key,
    required this.bottomLabels,
    required this.series,
    this.integerYAxis = false,
    this.yAxisIsPercent = false,
    this.minYOverride,
    this.maxYOverride,
  });

  final List<String> bottomLabels;
  final List<DashboardLineSeries> series;
  final bool integerYAxis;
  final bool yAxisIsPercent;
  final double? minYOverride;
  final double? maxYOverride;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (bottomLabels.isEmpty || series.isEmpty) {
      return const Center(child: Text('데이터가 없습니다.'));
    }
    final n = bottomLabels.length;
    for (final s in series) {
      if (s.values.length != n) {
        return const Center(child: Text('차트 데이터 길이가 맞지 않습니다.'));
      }
    }

    double dataMin = double.infinity;
    double dataMax = -double.infinity;
    for (final s in series) {
      for (final v in s.values) {
        if (v > dataMax) dataMax = v;
        if (v < dataMin) dataMin = v;
      }
    }
    if (!dataMin.isFinite) dataMin = 0;
    if (!dataMax.isFinite) dataMax = 1;
    if (dataMax < dataMin) dataMax = dataMin + 1;

    final bool allNonNegative = dataMin >= -1e-9;
    double minY;
    double maxY;

    if (integerYAxis) {
      minY = 0;
      maxY = dataMax.ceilToDouble();
      if (maxY < 4) maxY = 4;
    } else if (yAxisIsPercent) {
      if (allNonNegative) {
        minY = 0;
        final span = dataMax <= 0 ? 10.0 : dataMax;
        maxY = math.max(8.0, span * 1.12);
      } else {
        final span = (dataMax - dataMin).abs();
        final pad = span < 1e-6 ? 4.0 : span * 0.12;
        minY = dataMin - pad;
        maxY = dataMax + pad;
      }
    } else {
      // 금액 등: 값이 전부 0 이상이면 Y축은 0부터, 위쪽만 여유.
      if (allNonNegative) {
        minY = 0;
        if (dataMax <= 0) {
          maxY = 1;
        } else {
          maxY = dataMax * 1.08;
        }
      } else {
        final span = (dataMax - dataMin).abs();
        final pad = span < 1e-6 ? 1.0 : span * 0.12;
        minY = dataMin - pad;
        maxY = dataMax + pad;
      }
    }

    if (minYOverride != null) minY = minYOverride!;
    if (maxYOverride != null) maxY = maxYOverride!;

    final lineBarsData = <LineChartBarData>[];
    for (final s in series) {
      lineBarsData.add(
        LineChartBarData(
          spots: [
            for (int i = 0; i < n; i++) FlSpot(i.toDouble(), s.values[i]),
          ],
          color: s.color,
          isCurved: true,
          curveSmoothness: 0.22,
          barWidth: 2.8,
          preventCurveOverShooting: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, p, bar, idx) => FlDotCirclePainter(
              radius: 4,
              color: s.color,
              strokeWidth: 2,
              strokeColor: cs.surface,
            ),
          ),
        ),
      );
    }

    final maxLeftChars = yAxisIsPercent
        ? 4
        : integerYAxis
            ? 3
            : 5;
    final maxBottomChars =
        dashboardChartMaxLabelChars(bottomLabels);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = DashboardChartMetrics(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          labelCount: n,
          maxLeftLabelChars: maxLeftChars,
          maxBottomLabelChars: maxBottomChars,
          deviceTextScale: context.deviceTextScale,
        );
        final tt = Theme.of(context).textTheme;

        return LineChart(
          LineChartData(
            minX: 0,
            maxX: n > 1 ? (n - 1).toDouble() : 1,
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _axisInterval(minY, maxY),
              getDrawingHorizontalLine: (value) => FlLine(
                color: cs.outlineVariant.withValues(alpha: 0.22),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: metrics.leftReserved,
                  interval: _axisInterval(minY, maxY),
                  getTitlesWidget: (value, meta) {
                    if (yAxisIsPercent) {
                      return metrics.leftAxisLabel(
                        '${value.round()}%',
                        cs: cs,
                        tt: tt,
                      );
                    }
                    if (integerYAxis) {
                      final iv = value.round();
                      if (iv < 0) return const SizedBox.shrink();
                      return metrics.leftAxisLabel('$iv', cs: cs, tt: tt);
                    }
                    return metrics.leftAxisLabel(
                      dashboardChartMoneyAxisLabel(value.round()),
                      cs: cs,
                      tt: tt,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: metrics.bottomReserved,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= n) return const SizedBox.shrink();
                    if (!metrics.showBottomLabelAt(i)) {
                      return const SizedBox.shrink();
                    }
                    return metrics.bottomAxisLabel(
                      bottomLabels[i],
                      cs: cs,
                      tt: tt,
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => cs.surfaceContainerHigh,
                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                  return touchedSpots.map((spot) {
                    final si = spot.barIndex;
                    final xi = spot.x.round().clamp(0, n - 1);
                    if (si < 0 || si >= series.length) {
                      return LineTooltipItem('', const TextStyle());
                    }
                    final s = series[si];
                    final val = s.values[xi];
                    final text = yAxisIsPercent
                        ? '${s.label}\n${val.toStringAsFixed(1)}%'
                        : integerYAxis
                            ? '${s.label}\n${val.round()}'
                            : '${s.label}\n${getPrice(price: val.round())}';
                    return LineTooltipItem(
                      text,
                      TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: metrics.tooltipFontSize,
                        height: 1.25,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: lineBarsData,
          ),
        );
      },
    );
  }
}

/// 범주(예: 1월~12월)별 **건수**용 막대 차트.
///
/// 빈도·이산 값 표현에는 선차트보다 막대가 적합합니다.
/// [BarChart]의 암시적 애니메이션으로 값 변경 시 또는 최초 표시 시 막대가 성장합니다.
class DashboardCountBarChart extends StatelessWidget {
  const DashboardCountBarChart({
    super.key,
    required this.bottomLabels,
    required this.values,
    required this.barColor,
    this.valueLabel = '근무 건수',
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  });

  final List<String> bottomLabels;
  final List<double> values;
  final Color barColor;

  /// 툴팁 등에 노출되는 지표 이름.
  final String valueLabel;

  final Duration animationDuration;
  final Curve animationCurve;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (bottomLabels.isEmpty) {
      return const Center(child: Text('데이터가 없습니다.'));
    }
    final n = bottomLabels.length;
    if (values.length != n) {
      return const Center(child: Text('차트 데이터 길이가 맞지 않습니다.'));
    }

    double dataMax = 0;
    for (final v in values) {
      if (v > dataMax) dataMax = v;
    }
    if (!dataMax.isFinite) dataMax = 0;
    final maxY = math.max(4.0, dataMax.ceilToDouble());

    final barGroups = <BarChartGroupData>[
      for (int i = 0; i < n; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              fromY: 0,
              toY: values[i].clamp(0, maxY),
              width: math.min(20, math.max(10, 220 / n)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
              color: barColor.withValues(alpha: 0.92),
            ),
          ],
        ),
    ];

    final maxBottomChars =
        dashboardChartMaxLabelChars(bottomLabels, fallback: 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = DashboardChartMetrics(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          labelCount: n,
          maxLeftLabelChars: math.max(2, maxY.ceil().toString().length),
          maxBottomLabelChars: maxBottomChars,
          deviceTextScale: context.deviceTextScale,
        );
        final tt = Theme.of(context).textTheme;

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            groupsSpace: 6,
            minY: 0,
            maxY: maxY,
            barGroups: barGroups,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _axisInterval(0, maxY),
              getDrawingHorizontalLine: (value) => FlLine(
                color: cs.outlineVariant.withValues(alpha: 0.22),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipPadding: ResponsiveLayout.symmetric(
                  context,
                  horizontal: 12,
                  vertical: 8,
                ),
                getTooltipColor: (_) =>
                    cs.surfaceContainerHigh.withValues(alpha: 0.98),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final i = group.x.toInt();
                  if (i < 0 || i >= n) return null;
                  final label = bottomLabels[i];
                  final count = rod.toY.round();
                  return BarTooltipItem(
                    '$label\n$valueLabel $count',
                    TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: metrics.tooltipFontSize,
                      height: 1.3,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: metrics.leftReserved,
                  interval: _axisInterval(0, maxY),
                  getTitlesWidget: (value, meta) {
                    final iv = value.round();
                    if (iv < 0 || iv > maxY.ceil()) {
                      return const SizedBox.shrink();
                    }
                    return metrics.leftAxisLabel(
                      '$iv',
                      cs: cs,
                      tt: tt,
                      padding: EdgeInsets.only(right: context.rsi(6)),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: metrics.bottomReserved,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i < 0 || i >= n) return const SizedBox.shrink();
                    if (!metrics.showBottomLabelAt(i)) {
                      return const SizedBox.shrink();
                    }
                    return metrics.bottomAxisLabel(
                      bottomLabels[i],
                      cs: cs,
                      tt: tt,
                    );
                  },
                ),
              ),
            ),
          ),
          duration: animationDuration,
          curve: animationCurve,
        );
      },
    );
  }
}

const double _kBarGroupRodWidth = 10;

/// [BarChart] 막대(영업이익) + [LineChart] 꺾은선(이익률) Stack.
/// 막대 `spaceEvenly` 중심 x를 plot 너비로 정규화해 선과 맞춤, 오버레이는 [IgnorePointer]로 터치는 막대 쪽.
/// 내장 [BarTouchTooltip]은 [LineChart] z-order에 가려지므로, 터치 시 상단 [Material] 배너로 표시.
class DashboardLineChartMoneyAndPercent extends StatefulWidget {
  const DashboardLineChartMoneyAndPercent({
    super.key,
    required this.bottomLabels,
    required this.moneyValues,
    required this.percentValues,
    this.moneyColor,
    this.percentColor,
    this.moneyLabel = '영업이익',
    this.percentLabel = '이익률',
  });

  final List<String> bottomLabels;
  final List<double> moneyValues;
  final List<double> percentValues;
  final Color? moneyColor;
  final Color? percentColor;
  final String moneyLabel;
  final String percentLabel;

  @override
  State<DashboardLineChartMoneyAndPercent> createState() =>
      _DashboardLineChartMoneyAndPercentState();
}

class _DashboardLineChartMoneyAndPercentState
    extends State<DashboardLineChartMoneyAndPercent> {
  int? _touchedIndex;

  void _onBarTouch(FlTouchEvent event, BarTouchResponse? response) {
    if (event is FlPanEndEvent ||
        event is FlTapUpEvent ||
        event is FlPointerExitEvent ||
        event is FlTapCancelEvent ||
        event is FlPanCancelEvent ||
        event is FlLongPressEnd) {
      setState(() => _touchedIndex = null);
      return;
    }
    final spot = response?.spot;
    if (spot != null) {
      setState(() => _touchedIndex = spot.touchedBarGroupIndex);
    } else {
      setState(() => _touchedIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // metric_sheet과 동일 톤: 청록(금액)·퍼플(이익률), 밝은 배경 대비
    const defaultMoney = Color(0xFF00897B);
    const defaultMargin = Color(0xFF8E24AA);
    final mc = widget.moneyColor ?? defaultMoney;
    final pc = widget.percentColor ?? defaultMargin;

    final bottomLabels = widget.bottomLabels;
    final moneyValues = widget.moneyValues;
    final percentValues = widget.percentValues;
    final moneyLabel = widget.moneyLabel;
    final percentLabel = widget.percentLabel;

    if (bottomLabels.isEmpty) {
      return const Center(child: Text('데이터가 없습니다.'));
    }
    final n = bottomLabels.length;
    if (moneyValues.length != n || percentValues.length != n) {
      return const Center(child: Text('차트 데이터 길이가 맞지 않습니다.'));
    }

    double dataMin = double.infinity;
    double dataMax = -double.infinity;
    for (final v in moneyValues) {
      if (!v.isFinite) continue;
      if (v > dataMax) dataMax = v;
      if (v < dataMin) dataMin = v;
    }
    if (!dataMin.isFinite) dataMin = 0;
    if (!dataMax.isFinite) dataMax = 1;
    if (dataMax < dataMin) dataMax = dataMin + 1;

    final bool allNonNegative = dataMin >= -1e-9;
    double minY;
    double maxY;
    if (allNonNegative) {
      minY = 0;
      if (dataMax <= 0) {
        maxY = 1;
      } else {
        maxY = dataMax * 1.08;
      }
    } else {
      final span = (dataMax - dataMin).abs();
      final pad = span < 1e-6 ? 1.0 : span * 0.12;
      minY = dataMin - pad;
      maxY = dataMax + pad;
    }

    final spanY = maxY - minY;

    double safeMoney(int i) {
      final v = moneyValues[i];
      return (v.isFinite) ? v : 0.0;
    }

    double safePctForY(int i) {
      final p = percentValues[i];
      if (!p.isFinite) return 0.0;
      return p.clamp(0.0, 100.0);
    }

    double yForPercent(double pct) {
      if (spanY <= 0) return minY;
      return minY + (pct / 100.0) * spanY;
    }

    final useCurve = n > 2;

    final maxBottomChars =
        dashboardChartMaxLabelChars(bottomLabels);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        if (!w.isFinite || w <= 0 || !h.isFinite || h <= 0) {
          return const SizedBox.shrink();
        }
        final metrics = DashboardChartMetrics(
          width: w,
          height: h,
          labelCount: n,
          hasRightAxis: true,
          maxLeftLabelChars: 5,
          maxBottomLabelChars: maxBottomChars,
          deviceTextScale: context.deviceTextScale,
        );
        final tt = Theme.of(context).textTheme;
        final leftPad = metrics.leftReserved;
        final rightPad = metrics.rightReserved;
        final bottomPad = metrics.bottomReserved;
        final plotW = math.max(1.0, w - leftPad - rightPad);

        final groupCenters = _barGroupCentersSpaceEvenly(
          viewWidth: plotW,
          count: n,
          groupContentWidth: _kBarGroupRodWidth,
        );
        if (groupCenters.length != n) {
          return const Center(child: Text('차트 구성 오류'));
        }

        final lineSpots = <FlSpot>[
          for (int i = 0; i < n; i++)
            FlSpot(
              groupCenters[i] / plotW,
              yForPercent(safePctForY(i)),
            ),
        ];

        final barGroups = <BarChartGroupData>[
          for (int i = 0; i < n; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  fromY: 0,
                  toY: safeMoney(i),
                  width: _kBarGroupRodWidth,
                  color: mc,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ],
            ),
        ];

        final barData = BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          groupsSpace: 4,
          minY: minY,
          maxY: maxY,
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _axisInterval(minY, maxY),
            getDrawingHorizontalLine: (value) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchCallback: _onBarTouch,
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: rightPad,
                interval: _axisInterval(minY, maxY),
                getTitlesWidget: (value, meta) {
                  if (spanY <= 1e-9) {
                    return const SizedBox.shrink();
                  }
                  final pct =
                      ((value - minY) / spanY * 100).round().clamp(0, 100);
                  return metrics.rightAxisLabel('$pct%', cs: cs, tt: tt);
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: leftPad,
                interval: _axisInterval(minY, maxY),
                getTitlesWidget: (value, meta) {
                  return metrics.leftAxisLabel(
                    dashboardChartMoneyAxisLabel(value.round()),
                    cs: cs,
                    tt: tt,
                    emphasis: true,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: bottomPad,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= n) return const SizedBox.shrink();
                  if (!metrics.showBottomLabelAt(i)) {
                    return const SizedBox.shrink();
                  }
                  return metrics.bottomAxisLabel(
                    bottomLabels[i],
                    cs: cs,
                    tt: tt,
                    emphasis: true,
                  );
                },
              ),
            ),
          ),
        );

        final ti = _touchedIndex;
        final showBanner = ti != null && ti >= 0 && ti < n;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            BarChart(barData, duration: Duration.zero),
            Positioned(
              left: leftPad,
              right: rightPad,
              bottom: bottomPad,
              top: 0,
              child: IgnorePointer(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 1,
                    minY: minY,
                    maxY: maxY,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: lineSpots,
                        color: pc,
                        isCurved: useCurve,
                        curveSmoothness: 0.22,
                        barWidth: 3.2,
                        preventCurveOverShooting: useCurve,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, p, bar, idx) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: pc,
                            strokeWidth: 2,
                            strokeColor: cs.surface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: Duration.zero,
                ),
              ),
            ),
            if (showBanner)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: ResponsiveLayout.only(context, left: 8, top: 4, right: 8),
                      child: Material(
                        elevation: 8,
                        shadowColor: Colors.black45,
                        color: cs.inverseSurface,
                        borderRadius: BorderRadius.circular(context.rs(12)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(context.rs(12)),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.35),
                            ),
                          ),
                          padding: ResponsiveLayout.symmetric(
                            context,
                            horizontal: 14,
                            vertical: 12,
                          ),
                          constraints: BoxConstraints(maxWidth: context.rs(220)),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: cs.onInverseSurface,
                                fontSize: metrics.tooltipFontSize,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                              children: [
                                TextSpan(
                                  text: '$moneyLabel\n',
                                  style: TextStyle(
                                    color: mc,
                                    fontWeight: FontWeight.w800,
                                    fontSize: metrics.tooltipFontSize,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '${getPrice(price: safeMoney(ti).round())}\n',
                                  style: TextStyle(
                                    color: cs.onInverseSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: metrics.tooltipFontSize + 1,
                                  ),
                                ),
                                TextSpan(
                                  text: '\n$percentLabel ',
                                  style: TextStyle(
                                    color: pc,
                                    fontWeight: FontWeight.w800,
                                    fontSize: metrics.tooltipFontSize,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '${safePctForY(ti).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: cs.onInverseSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: metrics.tooltipFontSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// [BarChartAlignment.spaceEvenly]과 동일: 그룹 너비 합 + 남는 폭을 (n+1)등분.
List<double> _barGroupCentersSpaceEvenly({
  required double viewWidth,
  required int count,
  required double groupContentWidth,
}) {
  if (count <= 0) return const [];
  final sumWidth = groupContentWidth * count;
  if (viewWidth < sumWidth) {
    // 좁을 때: 중앙 정렬 1칸씩
    return List<double>.generate(
      count,
      (i) => (i + 0.5) * viewWidth / count,
    );
  }
  final eachSpace = (viewWidth - sumWidth) / (count + 1);
  final out = <double>[];
  var tempX = 0.0;
  for (var i = 0; i < count; i++) {
    tempX += eachSpace;
    tempX += groupContentWidth / 2;
    out.add(tempX);
    tempX += groupContentWidth / 2;
  }
  return out;
}
