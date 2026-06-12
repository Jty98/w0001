import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/user_account_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/account_settings_sections.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 계정 설정 화면 (admin·worker 공통).
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({
    super.key,
    this.phoneSettingRoute = '/settings/account/phone-setting',
  });

  final String phoneSettingRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('계정 설정'),
        backgroundColor: colorScheme.surface,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(userAccountProvider.notifier).reload(),
              ref.read(authSessionProvider.notifier).loadCurrentUser(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(16),
              vertical: context.rsi(16),
            ),
            child: AccountSettingsSectionBody(
              phoneSettingRoute: phoneSettingRoute,
            ),
          ),
        ),
      ),
    );
  }
}
