import 'package:flutter/material.dart';
import 'package:w0001/data/model/user_account_models.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_info_row.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_row_divider.dart';

/// `GET /users/me/account` 기반 계정 정보 카드.
class ProfileAccountSettingsCard extends StatelessWidget {
  const ProfileAccountSettingsCard({super.key, required this.account});

  final UserAccountRead account;

  @override
  Widget build(BuildContext context) {
    return AppInsetCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileInfoRow(
            icon: Icons.alternate_email_rounded,
            label: '아이디',
            value: account.uid,
          ),
          const AppInsetDivider(),
          ProfileInfoRow(
            icon: Icons.person_outline_rounded,
            label: '이름',
            value: account.uname,
          ),
          const AppInsetDivider(),
          ProfileInfoRow(
            icon: Icons.verified_user_outlined,
            label: '권한',
            value: account.role.labelKo,
          ),
        ],
      ),
    );
  }
}
