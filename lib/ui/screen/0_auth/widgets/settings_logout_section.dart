import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/navigation/pending_post_auth_navigation.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/screen/0_auth/profile_logout_dialog.dart';
import 'package:w0001/util/clear_user_providers.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/fcm/fcm_token_registration_cache.dart';
import 'package:w0001/util/notifications/local_notification_inbox_store.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 설정 탭 하단 로그아웃 버튼 (작업자·관리자 공통).
class SettingsLogoutSection extends ConsumerStatefulWidget {
  const SettingsLogoutSection({super.key});

  @override
  ConsumerState<SettingsLogoutSection> createState() =>
      _SettingsLogoutSectionState();
}

class _SettingsLogoutSectionState extends ConsumerState<SettingsLogoutSection> {
  var _loggingOut = false;

  Future<void> _onLogoutPressed() async {
    if (_loggingOut) return;

    final choice = await showProfileLogoutConfirmDialog(context);
    if (choice == null || !mounted) return;

    setState(() => _loggingOut = true);
    final uid = ref.read(authSessionProvider).asData?.value?.uid;
    try {
      await ref.read(authUseCaseProvider).logout(allDevices: choice.allDevices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 요청 중 오류: $e')),
        );
      }
    } finally {
      await PendingPostAuthNavigation.clear();
      if (uid != null && uid.isNotEmpty) {
        await LocalNotificationInboxStore.clear(uid);
        await FcmTokenRegistrationCache.clearForUser(uid);
      }

      final container = rootProviderContainer;
      if (container != null) {
        clearAllUserProviders(container);
      }

      ref.read(authSessionProvider.notifier).clearSession();
      if (mounted) {
        setState(() => _loggingOut = false);
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(top: context.rsi(28)),
      child: SizedBox(
        width: double.infinity,
        height: context.rs(46),
        child: OutlinedButton.icon(
          onPressed: _loggingOut ? null : _onLogoutPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.error,
            disabledForegroundColor: cs.error.withValues(alpha: 0.45),
            side: BorderSide(
              color: cs.error.withValues(alpha: _loggingOut ? 0.25 : 0.45),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.rs(12)),
            ),
          ),
          icon: _loggingOut
              ? SizedBox(
                  width: context.rs(18),
                  height: context.rs(18),
                  child: const HammerLoadingIndicator(size: 18),
                )
              : Icon(Icons.logout_rounded, size: context.rs(20)),
          label: Text(
            '로그아웃',
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.error,
            ),
          ),
        ),
      ),
    );
  }
}
