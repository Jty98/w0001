import 'package:flutter/material.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 캘린더 접힘 시 — 날짜 이동 + 펼치기 (한 줄).
class PlaceWorkforceCalendarCollapsedBar extends StatelessWidget {
  const PlaceWorkforceCalendarCollapsedBar({
    super.key,
    required this.selectedDay,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onExpand,
  });

  final DateTime selectedDay;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onExpand;

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final wd = getWeekDay(day.weekday);
    if (day.year == now.year) {
      return '${day.month}월 ${day.day}일($wd)';
    }
    return '${day.year}.${day.month}.${day.day}($wd)';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(4),
          context.rsi(4),
          context.rsi(4),
          context.rsi(4),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: '이전 날',
              onPressed: onPreviousDay,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.chevron_left_rounded, size: context.rs(26)),
            ),
            Expanded(
              child: Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(context.rs(12)),
                child: InkWell(
                  onTap: onExpand,
                  borderRadius: BorderRadius.circular(context.rs(12)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rsi(12),
                      vertical: context.rsi(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: context.rs(18),
                          color: cs.primary,
                        ),
                        SizedBox(width: context.rsi(8)),
                        Flexible(
                          child: Text(
                            _dayLabel(selectedDay),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: tt.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(width: context.rsi(6)),
                        Text(
                          '펼치기',
                          style: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                        Icon(
                          Icons.expand_more_rounded,
                          size: context.rs(18),
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '다음 날',
              onPressed: onNextDay,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.chevron_right_rounded, size: context.rs(26)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 캘린더 펼침 시 — 바로 아래 「캘린더 접기」.
class PlaceWorkforceCalendarCollapseBar extends StatelessWidget {
  const PlaceWorkforceCalendarCollapseBar({
    super.key,
    required this.onCollapse,
  });

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onCollapse,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(12),
            vertical: context.rsi(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: context.rs(20),
                color: cs.primary,
              ),
              SizedBox(width: context.rsi(4)),
              Text(
                '캘린더 접기 · 목록 공간 확보',
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
