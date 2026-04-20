import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:w0001/util/funtions.dart';

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
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: _axisInterval(minY, maxY),
              getTitlesWidget: (value, meta) {
                if (yAxisIsPercent) {
                  return Text(
                    '${value.round()}%',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  );
                }
                if (integerYAxis) {
                  final iv = value.round();
                  if (iv < 0) return const SizedBox.shrink();
                  return Text(
                    '$iv',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  );
                }
                final iv = value.round();
                String label;
                if (iv.abs() >= 100000000) {
                  label = '${(iv / 100000000).toStringAsFixed(0)}억';
                } else if (iv.abs() >= 10000) {
                  label = '${(iv / 10000).toStringAsFixed(0)}만';
                } else {
                  label = '$iv';
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= n) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    bottomLabels[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
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
                    fontSize: 11,
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
  }
}
