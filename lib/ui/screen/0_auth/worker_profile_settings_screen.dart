import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/user_account_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/account_settings_sections.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_worker_rank_career_section.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_worker_skills_section.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_private_info_entry.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 프로필 설정 화면
class WorkerProfileSettingsScreen extends ConsumerStatefulWidget {
  const WorkerProfileSettingsScreen({super.key});

  static const phoneSettingRoute = '/settings/profile/phone-setting';

  @override
  ConsumerState<WorkerProfileSettingsScreen> createState() =>
      _WorkerProfileSettingsScreenState();
}

class _WorkerProfileSettingsScreenState
    extends ConsumerState<WorkerProfileSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(userAccountProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('프로필 설정'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AccountSettingsSectionBody(
                  phoneSettingRoute: WorkerProfileSettingsScreen.phoneSettingRoute,
                ),
                SizedBox(height: context.rsi(20)),
                const ProfileSectionTitle('세무·정산'),
                SizedBox(height: context.rsi(8)),
                ProfileInsetPanel(
                  padding: EdgeInsets.all(context.rsi(12)),
                  child: const WorkerPrivateInfoEntry(),
                ),
                SizedBox(height: context.rsi(20)),
                const ProfileSectionTitle('현장 역할·경력'),
                SizedBox(height: context.rsi(8)),
                ProfileInsetPanel(
                  padding: EdgeInsets.all(context.rsi(12)),
                  child: const ProfileWorkerRankCareerSection(compact: true),
                ),
                SizedBox(height: context.rsi(20)),
                const ProfileSectionTitle('주특기·스킬'),
                SizedBox(height: context.rsi(8)),
                ProfileInsetPanel(
                  padding: EdgeInsets.all(context.rsi(12)),
                  child: const ProfileWorkerSkillsSection(compact: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
