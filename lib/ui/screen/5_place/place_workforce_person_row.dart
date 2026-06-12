import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인력·투입 화면 하단 리스트의 한 명 행.
class PlaceWorkforcePersonRow extends StatelessWidget {
  const PlaceWorkforcePersonRow({
    super.key,
    required this.name,
    required this.wageLabel,
    required this.settled,
    required this.canEdit,
    this.roleLabel,
    this.hasWorkInstruction = false,
    this.onEdit,
    this.onDelete,
    this.showBottomDivider = true,
  });

  final String name;
  final String wageLabel;
  final bool settled;

  /// 공정 카드 안에서는 생략하고, 기타 투입에서는 역할 문자열.
  final String? roleLabel;

  /// Quill 기반 작업 내용(텍스트·이미지)가 비어 있지 않을 때.
  final bool hasWorkInstruction;

  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final bool showBottomDivider;

  static String _initialLetter(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '?';
    final i = t.runes.iterator;
    return i.moveNext() ? String.fromCharCode(i.current) : '?';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final letter = _initialLetter(name);
    final showActions = canEdit && onEdit != null && onDelete != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showBottomDivider
            ? Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(14),
          context.rsi(12),
          context.rsi(8),
          context.rsi(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: context.rs(22),
              backgroundColor: cs.primaryContainer.withValues(alpha: 0.65),
              foregroundColor: cs.onPrimaryContainer,
              child: Text(
                letter,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(width: context.rsi(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (roleLabel != null && roleLabel!.trim().isNotEmpty) ...[
                    SizedBox(height: context.rsi(3)),
                    Text(
                      roleLabel!.trim(),
                      maxLines: 2,
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                  SizedBox(height: context.rsi(8)),
                  Wrap(
                    spacing: context.rsi(8),
                    runSpacing: context.rsi(6),
                    children: [
                      _InfoChip(
                        icon: Icons.payments_outlined,
                        label: wageLabel,
                        color: cs.secondaryContainer,
                        onColor: cs.onSecondaryContainer,
                      ),
                      _InfoChip(
                        icon: settled
                            ? Icons.check_circle_outline
                            : Icons.schedule_outlined,
                        label: settled ? '정산 완료' : '미정산',
                        color: settled
                            ? cs.tertiaryContainer.withValues(alpha: 0.85)
                            : cs.errorContainer.withValues(alpha: 0.55),
                        onColor: settled
                            ? cs.onTertiaryContainer
                            : cs.onErrorContainer,
                      ),
                      if (hasWorkInstruction)
                        _InfoChip(
                          icon: Icons.edit_note_rounded,
                          label: '작업 내용',
                          color: cs.primaryContainer
                              .withValues(alpha: 0.82),
                          onColor: cs.onPrimaryContainer,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (showActions) ...[
              SizedBox(width: context.rsi(4)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: '수정',
                    constraints: BoxConstraints(
                      minWidth: context.rs(40),
                      minHeight: context.rs(40),
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, size: context.rs(20)),
                  ),
                  SizedBox(height: context.rsi(4)),
                  IconButton.filledTonal(
                    tooltip: '삭제',
                    constraints: BoxConstraints(
                      minWidth: context.rs(40),
                      minHeight: context.rs(40),
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      foregroundColor: cs.error,
                      backgroundColor:
                          cs.errorContainer.withValues(alpha: 0.45),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded,
                        size: context.rs(20)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(10),
        vertical: context.rsi(5),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.rs(14), color: onColor),
          SizedBox(width: context.rsi(5)),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: onColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공정별 카드·기타 투입 블록 상단 제목 줄.
class PlaceWorkforceSectionLabel extends StatelessWidget {
  const PlaceWorkforceSectionLabel({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: context.rsi(4),
        bottom: context.rsi(10),
        top: context.rsi(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: context.rs(20), color: cs.primary),
          SizedBox(width: context.rsi(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 선택한 날짜에 표시할 빈 상태.
class PlaceWorkforceEmptyDay extends StatelessWidget {
  const PlaceWorkforceEmptyDay({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.rsi(36),
        horizontal: context.rsi(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.groups_outlined,
            size: context.rs(52),
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          SizedBox(height: context.rsi(14)),
          Text(
            '이 날짜에 투입된 인력이 없습니다',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: context.rsi(6)),
          Text(
            '공정 카드에서 「인력 투입」으로 추가할 수 있어요.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(
              height: 1.35,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
