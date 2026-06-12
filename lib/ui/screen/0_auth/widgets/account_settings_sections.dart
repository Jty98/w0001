import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/user_account_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_account_name_edit_tile.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_account_settings_card.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_password_edit_tile.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_phone_info_entry.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_settings_skeletons.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 계정·비밀번호·전화번호 설정 공통 섹션 (admin·worker).
class AccountSettingsSectionBody extends ConsumerWidget {
  const AccountSettingsSectionBody({
    super.key,
    required this.phoneSettingRoute,
  });

  final String phoneSettingRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(userAccountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionTitle('계정 정보'),
        SizedBox(height: context.rsi(8)),
        accountAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const ProfileAccountSectionSkeleton(),
          error: (e, _) => ProfileInsetPanel(
            padding: EdgeInsets.all(context.rsi(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('계정 정보를 불러오지 못했습니다: $e'),
                SizedBox(height: context.rsi(8)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(userAccountProvider.notifier).reload(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('다시 시도'),
                  ),
                ),
              ],
            ),
          ),
          data: (account) {
            if (account == null) {
              return ProfileInsetPanel(
                padding: EdgeInsets.all(context.rsi(16)),
                child: const Text('계정 정보가 없습니다.'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileAccountSettingsCard(account: account),
                SizedBox(height: context.rsi(8)),
                ProfileInsetPanel(
                  padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                  child: Column(
                    children: [
                      ProfileAccountNameEditTile(account: account),
                      const Divider(height: 1, indent: 56),
                      const ProfilePasswordEditTile(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: context.rsi(20)),
        const ProfileSectionTitle('전화번호'),
        SizedBox(height: context.rsi(8)),
        ProfilePhoneInfoEntry(phoneSettingRoute: phoneSettingRoute),
      ],
    );
  }
}
