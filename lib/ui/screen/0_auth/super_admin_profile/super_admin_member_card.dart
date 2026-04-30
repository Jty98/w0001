import 'package:flutter/material.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_state.dart';

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

/// 슈퍼관리자 회원 한 줄 카드. (구역 제목으로 맥락이 구분되므로 승인·활동 상태 칩은 표시하지 않음.)
class SuperAdminMemberCard extends StatelessWidget {
  const SuperAdminMemberCard({
    super.key,
    required this.user,
    required this.handlers,
  });

  final UserRead user;
  final SuperAdminMemberHandlers handlers;

  static const double _actionHeight = 44;
  static const double _radius = 18;

  ButtonStyle _filledPrimary(ColorScheme cs) {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, _actionHeight),
      maximumSize: const Size(double.infinity, _actionHeight),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      foregroundColor: cs.onPrimary,
      backgroundColor: cs.primary,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  ButtonStyle _outlined(
    ColorScheme cs, {
    required Color foreground,
    required Color borderColor,
  }) {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, _actionHeight),
      maximumSize: const Size(double.infinity, _actionHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: borderColor),
      foregroundColor: foreground,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  ButtonStyle _tonal(ColorScheme cs) {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, _actionHeight),
      maximumSize: const Size(double.infinity, _actionHeight),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      visualDensity: VisualDensity.standard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  List<Widget> _actionButtons(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (user.approvalStatus == UserApprovalStatus.pending) {
      return [
        FilledButton.icon(
          onPressed: () => handlers.approve(user),
          icon: const Icon(Icons.check_rounded, size: 20),
          label: const Text('승인'),
          style: _filledPrimary(cs),
        ),
        OutlinedButton.icon(
          onPressed: () => handlers.reject(user),
          icon: const Icon(Icons.close_rounded, size: 20),
          label: const Text('거절'),
          style: _outlined(
            cs,
            foreground: cs.error,
            borderColor: cs.error.withValues(alpha: 0.45),
          ),
        ),
      ];
    }

    if (user.approvalStatus == UserApprovalStatus.rejected) {
      return [
        FilledButton.icon(
          onPressed: () => handlers.approve(user),
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label: const Text('다시 승인'),
          style: _filledPrimary(cs),
        ),
        OutlinedButton.icon(
          onPressed: () => handlers.deleteUser(user),
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          label: const Text('데이터에서 제거'),
          style: _outlined(
            cs,
            foreground: cs.error,
            borderColor: cs.error.withValues(alpha: 0.42),
          ),
        ),
      ];
    }

    if (user.approvalStatus == UserApprovalStatus.approved) {
      if (!user.isActive) {
        return [
          FilledButton.tonalIcon(
            onPressed: () => handlers.activate(user),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('재활성화'),
            style: _tonal(cs),
          ),
          OutlinedButton.icon(
            onPressed: () => handlers.deleteUser(user),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('데이터에서 제거'),
            style: _outlined(
              cs,
              foreground: cs.error,
              borderColor: cs.error.withValues(alpha: 0.4),
            ),
          ),
        ];
      }

      if (isSuperAdminUser(user)) return [];

      return [
        OutlinedButton.icon(
          onPressed: () => handlers.suspend(user),
          icon: const Icon(Icons.block_rounded, size: 20),
          label: const Text('활동 정지'),
          style: _outlined(
            cs,
            foreground: cs.error,
            borderColor: cs.error.withValues(alpha: 0.38),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => handlers.flipRole(user),
          icon: Icon(
            user.role == UserRole.worker
                ? Icons.admin_panel_settings_rounded
                : Icons.construction_rounded,
            size: 20,
          ),
          label: Text(user.role == UserRole.worker ? '관리자로' : '작업자로'),
          style: _outlined(
            cs,
            foreground: cs.primary,
            borderColor: cs.primary.withValues(alpha: 0.4),
          ),
        ),
      ];
    }

    return [];
  }

  Widget _actionsLayout(List<Widget> actions) {
    if (actions.isEmpty) return const SizedBox.shrink();
    if (actions.length == 1) {
      return SizedBox(width: double.infinity, child: actions.first);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final actions = _actionButtons(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          color: cs.surfaceContainerLowest.withValues(alpha: 0.92),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.55),
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          cs.primaryContainer.withValues(alpha: 0.65),
                      child: Text(
                        user.uname.isNotEmpty
                            ? String.fromCharCodes(user.uname.runes.take(1))
                                .toUpperCase()
                            : '?',
                        style: tt.titleMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.uname,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.uid,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.role.labelKo,
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 12),
                _actionsLayout(actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
