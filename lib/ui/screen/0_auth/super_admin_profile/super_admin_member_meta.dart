import 'package:flutter/material.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 회원 목록·상세에서 쓰는 작은 메타 칩.
class SuperAdminMemberMetaChip extends StatelessWidget {
  const SuperAdminMemberMetaChip({
    super.key,
    required this.label,
    this.tone = SuperAdminMemberMetaTone.neutral,
    this.icon,
  });

  final String label;
  final SuperAdminMemberMetaTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (Color bg, Color fg) = switch (tone) {
      SuperAdminMemberMetaTone.primary => (
          cs.primaryContainer.withValues(alpha: 0.55),
          cs.onPrimaryContainer,
        ),
      SuperAdminMemberMetaTone.success => (
          cs.tertiaryContainer.withValues(alpha: 0.55),
          cs.onTertiaryContainer,
        ),
      SuperAdminMemberMetaTone.warning => (
          cs.errorContainer.withValues(alpha: 0.42),
          cs.onErrorContainer,
        ),
      SuperAdminMemberMetaTone.neutral => (
          cs.surfaceContainerHighest.withValues(alpha: 0.75),
          cs.onSurfaceVariant,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(7),
        vertical: context.rsi(3),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: context.rs(11), color: fg),
            SizedBox(width: context.rsi(3)),
          ],
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

enum SuperAdminMemberMetaTone { primary, success, warning, neutral }

/// 역할·승인·활동 상태를 칩으로 표시 (문자열 `·` 구분 대신).
class SuperAdminMemberStatusChips extends StatelessWidget {
  const SuperAdminMemberStatusChips({
    super.key,
    required this.user,
    this.dense = true,
  });

  final UserRead user;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      SuperAdminMemberMetaChip(
        label: user.role.labelKo,
        tone: SuperAdminMemberMetaTone.primary,
      ),
      SuperAdminMemberMetaChip(
        label: user.approvalStatus.labelKo,
        tone: switch (user.approvalStatus) {
          UserApprovalStatus.approved => SuperAdminMemberMetaTone.success,
          UserApprovalStatus.pending => SuperAdminMemberMetaTone.warning,
          UserApprovalStatus.rejected => SuperAdminMemberMetaTone.warning,
        },
      ),
      if (!user.isActive)
        const SuperAdminMemberMetaChip(
          label: '비활동',
          tone: SuperAdminMemberMetaTone.warning,
          icon: Icons.pause_circle_outline,
        ),
    ];

    return Wrap(
      spacing: context.rsi(dense ? 4 : 6),
      runSpacing: context.rsi(4),
      children: chips,
    );
  }
}
