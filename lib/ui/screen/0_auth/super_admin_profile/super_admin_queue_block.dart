import 'package:flutter/material.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_empty_banner.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_member_card.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/profile_super_admin_members_limits.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

class SuperAdminQueueBlock extends StatelessWidget {
  const SuperAdminQueueBlock({
    super.key,
    required this.subtitle,
    required this.items,
    required this.error,
    required this.icon,
    required this.emptyMessage,
    required this.handlers,
    required this.onRetryReload,
    this.onOpenMemberDetail,
    this.loading = false,
    this.humans = const [],
    this.maxVisible = ProfileSuperAdminMembersLimits.queuePageSize,
    this.showTopDivider = false,
    this.embedded = false,
  });

  final String subtitle;
  final List<HumanRead> humans;
  final List<UserRead> items;

  /// 처리 큐 카드 최대 표시 수.
  final int maxVisible;
  final Object? error;
  final IconData icon;
  final String emptyMessage;
  final SuperAdminMemberHandlers handlers;
  final VoidCallback onRetryReload;
  final void Function(UserRead u)? onOpenMemberDetail;

  /// 목록이 비어 있고 서버에서 채우는 중일 때 빈 배너 대신 플레이스홀더를 씁니다.
  final bool loading;

  /// 패널 안에서 이전 블록과 구분선.
  final bool showTopDivider;

  /// [ProfileInsetPanel] 내부에 묶여 있을 때 여백을 줄입니다.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final padH = context.rsi(embedded ? 10 : 0);
    final padV = context.rsi(embedded ? 10 : 0);

    return Padding(
      padding: EdgeInsets.only(bottom: embedded ? 0 : context.rsi(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTopDivider)
            Padding(
              padding: EdgeInsets.fromLTRB(padH, 0, padH, context.rsi(8)),
              child: const AppInsetDivider(),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(padH, padV, padH, 0),
            child: Row(
              children: [
                Container(
                  width: context.rs(28),
                  height: context.rs(28),
                  decoration: AppSectionCardStyles.iconBadgeDecoration(
                    context,
                    cs,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: context.rs(15),
                    color: cs.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: context.rsi(8)),
                Expanded(
                  child: Text(
                    subtitle,
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                AppInsetTile(
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: items.isEmpty
                      ? cs.appMutedFill
                      : cs.primaryContainer.withValues(alpha: 0.5),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rsi(8),
                    vertical: context.rsi(3),
                  ),
                  child: Text(
                    '${items.length}',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: items.isEmpty
                          ? cs.onSurfaceVariant
                          : cs.onPrimaryContainer,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.rsi(8)),
          if (error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(padH, 0, padH, context.rsi(8)),
              child: Material(
                color: cs.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: EdgeInsets.all(context.rsi(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '불러오기 실패',
                        style: tt.labelMedium?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: context.rsi(4)),
                      Text(
                        '$error',
                        style: tt.bodySmall?.copyWith(color: cs.error),
                      ),
                      SizedBox(height: context.rsi(6)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onRetryReload,
                          icon:
                              Icon(Icons.refresh_rounded, size: context.rs(16)),
                          label: const Text('다시 불러오기'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rsi(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (loading && items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(padH, 0, padH, context.rsi(8)),
              child: Skeletonizer(
                enabled: true,
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded,
                        size: context.rs(16), color: cs.primary),
                    SizedBox(width: context.rsi(8)),
                    Expanded(
                      child: Text(
                        '불러오는 중…',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(padH, 0, padH, padV),
              child: SuperAdminEmptyBanner(
                message: emptyMessage,
                icon: Icons.inbox_outlined,
                compact: true,
              ),
            )
          else ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padH),
              child: Column(
                children: items.take(maxVisible).map(
                  (u) {
                    final linked = findHumanReadForMember(u, humans);
                    return SuperAdminMemberCard(
                      user: u,
                      handlers: handlers,
                      primarySpecialty: memberListPrimarySpecialty(
                        u,
                        linkedHuman: linked,
                      ),
                      onOpenDetail: onOpenMemberDetail != null
                          ? () => onOpenMemberDetail!(u)
                          : null,
                    );
                  },
                ).toList(),
              ),
            ),
            if (items.length > maxVisible)
              Padding(
                padding: EdgeInsets.fromLTRB(padH, context.rsi(4), padH, padV),
                child: Text(
                  '외 ${items.length - maxVisible}명 — 상세 화면에서 확인할 수 있습니다',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              )
            else
              SizedBox(height: padV),
          ],
        ],
      ),
    );
  }
}
