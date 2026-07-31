import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/user_account_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_settings_skeletons.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 프로필 설정 — 전화번호 조회·수정 진입 (`GET /users/me/account`).
class ProfilePhoneInfoEntry extends ConsumerWidget {
  const ProfilePhoneInfoEntry({
    super.key,
    this.phoneSettingRoute = '/profile/phone-setting',
    this.embedded = false,
  });

  final String phoneSettingRoute;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accountAsync = ref.watch(userAccountProvider);

    return accountAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => embedded
          ? const ListTile(
              leading: Icon(Icons.phone_outlined),
              title: Text('전화번호'),
              subtitle: Text('불러오는 중'),
            )
          : const ProfilePhoneEntrySkeleton(),
      error: (e, _) => ProfileInsetPanel(
        padding: EdgeInsets.all(context.rsi(16)),
        child: Text(
          '전화번호 정보를 불러오지 못했습니다: $e',
          style: tt.bodyMedium?.copyWith(color: cs.error),
        ),
      ),
      data: (account) {
        if (account == null) {
          return ProfileInsetPanel(
            padding: EdgeInsets.all(context.rsi(16)),
            child: Text(
              '계정 정보를 불러올 수 없습니다.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          );
        }

        final phone = account.phoneMasked?.trim() ?? '';
        final hasPhone = phone.isNotEmpty;
        final subtitle = hasPhone
            ? (account.phoneVerified ? '$phone · 인증됨' : '$phone · 미인증')
            : '등록된 전화번호가 없습니다';

        final tile = ListTile(
          leading: Icon(
            Icons.phone_outlined,
            color: cs.primary,
            size: context.rsi(22),
          ),
          title: Text(
            '전화번호',
            style: TextStyle(fontSize: context.rs(14)),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: context.rs(12),
              color: hasPhone && !account.phoneVerified
                  ? cs.error.withValues(alpha: 0.85)
                  : null,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPhone)
                Icon(
                  account.phoneVerified
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  size: context.rsi(18),
                  color: account.phoneVerified
                      ? cs.primary
                      : cs.error.withValues(alpha: 0.75),
                ),
              Icon(
                Icons.chevron_right_rounded,
                size: context.rsi(20),
              ),
            ],
          ),
          onTap: () => context.push(phoneSettingRoute),
        );

        return embedded
            ? tile
            : ProfileInsetPanel(
                padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                child: tile,
              );
      },
    );
  }
}
