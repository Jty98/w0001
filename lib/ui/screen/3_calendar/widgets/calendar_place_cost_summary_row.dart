import 'package:flutter/material.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/calendar_view_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

const Color _workColor = Color(0xFF1976D2);
const Color _materialColor = Color(0xFFE65100);
const Color _paidColor = Color(0xFF5C6BC0);

/// 접힌 현장 타일 — 합계 바 + 2×2 메트릭 (컴팩트·만/억 축약).
class CalendarPlaceCostSummaryPanel extends StatelessWidget {
  const CalendarPlaceCostSummaryPanel({
    super.key,
    required this.placeName,
    required this.isPlaceComplete,
    required this.summary,
    required this.selectedFilterType,
    required this.filteredAmount,
  });

  final String placeName;
  final bool isPlaceComplete;
  final PlaceDayCostSummary summary;
  final FilterType selectedFilterType;
  final int filteredAmount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlaceNameRow(
          placeName: placeName,
          isPlaceComplete: isPlaceComplete,
        ),
        SizedBox(height: context.rsi(6)),
        _CompactTotalBar(summary: summary),
        SizedBox(height: context.rsi(5)),
        if (selectedFilterType == FilterType.all)
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(context.rs(8)),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.rs(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MetricCell(
                          label: '인건비',
                          amount: summary.workAmount,
                          accent: _workColor,
                        ),
                        const _MetricDivider(),
                        _MetricCell(
                          label: '자재',
                          amount: summary.materialAmount,
                          accent: _materialColor,
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MetricCell(
                          label: '지급',
                          amount: summary.paidAmount,
                          accent: _paidColor,
                        ),
                        const _MetricDivider(),
                        _MetricCell(
                          label: '미지급',
                          amount: summary.unpaidAmount,
                          accent: summary.unpaidAmount > 0
                              ? cs.error
                              : cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _SelectedMetricBar(
            label: selectedFilterType.category,
            amount: filteredAmount,
            accent: _filterAccent(
              selectedFilterType,
              cs: cs,
              summary: summary,
            ),
          ),
      ],
    );
  }
}

Color _filterAccent(
  FilterType filterType, {
  required ColorScheme cs,
  required PlaceDayCostSummary summary,
}) {
  switch (filterType) {
    case FilterType.work:
      return _workColor;
    case FilterType.material:
      return _materialColor;
    case FilterType.notPay:
      return summary.unpaidAmount > 0 ? cs.error : cs.onSurfaceVariant;
    default:
      return cs.primary;
  }
}

class _PlaceNameRow extends StatelessWidget {
  const _PlaceNameRow({
    required this.placeName,
    required this.isPlaceComplete,
  });

  final String placeName;
  final bool isPlaceComplete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            placeName,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isPlaceComplete) ...[
          SizedBox(width: context.rsi(6)),
          Text(
            '완료',
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactTotalBar extends StatelessWidget {
  const _CompactTotalBar({required this.summary});

  final PlaceDayCostSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final amount = summary.totalAmount;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rs(8)),
        color: cs.primaryContainer.withValues(alpha: 0.42),
        border: Border.all(color: cs.primary.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: ResponsiveLayout.symmetric(
          context,
          horizontal: 10,
          vertical: 6,
        ),
        child: Row(
          children: [
            Text(
              '합계',
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
            ),
            SizedBox(width: context.rsi(4)),
            Text(
              '인건비+자재',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 10,
                height: 1.0,
              ),
            ),
            const Spacer(),
            _CompactAmountText(
              amount: amount,
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.0,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 축약 표기 + 길게 누르면 [getPrice] 전체 금액.
class _CompactAmountText extends StatelessWidget {
  const _CompactAmountText({
    required this.amount,
    required this.style,
    this.color,
    this.alignment = Alignment.centerRight,
  });

  final int amount;
  final TextStyle? style;
  final Color? color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final textStyle = color != null ? style?.copyWith(color: color) : style;

    return Tooltip(
      message: getPrice(price: amount),
      preferBelow: false,
      child: Text(
        formatCompactKrw(amount),
        style: textStyle,
        textAlign: alignment == Alignment.center
            ? TextAlign.center
            : (alignment == Alignment.centerLeft
                ? TextAlign.left
                : TextAlign.right),
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.amount,
    required this.accent,
  });

  final String label;
  final int amount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: Padding(
        padding: ResponsiveLayout.symmetric(
          context,
          horizontal: 8,
          vertical: 7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                fontSize: 10,
                height: 1.0,
                color: accent,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
            ),
            SizedBox(height: context.rsi(3)),
            _CompactAmountText(
              amount: amount,
              color: accent,
              alignment: Alignment.center,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedMetricBar extends StatelessWidget {
  const _SelectedMetricBar({
    required this.label,
    required this.amount,
    required this.accent,
  });

  final String label;
  final int amount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(context.rs(8)),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: ResponsiveLayout.symmetric(
          context,
          horizontal: 10,
          vertical: 8,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const Spacer(),
            _CompactAmountText(
              amount: amount,
              color: accent,
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
