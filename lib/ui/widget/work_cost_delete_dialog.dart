import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// [showWorkCostDeleteDialog] 결과.
enum WorkCostDeleteChoice {
  cancel,
  /// 인건비만 삭제(연결된 작업 투입 없음).
  costOnly,
  /// 인건비 + 작업 투입(place-work-days) 함께 삭제.
  costAndWorkDay,
}

/// 인건비 삭제 전 확인. 작업 투입이 있으면 함께 삭제 여부를 안내한다.
Future<WorkCostDeleteChoice?> showWorkCostDeleteDialog(
  BuildContext context, {
  required String placeName,
  required String workerName,
  required String dateLabel,
  required bool hasLinkedWorkDay,
  String? workrole,
}) {
  final role = workrole?.trim();
  final roleLine = role != null && role.isNotEmpty ? '\n공정: $role' : '';

  return showDialog<WorkCostDeleteChoice>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      if (hasLinkedWorkDay) {
        return AlertDialog(
          title: const Text('인건비·작업 투입 삭제'),
          content: Text(
            '$workerName · $placeName\n$dateLabel$roleLine\n\n'
            '이 날짜에 등록된 작업지시(현장 투입) 내역이 있습니다.\n'
            '인건비만 지우면 작업 기록과 금액이 어긋날 수 있어, '
            '함께 삭제하는 것을 권장합니다.',
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: cs.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(WorkCostDeleteChoice.cancel),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => ctx.pop(WorkCostDeleteChoice.costAndWorkDay),
              child: Text(
                '함께 삭제',
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      }

      return AlertDialog(
        title: const Text('인건비 삭제'),
        content: Text(
          '$workerName · $placeName\n$dateLabel$roleLine\n\n'
          '이 인건비 항목을 삭제할까요?',
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
            height: 1.45,
            color: cs.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(WorkCostDeleteChoice.cancel),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => ctx.pop(WorkCostDeleteChoice.costOnly),
            child: Text(
              '삭제',
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );
}
