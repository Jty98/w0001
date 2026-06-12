import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/navigation/pending_post_auth_navigation.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/screen/0_auth/profile_logout_dialog.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_session_placeholders.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_signed_in_body.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/clear_user_providers.dart';
import 'package:w0001/util/fcm/fcm_token_registration_cache.dart';
import 'package:w0001/util/notifications/local_notification_inbox_store.dart';
import 'package:w0001/util/responsive_layout.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _loggingOut = false;

  Future<void> _onLogoutPressed() async {
    final choice = await showProfileLogoutConfirmDialog(context);
    if (choice == null || !mounted) return;

    setState(() => _loggingOut = true);
    final uid = ref.read(authSessionProvider).asData?.value?.uid;
    try {
      await ref
          .read(authUseCaseProvider)
          .logout(allDevices: choice.allDevices);
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

      // 모든 사용자별 상태 초기화
      _clearAllUserSpecificProviders();
      
      ref.read(authSessionProvider.notifier).clearSession();
      if (mounted) {
        setState(() => _loggingOut = false);
        context.go('/login');
      }
    }
  }

  /// 로그아웃 시 모든 사용자별 provider 초기화
  void _clearAllUserSpecificProviders() {
    final container = rootProviderContainer;
    if (container != null) {
      clearAllUserProviders(container);
    }
  }

  List<Widget> _logoutAppBarActions(
    AsyncValue<UserRead?> session,
    ColorScheme cs,
  ) {
    final showLogout = session.maybeWhen(
      data: (u) => u != null,
      orElse: () => false,
    );
    if (!showLogout) return [];

    if (_loggingOut) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(14),
            vertical: context.rsi(12),
          ),
          child: Icon(
            Icons.logout_rounded,
            color: cs.error.withValues(alpha: 0.35),
            size: context.rs(22),
          ),
        ),
      ];
    }

    return [
      IconButton(
        tooltip: '로그아웃',
        onPressed: _onLogoutPressed,
        icon: Icon(Icons.logout_rounded, color: cs.error),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final sessionVm = ref.read(authSessionProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final canPop = context.canPop();

    return PopScope(
      canPop: canPop,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        automaticallyImplyLeading: canPop,
        actions: _logoutAppBarActions(session, cs),
      ),
      body: session.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (user) {
          if (user == null) {
            return ProfileMissingSessionBody(
              onRetryLoad: () => unawaited(sessionVm.loadCurrentUser()),
            );
          }
          return ProfileSignedInBody(user: user);
        },
        error: (e, _) => ProfileSessionErrorBody(
          message: e.toString(),
          onRetryLoad: () => unawaited(sessionVm.loadCurrentUser()),
        ),
        loading: () => const ProfileSessionLoadingBody(),
      ),
    ),
    );
  }
}
