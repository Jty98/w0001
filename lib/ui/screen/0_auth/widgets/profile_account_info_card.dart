import 'package:flutter/material.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_info_row.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_row_divider.dart';

class ProfileAccountInfoCard extends StatelessWidget {
  const ProfileAccountInfoCard({super.key, required this.user});

  final UserRead user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileInfoRow(
            icon: Icons.alternate_email_rounded,
            label: '아이디',
            value: user.uid,
          ),
          const ProfileRowDivider(),
          ProfileInfoRow(
            icon: Icons.verified_user_outlined,
            label: '권한',
            value: user.role.labelKo,
          ),
        ],
      ),
    );
  }
}
