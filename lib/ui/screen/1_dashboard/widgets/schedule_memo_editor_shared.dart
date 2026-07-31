import 'dart:ui' show FontFeature;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

TimeOfDay? parseScheduleMemoTaskTime(String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  final p = v.split(':');
  if (p.length != 2) return null;
  final hour = int.tryParse(p[0]);
  final minute = int.tryParse(p[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String scheduleMemoTimeToKey(TimeOfDay t) {
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

Future<TimeOfDay?> pickScheduleMemoTaskTime(
  BuildContext context,
  TimeOfDay? initial,
) async {
  final now = DateTime.now();
  final init = initial ?? TimeOfDay.now();
  var selected = DateTime(
    now.year,
    now.month,
    now.day,
    init.hour,
    init.minute,
  );

  final picked = await showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          var pickerResetKey = 0;
          void applyQuickMinute(int minute) {
            final base = selected;
            setModalState(() {
              selected = DateTime(
                base.year,
                base.month,
                base.day,
                base.hour,
                minute,
              );
              pickerResetKey++;
            });
          }

          return SizedBox(
            height: ctx.rs(360),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    ctx.rsi(16),
                    ctx.rsi(8),
                    ctx.rsi(16),
                    0,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('취소'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, selected),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    ctx.rsi(16),
                    ctx.rsi(8),
                    ctx.rsi(16),
                    0,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(ctx.rsi(4)),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(ctx.rs(12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => applyQuickMinute(0),
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              backgroundColor: selected.minute == 0
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Colors.transparent,
                              foregroundColor: selected.minute == 0
                                  ? Theme.of(ctx).colorScheme.onPrimary
                                  : Theme.of(ctx).colorScheme.onSurfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ctx.rs(10)),
                              ),
                            ),
                            child: const Text('정각'),
                          ),
                        ),
                        SizedBox(width: ctx.rsi(6)),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => applyQuickMinute(30),
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              backgroundColor: selected.minute == 30
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Colors.transparent,
                              foregroundColor: selected.minute == 30
                                  ? Theme.of(ctx).colorScheme.onPrimary
                                  : Theme.of(ctx).colorScheme.onSurfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ctx.rs(10)),
                              ),
                            ),
                            child: const Text('반'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    key: ValueKey(
                      '${selected.hour}-${selected.minute}-$pickerResetKey',
                    ),
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: selected,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  if (picked == null) return null;
  return TimeOfDay(hour: picked.hour, minute: picked.minute);
}

String normalizeScheduleMemoBulletText(String raw) {
  final lines = raw
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => e.startsWith('- ') ? e : '- $e')
      .toList();
  return lines.join('\n');
}

/// 일정 목록·카드 — 제목 오른쪽에 시각(HH:mm) 고정 너비 정렬.
Widget scheduleMemoListTitleRow(
  BuildContext context, {
  required String title,
  required String tasktimeRaw,
  TextStyle? titleStyle,
  int titleMaxLines = 2,
}) {
  final time = _scheduleMemoListTimeText(context, tasktimeRaw);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          title,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
      ),
      if (time != null) ...[
        SizedBox(width: context.rsi(10)),
        time,
      ],
    ],
  );
}

Widget? _scheduleMemoListTimeText(BuildContext context, String tasktimeRaw) {
  final t = tasktimeRaw.trim();
  if (t.isEmpty) return null;

  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final asClock = parseScheduleMemoTaskTime(t);

  return SizedBox(
    width: context.rs(52),
    child: Text(
      t,
      textAlign: TextAlign.end,
      style: (asClock != null ? tt.labelLarge : tt.labelMedium)?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: asClock != null ? cs.onSurfaceVariant : cs.outline,
        height: 1.25,
      ),
    ),
  );
}
