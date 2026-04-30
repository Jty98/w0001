import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/screen/0_auth/profile_logout_dialog.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_session_placeholders.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_signed_in_body.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _loggingOut = false;

  Future<void> _onLogoutPressed() async {
    final confirmed = await showProfileLogoutConfirmDialog(context);
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await ref.read(authUseCaseProvider).logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 요청 중 오류: $e')),
        );
      }
    } finally {
      ref.read(authSessionProvider.notifier).clearSession();
      if (mounted) {
        setState(() => _loggingOut = false);
        context.go('/login');
      }
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.error,
            ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: _logoutAppBarActions(session, cs),
      ),
      body: session.when(
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
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
