import 'package:flutter/material.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_state.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 회원 카드 액션: 다이얼로그·스낵바는 상위에서 처리.
class SuperAdminMemberHandlers {
  const SuperAdminMemberHandlers({
    required this.approve,
    required this.reject,
    required this.suspend,
    required this.activate,
    required this.flipRole,
    required this.deleteUser,
  });

  final Future<void> Function(UserRead u) approve;
  final Future<void> Function(UserRead u) reject;
  final Future<void> Function(UserRead u) suspend;
  final Future<void> Function(UserRead u) activate;
  final Future<void> Function(UserRead u) flipRole;
  final Future<void> Function(UserRead u) deleteUser;
}

/// 슈퍼관리자 회원 한 줄 카드 — 목록에는 이름·주특기·전화번호만 표시.
class SuperAdminMemberCard extends StatelessWidget {
  const SuperAdminMemberCard({
    super.key,
    required this.user,
    required this.handlers,
    required this.primarySpecialty,
    this.onOpenDetail,
  });

  final UserRead user;
  final SuperAdminMemberHandlers handlers;
  final String primarySpecialty;
  final VoidCallback? onOpenDetail;

  static const double _actionHeight = 30;
  static const double _radius = 10;

  ButtonStyle _compactAction(
    BuildContext context, {
    Color? foreground,
    Color? background,
    Color? border,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.styleFrom(
      minimumSize: Size(0, context.rs(_actionHeight)),
      maximumSize: Size(double.infinity, context.rs(_actionHeight)),
      padding: EdgeInsets.symmetric(horizontal: context.rsi(8)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      foregroundColor: foreground ?? cs.primary,
      backgroundColor: background,
      side: border == null ? null : BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(8)),
      ),
      textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
    );
  }

  List<Widget> _actionButtons(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (user.approvalStatus == UserApprovalStatus.pending) {
      return [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => handlers.approve(user),
            icon: Icon(Icons.check_rounded, size: context.rs(15)),
            label: const Text('승인'),
            style: _compactAction(
              context,
              foreground: cs.onPrimary,
              background: cs.primary,
            ),
          ),
        ),
        SizedBox(width: context.rsi(6)),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => handlers.reject(user),
            icon: Icon(Icons.close_rounded, size: context.rs(15)),
            label: const Text('거절'),
            style: _compactAction(
              context,
              foreground: cs.error,
              border: cs.error.withValues(alpha: 0.4),
            ),
          ),
        ),
      ];
    }

    if (user.approvalStatus == UserApprovalStatus.rejected) {
      return [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => handlers.approve(user),
            icon: Icon(Icons.refresh_rounded, size: context.rs(15)),
            label: const Text('재승인'),
            style: _compactAction(
              context,
              foreground: cs.onPrimary,
              background: cs.primary,
            ),
          ),
        ),
        SizedBox(width: context.rsi(6)),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => handlers.deleteUser(user),
            icon: Icon(Icons.delete_outline_rounded, size: context.rs(15)),
            label: const Text('제거'),
            style: _compactAction(
              context,
              foreground: cs.error,
              border: cs.error.withValues(alpha: 0.38),
            ),
          ),
        ),
      ];
    }

    if (user.approvalStatus == UserApprovalStatus.approved) {
      if (!user.isActive) {
        return [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => handlers.activate(user),
              icon: Icon(Icons.refresh_rounded, size: context.rs(15)),
              label: const Text('재활성'),
              style: _compactAction(context),
            ),
          ),
          SizedBox(width: context.rsi(6)),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => handlers.deleteUser(user),
              icon: Icon(Icons.delete_outline_rounded, size: context.rs(15)),
              label: const Text('제거'),
              style: _compactAction(
                context,
                foreground: cs.error,
                border: cs.error.withValues(alpha: 0.38),
              ),
            ),
          ),
        ];
      }

      if (isProtectedAdminUser(user)) return [];

      return [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => handlers.suspend(user),
            icon: Icon(Icons.block_rounded, size: context.rs(15)),
            label: const Text('정지'),
            style: _compactAction(
              context,
              foreground: cs.error,
              border: cs.error.withValues(alpha: 0.35),
            ),
          ),
        ),
        SizedBox(width: context.rsi(6)),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => handlers.flipRole(user),
            icon: Icon(
              user.role == UserRole.worker
                  ? Icons.admin_panel_settings_outlined
                  : Icons.construction_outlined,
              size: context.rs(15),
            ),
            label: Text(
              user.role == UserRole.worker ? '관리자' : '작업자',
            ),
            style: _compactAction(
              context,
              foreground: cs.primary,
              border: cs.primary.withValues(alpha: 0.35),
            ),
          ),
        ),
      ];
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final actions = _actionButtons(context);
    final phone = user.phoneMasked?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;
    final hasSpecialty = primarySpecialty != '주특기 미등록';

    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(6)),
      child: AppInsetTile(
        borderRadius: BorderRadius.circular(context.rs(_radius)),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpenDetail,
            borderRadius: BorderRadius.circular(context.rs(_radius)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(10),
                context.rsi(8),
                context.rsi(6),
                context.rsi(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.uname,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.25,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: context.rsi(2)),
                            Text(
                              primarySpecialty,
                              style: tt.labelMedium?.copyWith(
                                color: hasSpecialty
                                    ? cs.primary
                                    : cs.onSurfaceVariant
                                        .withValues(alpha: 0.75),
                                fontWeight: hasSpecialty
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: context.rsi(2)),
                            Text(
                              hasPhone ? phone : '전화번호 미등록',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (onOpenDetail != null)
                        Icon(
                          Icons.chevron_right_rounded,
                          size: context.rs(20),
                          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                    ],
                  ),
                  if (actions.isNotEmpty) ...[
                    SizedBox(height: context.rsi(8)),
                    Row(children: actions),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
