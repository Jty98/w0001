import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/presentation/viewmodel/user_private_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_settings_skeletons.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 프로필·대시보드 — 세무·정산 정보 진입.
class WorkerPrivateInfoEntry extends ConsumerWidget {
  const WorkerPrivateInfoEntry({
    super.key,
    this.compact = false,
    this.embedded = false,
  });

  final bool compact;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workerPrivateInfoProvider);
    final private = async.asData?.value;

    // 약관 동의 이력도 확인
    final taxAgreements = ref.watch(workerTaxAgreementsProvider);
    final hasTaxAgreement = (taxAgreements.asData?.value ?? []).isNotEmpty;

    // 로딩 중인지 확인
    final isLoading = async.isLoading || taxAgreements.isLoading;
    final hasTaxAgreementHistory = hasTaxAgreement;

    // 주민번호, 계좌, 약관 동의가 모두 있으면 완료
    final complete = private?.isRegistrationComplete(
          hasTaxAgreementHistory: hasTaxAgreementHistory,
        ) ??
        false;

    if (compact) {
      return _dashboardBanner(
        context,
        complete: complete,
        isLoading: isLoading,
        hasError: async.hasError,
      );
    }

    if (isLoading) {
      if (embedded) {
        return ListTile(
          dense: true,
          leading: Icon(
            Icons.account_balance_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: context.rsi(22),
          ),
          title: Text(
            '세무·정산 정보',
            style: TextStyle(fontSize: context.rs(14)),
          ),
          subtitle: Text(
            '등록 상태 확인 중',
            style: TextStyle(fontSize: context.rs(12)),
          ),
        );
      }
      return const ProfileSettingsListTileSkeleton(
        icon: Icons.account_balance_outlined,
        title: '세무·정산 정보',
        subtitle: '등록 상태 확인 중',
      );
    }

    final cs = Theme.of(context).colorScheme;
    final tile = ListTile(
      dense: true,
      leading: Icon(
        complete
            ? Icons.verified_user_outlined
            : Icons.account_balance_outlined,
        color: cs.primary,
        size: context.rsi(22),
      ),
      title: Text(
        '세무·정산 정보',
        style: TextStyle(fontSize: context.rs(14)),
      ),
      subtitle: Text(
        complete ? '등록 완료' : '입력 필요',
        style: TextStyle(fontSize: context.rs(12)),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: context.rsi(20),
      ),
      onTap: () => context.push('/profile/private-info'),
    );

    if (embedded) return tile;

    return ProfileInsetPanel(
      padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
      child: tile,
    );
  }

  Widget _dashboardBanner(
    BuildContext context, {
    required bool complete,
    required bool isLoading,
    required bool hasError,
  }) {
    // 로딩·완료·조회 실패 시 배너를 표시하지 않음 (실패를 미입력으로 오인하지 않음)
    if (isLoading || complete || hasError) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        context.rsi(8),
        context.rsi(16),
        context.rsi(4),
      ),
      child: Material(
        color: cs.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(context.rs(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(context.rs(12)),
          onTap: () => context.push('/profile/private-info'),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(14),
              vertical: context.rsi(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: cs.primary),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: Text(
                    '세무·정산 정보를 입력해 주세요.',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
