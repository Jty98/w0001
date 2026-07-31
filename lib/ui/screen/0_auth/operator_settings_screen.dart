import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/presentation/viewmodel/large_text_mode_provider.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/presentation/viewmodel/theme_mode_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/settings_logout_section.dart';
import 'package:w0001/ui/screen/0_auth/widgets/terms_detail_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 관리자 설정 화면
class OperatorSettingsScreen extends ConsumerStatefulWidget {
  const OperatorSettingsScreen({super.key});

  @override
  ConsumerState<OperatorSettingsScreen> createState() =>
      _OperatorSettingsScreenState();
}

class _OperatorSettingsScreenState
    extends ConsumerState<OperatorSettingsScreen> {
  static const String _appVersion = '1.0.0';

  Future<void> _showTermsDetail(BuildContext context, TermType type) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AppLoadingIndicator(),
    );

    try {
      final terms = await ref.read(termsUseCaseProvider).listLatest();
      final term = terms.where((t) => t.type == type).firstOrNull;

      if (term == null) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('약관을 찾을 수 없습니다.')),
        );
        return;
      }

      final detail =
          await ref.read(termsUseCaseProvider).getTermDetail(term.id);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      await showTermsDetailSheet(context, detail: detail);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('약관을 불러올 수 없습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = ref.watch(authSessionProvider);
    final user = session.asData?.value;
    final canAccessWorkerMgmt =
        user?.role.canAccessWorkerManagementMenus ?? false;
    final canManageMemberAccounts = user?.role.canManageMemberAccounts ?? false;
    final canManageExtras = user?.role.canManageExtras ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(12),
            context.rsi(16),
            context.rsi(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 프로필 섹션
              const ProfileSectionTitle('프로필'),
              SizedBox(height: context.rsi(8)),
              ProfileInsetPanel(
                padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.person_outline,
                    color: colorScheme.primary,
                    size: context.rsi(22),
                  ),
                  title: Text(
                    '내 정보',
                    style: TextStyle(fontSize: context.rs(14)),
                  ),
                  subtitle: Text(
                    '이름·비밀번호·전화번호',
                    style: TextStyle(fontSize: context.rs(12)),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: context.rsi(20),
                  ),
                  onTap: () => context.push('/settings/account'),
                ),
              ),

              SizedBox(height: context.rsi(20)),

              // 알림 섹션
              const ProfileSectionTitle('알림'),
              SizedBox(height: context.rsi(8)),
              ProfileInsetPanel(
                padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.notifications_outlined,
                    color: colorScheme.primary,
                    size: context.rsi(22),
                  ),
                  title: Text(
                    '알림 설정',
                    style: TextStyle(fontSize: context.rs(14)),
                  ),
                  subtitle: Text(
                    '알림 카테고리 관리',
                    style: TextStyle(fontSize: context.rs(12)),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: context.rsi(20),
                  ),
                  onTap: () => context.push('/settings/notification-settings'),
                ),
              ),

              // 작업자 관리 섹션
              if (canAccessWorkerMgmt) ...[
                SizedBox(height: context.rsi(20)),
                const ProfileSectionTitle('작업자 관리'),
                SizedBox(height: context.rsi(8)),
                ProfileInsetPanel(
                  padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.rate_review_outlined,
                          color: colorScheme.primary,
                          size: context.rsi(22),
                        ),
                        title: Text(
                          '작업자 평가/메모',
                          style: TextStyle(fontSize: context.rs(14)),
                        ),
                        subtitle: Text(
                          '작업자별 평가 및 메모 관리',
                          style: TextStyle(fontSize: context.rs(12)),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: context.rsi(20),
                        ),
                        onTap: () =>
                            context.push('/dashboard/worker-mgmt/memos'),
                      ),
                      Divider(
                        height: 1,
                        indent: context.rsi(48),
                        color: colorScheme.outlineVariant,
                      ),
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.payments_outlined,
                          color: colorScheme.primary,
                          size: context.rsi(22),
                        ),
                        title: Text(
                          '역할별 기본 일당',
                          style: TextStyle(fontSize: context.rs(14)),
                        ),
                        subtitle: Text(
                          '조공·준기공·기공·반장·감리 역할별 인건비',
                          style: TextStyle(fontSize: context.rs(12)),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: context.rsi(20),
                        ),
                        onTap: () =>
                            context.push('/dashboard/worker-mgmt/rank-wages'),
                      ),
                      Divider(
                        height: 1,
                        indent: context.rsi(48),
                        color: colorScheme.outlineVariant,
                      ),
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.primary,
                          size: context.rsi(22),
                        ),
                        title: Text(
                          '트러블 페어 관리',
                          style: TextStyle(fontSize: context.rs(14)),
                        ),
                        subtitle: Text(
                          '작업자 간 트러블 관리',
                          style: TextStyle(fontSize: context.rs(12)),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: context.rsi(20),
                        ),
                        onTap: () =>
                            context.push('/dashboard/worker-mgmt/troubles'),
                      ),
                    ],
                  ),
                ),
              ],

              // 회원 관리 섹션
              if (canManageMemberAccounts) ...[
                SizedBox(height: context.rsi(20)),
                const ProfileSectionTitle('회원 관리'),
                SizedBox(height: context.rsi(8)),
                ProfileInsetPanel(
                  padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.people_outline,
                      color: colorScheme.primary,
                      size: context.rsi(22),
                    ),
                    title: Text(
                      '회원 승인 및 관리',
                      style: TextStyle(fontSize: context.rs(14)),
                    ),
                    subtitle: Text(
                      '회원 가입 승인, 활동 제어, 역할 변경',
                      style: TextStyle(fontSize: context.rs(12)),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: context.rsi(20),
                    ),
                    onTap: () => context.push('/dashboard/member-queue'),
                  ),
                ),
              ],

              if (canManageExtras) ...[
                SizedBox(height: context.rsi(20)),
                const ProfileSectionTitle('부가기능'),
                SizedBox(height: context.rsi(8)),
                ProfileInsetPanel(
                  padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.format_quote_rounded,
                          color: colorScheme.primary,
                          size: context.rsi(22),
                        ),
                        title: Text(
                          '오늘의 명언',
                          style: TextStyle(fontSize: context.rs(14)),
                        ),
                        subtitle: Text(
                          '명언 풀·자동 선정·오늘 직접 지정',
                          style: TextStyle(fontSize: context.rs(12)),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: context.rsi(20),
                        ),
                        onTap: () =>
                            context.push('/dashboard/extras/daily-quotes'),
                      ),
                      Divider(
                        height: 1,
                        indent: context.rsi(48),
                        color: colorScheme.outlineVariant,
                      ),
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.menu_book_outlined,
                          color: colorScheme.primary,
                          size: context.rsi(22),
                        ),
                        title: Text(
                          '현장 지식 사전',
                          style: TextStyle(fontSize: context.rs(14)),
                        ),
                        subtitle: Text(
                          '자재·용어·베스트·워스트 사례',
                          style: TextStyle(fontSize: context.rs(12)),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: context.rsi(20),
                        ),
                        onTap: () =>
                            context.push('/dashboard/extras/knowledge'),
                      ),
                      Divider(
                        height: 1,
                        indent: context.rsi(48),
                        color: colorScheme.outlineVariant,
                      ),
                      ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.local_phone_outlined,
                          color: colorScheme.primary,
                          size: context.rsi(22),
                        ),
                        title: Text(
                          '공용 거래처 전화번호',
                          style: TextStyle(fontSize: context.rs(14)),
                        ),
                        subtitle: Text(
                          '관리자 공용 거래처 연락처 관리부',
                          style: TextStyle(fontSize: context.rs(12)),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: context.rsi(20),
                        ),
                        onTap: () =>
                            context.push('/dashboard/extras/vendor-phones'),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: context.rsi(20)),

              // 앱 정보 섹션
              const ProfileSectionTitle('앱 정보'),
              SizedBox(height: context.rsi(8)),
              ProfileInsetPanel(
                padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                child: Column(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final themeMode = ref.watch(themeModeProvider);
                        final isDark = themeMode == ThemeMode.dark;

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isDark ? Icons.dark_mode : Icons.light_mode,
                            color: colorScheme.primary,
                            size: context.rsi(22),
                          ),
                          title: Text(
                            '다크 모드',
                            style: TextStyle(fontSize: context.rs(14)),
                          ),
                          subtitle: Text(
                            isDark ? '다크 모드 사용 중' : '라이트 모드 사용 중',
                            style: TextStyle(fontSize: context.rs(12)),
                          ),
                          trailing: Switch(
                            value: isDark,
                            onChanged: (value) {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .toggleDarkMode(value);
                            },
                            activeColor: colorScheme.primary,
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: context.rsi(48),
                      color: colorScheme.outlineVariant,
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final largeText = ref.watch(largeTextModeProvider);
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.text_fields_rounded,
                            color: colorScheme.primary,
                            size: context.rsi(22),
                          ),
                          title: Text(
                            '큰 글씨 모드',
                            style: TextStyle(fontSize: context.rs(14)),
                          ),
                          subtitle: Text(
                            largeText ? '큰 글씨 적용됨' : '일반 글씨 크기',
                            style: TextStyle(fontSize: context.rs(12)),
                          ),
                          trailing: Switch(
                            value: largeText,
                            onChanged: (value) {
                              ref
                                  .read(largeTextModeProvider.notifier)
                                  .setEnabled(value);
                            },
                            activeColor: colorScheme.primary,
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: context.rsi(48),
                      color: colorScheme.outlineVariant,
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.description_outlined,
                        color: colorScheme.primary,
                        size: context.rsi(22),
                      ),
                      title: Text(
                        '서비스 이용약관',
                        style: TextStyle(fontSize: context.rs(14)),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: context.rsi(20),
                      ),
                      onTap: () => unawaited(
                        _showTermsDetail(context, TermType.service),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: context.rsi(48),
                      color: colorScheme.outlineVariant,
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.privacy_tip_outlined,
                        color: colorScheme.primary,
                        size: context.rsi(22),
                      ),
                      title: Text(
                        '개인정보 처리방침',
                        style: TextStyle(fontSize: context.rs(14)),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: context.rsi(20),
                      ),
                      onTap: () => unawaited(
                        _showTermsDetail(context, TermType.privacy),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: context.rsi(48),
                      color: colorScheme.outlineVariant,
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: context.rsi(22),
                      ),
                      title: Text(
                        '앱 버전',
                        style: TextStyle(fontSize: context.rs(14)),
                      ),
                      subtitle: Text(
                        _appVersion,
                        style: TextStyle(fontSize: context.rs(12)),
                      ),
                    ),
                  ],
                ),
              ),

              const SettingsLogoutSection(),
              SizedBox(height: context.rsi(8)),
            ],
          ),
        ),
      ),
    );
  }
}
