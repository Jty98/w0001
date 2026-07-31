import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_info_row.dart';

class ProfileAccountInfoCard extends StatelessWidget {
  const ProfileAccountInfoCard({
    super.key,
    required this.user,
    this.showPhone = true,
    this.showWorkerMeta = true,
    this.phoneSettingRoute = '/profile/phone-setting',
  });

  final UserRead user;
  final bool showPhone;
  final bool showWorkerMeta;
  final String phoneSettingRoute;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppInsetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileInfoRow(
            icon: Icons.alternate_email_rounded,
            label: '아이디',
            value: user.uid,
          ),
          const AppInsetDivider(),
          ProfileInfoRow(
            icon: Icons.person_outline_rounded,
            label: '이름',
            value: user.uname,
          ),
          const AppInsetDivider(),
          ProfileInfoRow(
            icon: Icons.verified_user_outlined,
            label: '권한',
            value: user.role.labelKo,
          ),
          if (showPhone &&
              user.phoneMasked != null &&
              user.phoneMasked!.isNotEmpty) ...[
            const AppInsetDivider(),
            InkWell(
              onTap:
                  user.isWorker ? () => context.push(phoneSettingRoute) : null,
              borderRadius: BorderRadius.circular(12),
              child: ProfileInfoRow(
                icon: Icons.phone_outlined,
                label: '전화번호',
                value: user.phoneMasked!,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      user.phoneVerified
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: user.phoneVerified
                          ? cs.primary
                          : cs.error.withValues(alpha: 0.7),
                    ),
                    if (user.isWorker) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else if (showPhone && user.isWorker) ...[
            const AppInsetDivider(),
            InkWell(
              onTap: () => context.push(phoneSettingRoute),
              borderRadius: BorderRadius.circular(12),
              child: ProfileInfoRow(
                icon: Icons.phone_outlined,
                label: '전화번호',
                value: '미등록',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
          if (showWorkerMeta &&
              user.isWorker &&
              (user.workerRank.isNotEmpty || user.career.isNotEmpty)) ...[
            const AppInsetDivider(),
            if (user.workerRank.isNotEmpty)
              ProfileInfoRow(
                icon: Icons.badge_outlined,
                label: '현장 역할',
                value: user.workerRank,
              ),
            if (user.workerRank.isNotEmpty && user.career.isNotEmpty)
              const AppInsetDivider(),
            if (user.career.isNotEmpty)
              ProfileInfoRow(
                icon: Icons.history_edu_outlined,
                label: '경력',
                value: user.career,
              ),
          ],
        ],
      ),
    );
  }
}
