import 'package:flutter/material.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_section_card.dart';
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
    this.compact = false,
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

  /// 공정 카드 안 인원 목록 — 패딩·아바타를 줄인다.
  final bool compact;

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
    final avatarR = compact ? context.rs(16) : context.rs(22);
    final hPad = compact ? context.rsi(10) : context.rsi(14);
    final vPad = compact ? context.rsi(8) : context.rsi(12);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showBottomDivider
            ? Border(
                bottom: BorderSide(
                  color: cs.appDivider,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, vPad, context.rsi(8), vPad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: avatarR,
              backgroundColor: cs.appIconBadge,
              foregroundColor: cs.primary,
              child: Text(
                letter,
                style: (compact ? tt.labelLarge : tt.titleSmall)?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: context.rsi(compact ? 10 : 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: (compact ? tt.labelLarge : tt.bodyMedium)?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (roleLabel != null && roleLabel!.trim().isNotEmpty) ...[
                    SizedBox(height: context.rsi(compact ? 2 : 3)),
                    Text(
                      roleLabel!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ],
                  SizedBox(height: context.rsi(compact ? 5 : 8)),
                  Wrap(
                    spacing: context.rsi(compact ? 5 : 8),
                    runSpacing: context.rsi(compact ? 4 : 6),
                    children: [
                      _InfoChip(
                        icon: Icons.payments_outlined,
                        label: wageLabel,
                        color: cs.secondaryContainer,
                        onColor: cs.onSecondaryContainer,
                        compact: compact,
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
                        compact: compact,
                      ),
                      if (hasWorkInstruction)
                        _InfoChip(
                          icon: Icons.edit_note_rounded,
                          label: '작업 내용',
                          color: cs.appIconBadge,
                          onColor: cs.primary,
                          compact: compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (showActions) ...[
              SizedBox(width: context.rsi(2)),
              if (compact)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '수정',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: context.rs(36),
                        minHeight: context.rs(36),
                      ),
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, size: context.rs(18)),
                    ),
                    IconButton(
                      tooltip: '삭제',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: context.rs(36),
                        minHeight: context.rs(36),
                      ),
                      style: IconButton.styleFrom(foregroundColor: cs.error),
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: context.rs(18),
                      ),
                    ),
                  ],
                )
              else
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
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(compact ? 7 : 10),
        vertical: context.rsi(compact ? 3 : 5),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.appBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.rs(compact ? 12 : 14), color: onColor),
          SizedBox(width: context.rsi(compact ? 4 : 5)),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: onColor,
              height: 1.1,
              fontSize: compact ? 11 : null,
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
        bottom: context.rsi(6),
        top: context.rsi(2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.rs(32),
            height: context.rs(32),
            alignment: Alignment.center,
            decoration: AppSectionCardStyles.iconBadgeDecoration(context, cs),
            child: Icon(icon, size: context.rs(18), color: cs.primary),
          ),
          SizedBox(width: context.rsi(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: context.rsi(2)),
                    child: Text(
                      subtitle!,
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
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
