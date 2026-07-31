import 'package:flutter/material.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/util/responsive_layout.dart';

class BulkProcessSelectionCard extends StatelessWidget {
  const BulkProcessSelectionCard({
    super.key,
    required this.taskName,
    required this.dateLabel,
    required this.isSelected,
    required this.isCompleted,
    required this.isPartial,
    required this.onTap,
    this.statusBar,
  });

  final String taskName;
  final String dateLabel;
  final bool isSelected;
  final bool isCompleted;
  final bool isPartial;
  final VoidCallback onTap;
  final Widget? statusBar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: isSelected
          ? cs.primaryContainer.withValues(alpha: 0.35)
          : cs.surfaceContainerLow.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(12)),
        side: BorderSide(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.45)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.rsi(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_outline
                        : isPartial
                            ? Icons.schedule_outlined
                            : Icons.engineering_outlined,
                    size: context.rs(18),
                    color: cs.onSurfaceVariant,
                  ),
                  SizedBox(width: context.rsi(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                taskName,
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCompleted) const BulkStatusChip(label: '완료'),
                            if (isPartial && !isCompleted)
                              const BulkStatusChip(label: '진행'),
                          ],
                        ),
                        SizedBox(height: context.rsi(4)),
                        Text(
                          dateLabel,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: context.rs(20),
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              if (statusBar != null) ...[
                SizedBox(height: context.rsi(10)),
                statusBar!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class BulkStatusChip extends StatelessWidget {
  const BulkStatusChip({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.only(left: context.rsi(6)),
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(7),
        vertical: context.rsi(2),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rs(6)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class BulkEmptyProcessList extends StatelessWidget {
  const BulkEmptyProcessList({
    super.key,
    required this.onSelectDateDirectly,
  });

  final VoidCallback onSelectDateDirectly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(context.rsi(28)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(context.rs(12)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            size: context.rs(40),
            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
          ),
          SizedBox(height: context.rsi(10)),
          Text(
            '등록된 공정이 없습니다',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.rsi(4)),
          Text(
            '새 공정을 추가하거나 날짜를 직접 선택하세요',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.rsi(14)),
          OutlinedButton.icon(
            onPressed: onSelectDateDirectly,
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('날짜 직접 선택'),
          ),
        ],
      ),
    );
  }
}

class BulkWorkerSearchEmptyState extends StatelessWidget {
  const BulkWorkerSearchEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: context.rs(200)),
      child: Container(
        width: double.infinity,
        padding: ResponsiveLayout.all(context, 32),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(context.rs(16)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.rs(48),
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            SizedBox(height: context.rsi(12)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (subtitle != null) ...[
              SizedBox(height: context.rsi(6)),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BulkWorkerGridItem extends StatelessWidget {
  const BulkWorkerGridItem({
    super.key,
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.workRole,
    this.wageLabel,
    this.primarySpecialty,
  });

  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? workRole;
  final String? wageLabel;
  final String? primarySpecialty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final leading = name.isNotEmpty ? name[0] : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(context.rs(10)),
        child: Container(
          padding: EdgeInsets.all(context.rsi(8)),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.06)
                : cs.surfaceContainerLow.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(context.rs(10)),
            border: Border.all(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.65)
                  : cs.outlineVariant.withValues(alpha: 0.45),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: context.rs(14),
                    backgroundColor: isSelected
                        ? cs.primary.withValues(alpha: 0.12)
                        : cs.surfaceContainerHighest,
                    child: Text(
                      leading,
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      size: context.rs(14),
                      color: cs.primary,
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: context.rs(12),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.rsi(2)),
                  if (isSelected) ...[
                    if (workRole != null)
                      Text(
                        workRole!,
                        style: tt.labelSmall?.copyWith(
                          fontSize: context.rs(10),
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (wageLabel != null)
                      Text(
                        wageLabel!,
                        style: tt.labelSmall?.copyWith(
                          fontSize: context.rs(10),
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ] else if (primarySpecialty != null)
                    Text(
                      primarySpecialty!,
                      style: tt.labelSmall?.copyWith(
                        fontSize: context.rs(10),
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BulkAssignmentSummaryCard extends StatelessWidget {
  const BulkAssignmentSummaryCard({
    super.key,
    required this.dayCount,
    required this.workerCount,
    required this.totalAssignments,
    required this.periodLabel,
  });

  final int dayCount;
  final int workerCount;
  final int totalAssignments;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(context.rsi(14)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(context.rs(12)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$dayCount일간 $workerCount명 일괄 투입',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.rsi(4)),
          Text(
            '총 $totalAssignments품이 생성됩니다',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.rsi(12)),
          _BulkSummaryRow(
            icon: Icons.calendar_today_outlined,
            label: '기간',
            value: periodLabel,
          ),
          Divider(
              height: context.rsi(20),
              color: cs.outlineVariant.withValues(alpha: 0.4)),
          _BulkSummaryRow(
            icon: Icons.group_outlined,
            label: '인력',
            value: '$workerCount명',
          ),
          Divider(
              height: context.rsi(20),
              color: cs.outlineVariant.withValues(alpha: 0.4)),
          _BulkSummaryRow(
            icon: Icons.assignment_outlined,
            label: '생성 품수',
            value: '$totalAssignments품',
          ),
        ],
      ),
    );
  }
}

class BulkSelectedWorkersDetailCard extends StatelessWidget {
  const BulkSelectedWorkersDetailCard({
    super.key,
    required this.workers,
    required this.dayCount,
  });

  final List<BulkSelectedWorkerDetail> workers;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(context.rs(10)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(12),
              context.rsi(10),
              context.rsi(12),
              context.rsi(8),
            ),
            child: Text(
              '투입 인력 상세',
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          ...workers.map((worker) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.rsi(12),
                vertical: context.rsi(10),
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: context.rs(14),
                    backgroundColor: cs.surfaceContainerHighest,
                    child: Text(
                      worker.leadingChar,
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(width: context.rsi(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker.name,
                          style: tt.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          worker.workRole,
                          style: tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(worker.wage / 10000).toStringAsFixed(0)}만원',
                        style:
                            tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '× $dayCount일',
                        style:
                            tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class BulkSelectedWorkerDetail {
  const BulkSelectedWorkerDetail({
    required this.human,
    required this.workRole,
    required this.wage,
  });

  final HumanModel human;
  final String workRole;
  final int wage;

  String get name => human.hname;
  String get leadingChar => human.hname.isNotEmpty ? human.hname[0] : '?';
}

class _BulkSummaryRow extends StatelessWidget {
  const _BulkSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, color: cs.onSurfaceVariant, size: context.rs(18)),
        SizedBox(width: context.rsi(10)),
        Expanded(
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class BulkWorkInstructionSection extends StatelessWidget {
  const BulkWorkInstructionSection({
    super.key,
    required this.hasInstruction,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onClear,
  });

  final bool hasInstruction;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(context.rs(12)),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(context.rs(12)),
              bottom: expanded ? Radius.zero : Radius.circular(context.rs(12)),
            ),
            child: Padding(
              padding: ResponsiveLayout.all(context, 16),
              child: Row(
                children: [
                  Icon(Icons.assignment_outlined,
                      color: cs.onSurfaceVariant, size: context.rs(18)),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '전체 작업지시 (선택사항)',
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (hasInstruction && !expanded) ...[
                          SizedBox(height: context.rsi(4)),
                          Text(
                            '작업지시가 입력되었습니다',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: ResponsiveLayout.all(context, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasInstruction) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: cs.onSurfaceVariant,
                          size: context.rs(16),
                        ),
                        SizedBox(width: context.rsi(8)),
                        Text(
                          '작업지시가 저장되었습니다',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.rsi(12)),
                  ],
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: Icon(
                      hasInstruction ? Icons.edit : Icons.add,
                      size: context.rs(18),
                    ),
                    label: Text(hasInstruction ? '작업지시 수정' : '작업지시 작성'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(context.rs(40)),
                    ),
                  ),
                  if (hasInstruction) ...[
                    SizedBox(height: context.rsi(8)),
                    TextButton.icon(
                      onPressed: onClear,
                      icon: Icon(Icons.delete_outline, size: context.rs(16)),
                      label: const Text('작업지시 삭제'),
                      style: TextButton.styleFrom(foregroundColor: cs.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
