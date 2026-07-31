import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/user_account_models.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_account_settings_card.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 계정 정보 카드 + 수정 타일 스켈레톤.
class ProfileAccountSectionSkeleton extends StatelessWidget {
  const ProfileAccountSectionSkeleton({super.key});

  static const _placeholderAccount = UserAccountRead(
    uid: 'user_id_sample',
    uname: '사용자 이름',
    role: UserRole.worker,
    phoneMasked: '010-****-0000',
    phoneVerified: true,
  );

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ProfileAccountSettingsCard(account: _placeholderAccount),
          SizedBox(height: context.rsi(8)),
          ProfileInsetPanel(
            padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.lock_outline_rounded,
                    size: context.rsi(22),
                  ),
                  title: Text(
                    '비밀번호 변경',
                    style: TextStyle(fontSize: context.rs(14)),
                  ),
                  subtitle: Text(
                    '보안을 위해 주기적으로 변경하세요',
                    style: TextStyle(fontSize: context.rs(12)),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: context.rsi(20),
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

/// 전화번호 진입 타일 스켈레톤.
class ProfilePhoneEntrySkeleton extends StatelessWidget {
  const ProfilePhoneEntrySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ProfileInsetPanel(
        padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
        child: ListTile(
          dense: true,
          leading: Icon(
            Icons.phone_outlined,
            size: context.rsi(22),
          ),
          title: Text(
            '전화번호',
            style: TextStyle(fontSize: context.rs(14)),
          ),
          subtitle: Text(
            '010-****-0000 · 인증됨',
            style: TextStyle(fontSize: context.rs(12)),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: context.rsi(20),
          ),
        ),
      ),
    );
  }
}

/// 세무·정산 등 ListTile 진입 스켈레톤.
class ProfileSettingsListTileSkeleton extends StatelessWidget {
  const ProfileSettingsListTileSkeleton({
    super.key,
    this.icon = Icons.account_balance_outlined,
    this.title = '세무·정산 정보',
    this.subtitle = '등록 상태 확인 중',
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ProfileInsetPanel(
        padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
        child: ListTile(
          leading: Icon(icon, size: context.rsi(22)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}
