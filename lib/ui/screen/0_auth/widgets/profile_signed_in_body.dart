import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_profile_notifier.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_account_info_card.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_header.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_worker_rank_career_section.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_worker_skills_section.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_private_info_entry.dart';
import 'package:w0001/presentation/viewmodel/user_private_providers.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 로그인 사용자 프로필 본문.
class ProfileSignedInBody extends ConsumerStatefulWidget {
  const ProfileSignedInBody({super.key, required this.user});

  final UserRead user;

  @override
  ConsumerState<ProfileSignedInBody> createState() =>
      _ProfileSignedInBodyState();
}

class _ProfileSignedInBodyState extends ConsumerState<ProfileSignedInBody> {
  @override
  void initState() {
    super.initState();
    // 워커 계정이면 프로필 로드 시작
    if (widget.user.isWorker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(workerProfileProvider);
        ref.invalidate(workerPrivateInfoProvider);
        ref.invalidate(workerTaxAgreementsProvider);
      });
    }
  }

  @override
  void didUpdateWidget(ProfileSignedInBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 사용자가 변경되었을 때 워커 프로필 재로드
    if (oldWidget.user.uid != widget.user.uid) {
      if (widget.user.isWorker) {
        ref.invalidate(workerProfileProvider);
        ref.invalidate(workerPrivateInfoProvider);
        ref.invalidate(workerTaxAgreementsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    // 작업자 전용 레이아웃 (관리 권한이 없는 순수 작업자)
    final workerOnlyLayout = user.isWorker;

    final pad = workerOnlyLayout
        ? EdgeInsets.fromLTRB(
            context.rsi(16), context.rsi(6), context.rsi(16), context.rsi(10))
        : EdgeInsets.fromLTRB(
            context.rsi(18), context.rsi(14), context.rsi(18), context.rsi(22));

    final scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileHeader(uname: user.uname, compact: workerOnlyLayout),
          SizedBox(height: context.rsi(workerOnlyLayout ? 16 : 24)),
          const ProfileSectionTitle('내 정보'),
          SizedBox(height: context.rsi(workerOnlyLayout ? 8 : 12)),
          ProfileAccountInfoCard(user: user),
          if (user.isWorker) ...[
            SizedBox(height: context.rsi(8)),
            ProfileInsetPanel(
              padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
              child: const WorkerPrivateInfoEntry(embedded: true),
            ),
          ],
          if (user.isWorker && !workerOnlyLayout) ...[
            SizedBox(height: context.rsi(28)),
            const ProfileSectionTitle('현장 역할·경력'),
            SizedBox(height: context.rsi(12)),
            ProfileInsetPanel(
              padding: EdgeInsets.all(context.rsi(16)),
              child: const ProfileWorkerRankCareerSection(compact: false),
            ),
            SizedBox(height: context.rsi(28)),
            const ProfileSectionTitle('주특기·스킬'),
            SizedBox(height: context.rsi(12)),
            ProfileInsetPanel(
              padding: EdgeInsets.all(context.rsi(16)),
              child: const ProfileWorkerSkillsSection(compact: false),
            ),
            SizedBox(height: context.rsi(24)),
          ],
        ],
      ),
    );

    final scrollChild = AppRefreshIndicator(
      onRefresh: () async {
        if (user.isWorker) {
          await ref.read(workerProfileProvider.notifier).reload();
          await ref.read(workerPrivateInfoProvider.notifier).reload();
          ref.invalidate(workerTaxAgreementsProvider);
        }
        if (!context.mounted) return;
        await ref.read(authSessionProvider.notifier).loadCurrentUser();
      },
      child: scroll,
    );

    return SafeArea(
      child: scrollChild,
    );
  }
}
