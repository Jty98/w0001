import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인건비 조회 — 역할·공정 라벨 칩 (이름·현장명 옆 인라인).
class WorkCostRoleChip extends StatelessWidget {
  const WorkCostRoleChip({
    super.key,
    required this.label,
    this.toned = false,
  });

  final String label;
  final bool toned;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final text = label.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final bg = toned
        ? cs.primary
        : cs.primaryContainer.withValues(alpha: 0.5);
    final fg = toned ? cs.onPrimary : cs.onPrimaryContainer;
    final border = toned
        ? Colors.transparent
        : cs.primary.withValues(alpha: 0.22);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(7),
        vertical: context.rsi(3),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.05,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

/// 인건비 일별 항목 — 작업지시·공정표 연동 공정명 (레거시 세로 배치).
class WorkCostProcessMeta extends StatelessWidget {
  const WorkCostProcessMeta({
    super.key,
    required this.workrole,
  });

  final String workrole;

  @override
  Widget build(BuildContext context) {
    final role = workrole.trim();
    if (role.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(top: context.rsi(5)),
      child: Row(
        children: [
          Icon(
            Icons.engineering_outlined,
            size: context.rs(13),
            color: cs.primary.withValues(alpha: 0.9),
          ),
          SizedBox(width: context.rsi(5)),
          Flexible(child: WorkCostRoleChip(label: role)),
        ],
      ),
    );
  }
}
