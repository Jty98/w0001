import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_notifier.dart';
import 'package:w0001/ui/screen/0_auth/profile_super_admin_user_section.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_account_info_card.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_header.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';

/// 로그인 사용자 프로필 본문.
class ProfileSignedInBody extends ConsumerWidget {
  const ProfileSignedInBody({super.key, required this.user});

  final UserRead user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = user.role == UserRole.superAdmin;

    final scroll = SingleChildScrollView(
      physics: isSuperAdmin
          ? const AlwaysScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileHeader(uname: user.uname),
          const SizedBox(height: 18),
          const ProfileSectionTitle('내 정보'),
          const SizedBox(height: 8),
          ProfileAccountInfoCard(user: user),
          if (isSuperAdmin) ...[
            const SizedBox(height: 22),
            const ProfileSectionTitle('회원 관리'),
            const SizedBox(height: 8),
            ProfileInsetPanel(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: ProfileSuperAdminUserSection(
                reloadSession: () {
                  unawaited(
                    ref.read(authSessionProvider.notifier).loadCurrentUser(),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );

    final scrollChild = isSuperAdmin
        ? RefreshIndicator(
            onRefresh: () async {
              await reloadProfileSuperAdminMembers(ref);
              if (!context.mounted) return;
              await ref.read(authSessionProvider.notifier).loadCurrentUser();
            },
            child: scroll,
          )
        : scroll;

    return SafeArea(
      child: scrollChild,
    );
  }
}
