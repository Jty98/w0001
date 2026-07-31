import 'package:flutter/material.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

/// 인건비 조회 — 칩 종류 (현장 역할 vs 주특기 vs 공정명).
enum WorkCostChipKind {
  process,
  siteRank,
  primarySpecialty,
}

/// 인건비 조회 — 역할·공정 라벨 칩 (이름·현장명 옆 인라인).
class WorkCostRoleChip extends StatelessWidget {
  const WorkCostRoleChip({
    super.key,
    required this.label,
    this.toned = false,
    this.kind = WorkCostChipKind.process,
    this.appBar = false,
  });

  final String label;
  final bool toned;
  final WorkCostChipKind kind;
  final bool appBar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final text = label.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    late final Color bg;
    late final Color fg;
    late final Color border;

    if (toned) {
      bg = cs.primary;
      fg = cs.onPrimary;
      border = Colors.transparent;
    } else {
      switch (kind) {
        case WorkCostChipKind.siteRank:
          bg = cs.secondaryContainer.withValues(alpha: 0.72);
          fg = cs.onSecondaryContainer;
          border = cs.secondary.withValues(alpha: 0.28);
        case WorkCostChipKind.primarySpecialty:
          bg = cs.primaryContainer.withValues(alpha: 0.55);
          fg = cs.onPrimaryContainer;
          border = cs.primary.withValues(alpha: 0.24);
        case WorkCostChipKind.process:
          bg = cs.primaryContainer.withValues(alpha: 0.5);
          fg = cs.onPrimaryContainer;
          border = cs.primary.withValues(alpha: 0.22);
      }
    }

    final caption = switch (kind) {
      WorkCostChipKind.siteRank => '역할',
      WorkCostChipKind.primarySpecialty => '주특기',
      WorkCostChipKind.process => null,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(appBar ? 5 : 7),
        vertical: context.rsi(appBar ? 2 : 3),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption != null) ...[
            Text(
              caption,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: fg.withValues(alpha: 0.72),
                height: 1.0,
                fontSize: context.rs(appBar ? 9 : 10),
              ),
            ),
            SizedBox(width: context.rsi(appBar ? 3 : 4)),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: appBar ? 2 : 1,
              overflow: TextOverflow.fade,
              softWrap: true,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
                height: 1.05,
                letterSpacing: -0.1,
                fontSize: context.rs(appBar ? 10 : 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 인건비 사람 목록 — 이름 옆 현장 역할·주특기 배지.
class WorkCostHumanBadges extends StatelessWidget {
  const WorkCostHumanBadges({
    super.key,
    required this.human,
    this.dense = false,
    this.appBar = false,
  });

  final HumanModel human;
  final bool dense;
  final bool appBar;

  @override
  Widget build(BuildContext context) {
    final badges = resolveHumanWorkCostBadges(human);
    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: (dense || appBar) ? 0 : context.rsi(4)),
      child: Wrap(
        spacing: context.rsi(appBar ? 4 : 5),
        runSpacing: context.rsi(appBar ? 3 : 4),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (badges.siteRank != null && badges.siteRank!.isNotEmpty)
            WorkCostRoleChip(
              label: badges.siteRank!,
              kind: WorkCostChipKind.siteRank,
              appBar: appBar,
            ),
          if (badges.primarySpecialty != null &&
              badges.primarySpecialty!.isNotEmpty)
            WorkCostRoleChip(
              label: badges.primarySpecialty!,
              kind: WorkCostChipKind.primarySpecialty,
              appBar: appBar,
            ),
        ],
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
