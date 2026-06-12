import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/screen/0_auth/profile_logout_dialog.dart';
import 'package:w0001/ui/widget/responsive_page_shell.dart';
import 'package:w0001/util/clear_user_providers.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 가입 승인 대기 (`approval_status == pending`).
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  var _loggingOut = false;
  var _refreshing = false;

  Future<void> _refreshStatus() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(authSessionProvider.notifier).loadCurrentUser();
      if (!mounted) return;
      final user = ref.read(authSessionProvider).asData?.value;
      if (user != null && !user.isPendingApproval) {
        context.go('/dashboard');
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final choice = await showProfileLogoutConfirmDialog(context);
    if (choice == null || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await ref
          .read(authUseCaseProvider)
          .logout(allDevices: choice.allDevices);
    } catch (_) {}
    final container = rootProviderContainer;
    if (container != null) clearAllUserProviders(container);
    ref.read(authSessionProvider.notifier).clearSession();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(authSessionProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('승인 대기'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: '로그아웃',
            onPressed: _loggingOut ? null : _logout,
            icon: Icon(Icons.logout_rounded, color: cs.error),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsivePageShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: context.rsi(24)),
              Icon(
                Icons.hourglass_top_rounded,
                size: context.rs(56),
                color: cs.primary,
              ),
              SizedBox(height: context.rsi(16)),
              Text(
                '가입 승인을 기다리는 중입니다',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rsi(10)),
              Text(
                user != null
                    ? '${user.uname} 님, 관리자 승인이 완료되면 앱의 모든 기능을 이용할 수 있습니다.\n승인 알림이 오면 아래에서 상태를 다시 확인해 주세요.'
                    : '관리자 승인이 완료되면 앱의 모든 기능을 이용할 수 있습니다.',
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.rsi(28)),
              FilledButton.icon(
                onPressed: _refreshing ? null : _refreshStatus,
                icon: _refreshing
                    ? SizedBox(
                        width: context.rs(18),
                        height: context.rs(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('승인 상태 확인'),
              ),
              SizedBox(height: context.rsi(12)),
              OutlinedButton(
                onPressed: _loggingOut ? null : _logout,
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
