import 'package:flutter/material.dart';
import 'package:w0001/domain/place_work_day_cross_place_conflict.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 다른 현장 동일 날짜 투입 충돌 안내.
///
/// * false — 취소
/// * true — 충돌 인력 포함 전원 투입
enum CrossPlaceConflictChoice { cancel, proceedAll }

Future<CrossPlaceConflictChoice?> showCrossPlaceWorkDayConflictDialog(
  BuildContext context, {
  required String workdateLabel,
  required String currentPlaceName,
  required List<CrossPlaceWorkDayConflict> conflicts,
}) {
  return showDialog<CrossPlaceConflictChoice>(
    context: context,
    builder: (ctx) {
      final lines = <Widget>[
        Text(
          '$workdateLabel · 「$currentPlaceName」에 투입하려는 인력 중 '
          '아래 분은 같은 날 다른 현장에 이미 등록되어 있습니다.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        SizedBox(height: ctx.rsi(12)),
      ];
      for (final c in conflicts) {
        final places = c.assignments.map((a) {
          final role = a.workrole.isNotEmpty ? ' (${a.workrole})' : '';
          return '· ${a.placeName}$role';
        }).join('\n');
        lines.add(
          Padding(
            padding: EdgeInsets.only(bottom: ctx.rsi(10)),
            child: Text(
              '${c.humanName}\n$places',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        );
      }
      return AlertDialog(
        title: const Text('다른 현장 투입 확인'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: lines,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, CrossPlaceConflictChoice.cancel),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, CrossPlaceConflictChoice.proceedAll),
            child: const Text('그래도 투입'),
          ),
        ],
      );
    },
  );
}
