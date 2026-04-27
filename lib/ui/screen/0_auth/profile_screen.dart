import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _loggingOut = false;

  Future<void> _onLogoutPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('로그아웃할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final vm = ref.read(authSessionProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인 정보'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: session.isLoading
                ? null
                : () => vm.loadCurrentUser(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: session.when(
        data: (user) {
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('로그인 정보가 없습니다.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => vm.loadCurrentUser(),
                    child: const Text('내 정보 불러오기'),
                  ),
                ],
              ),
            );
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(
                    uname: user.uname,
                    colorScheme: cs,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ProfileInfoRow(
                          icon: Icons.alternate_email_rounded,
                          label: '아이디',
                          value: user.uid,
                          colorScheme: cs,
                          textTheme: textTheme,
                        ),
                        _rowDivider(cs),
                        _ProfileInfoRow(
                          icon: Icons.person_rounded,
                          label: '이름',
                          value: user.uname,
                          colorScheme: cs,
                          textTheme: textTheme,
                        ),
                        _rowDivider(cs),
                        _ProfileInfoRow(
                          icon: Icons.verified_user_outlined,
                          label: '권한',
                          value: user.role.labelKo,
                          colorScheme: cs,
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _loggingOut ? null : _onLogoutPressed,
                    child: _loggingOut
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.error,
                            ),
                          )
                        : Text(
                            '로그아웃',
                            style: TextStyle(
                              color: cs.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => vm.loadCurrentUser(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  static Widget _rowDivider(ColorScheme cs) {
    return Divider(
      height: 1,
      thickness: 1,
      color: cs.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.uname,
    required this.colorScheme,
    required this.textTheme,
  });

  final String uname;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final initial = uname.isNotEmpty
        ? String.fromCharCodes(uname.runes.take(1))
        : '?';
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            initial,
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          uname,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '로그인 계정',
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
