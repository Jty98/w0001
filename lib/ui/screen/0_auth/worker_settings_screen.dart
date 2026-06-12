import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/presentation/viewmodel/theme_mode_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/settings_logout_section.dart';
import 'package:w0001/ui/screen/0_auth/widgets/terms_detail_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 설정 화면
class WorkerSettingsScreen extends ConsumerWidget {
  const WorkerSettingsScreen({super.key});

  Future<void> _showTermByType(
    BuildContext context,
    WidgetRef ref,
    TermType type,
  ) async {
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 약관 목록 가져오기
      final terms = await ref.read(termsUseCaseProvider).listLatest();

      // 해당 타입의 약관 찾기
      final term = terms.where((t) => t.type == type).firstOrNull;
      
      if (term == null) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('약관을 찾을 수 없습니다.')),
        );
        return;
      }

      // 약관 상세 가져오기
      final detail = await ref.read(termsUseCaseProvider).getTermDetail(term.id);
      
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기

      // 약관 상세 표시
      await showTermsDetailSheet(context, detail: detail);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('약관을 불러올 수 없습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
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
              // 헤더
              Padding(
                padding: EdgeInsets.only(
                  left: context.rsi(4),
                  bottom: context.rsi(16),
                ),
                child: Text(
                  '설정',
                  style: TextStyle(
                    fontSize: context.rs(24),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),

              // 프로필 설정 섹션
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
                    '프로필 설정',
                    style: TextStyle(fontSize: context.rs(14)),
                  ),
                  subtitle: Text(
                    '계정, 전화번호, 세무정산, 역할, 스킬',
                    style: TextStyle(fontSize: context.rs(12)),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: context.rsi(20),
                  ),
                  onTap: () => context.push('/settings/profile'),
                ),
              ),

              SizedBox(height: context.rsi(20)),

              // 알림 설정 섹션
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
                    '받고 싶은 알림을 선택하세요',
                    style: TextStyle(fontSize: context.rs(12)),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: context.rsi(20),
                  ),
                  onTap: () => context.push('/settings/notification-settings'),
                ),
              ),

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
                            color: colorScheme.onSurfaceVariant,
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
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.info_outline,
                        color: colorScheme.onSurfaceVariant,
                        size: context.rsi(22),
                      ),
                      title: Text(
                        '버전 정보',
                        style: TextStyle(fontSize: context.rs(14)),
                      ),
                      subtitle: Text(
                        'v1.0.0',
                        style: TextStyle(fontSize: context.rs(12)),
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
                        Icons.article_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: context.rsi(22),
                      ),
                      title: Text(
                        '이용약관',
                        style: TextStyle(fontSize: context.rs(14)),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: context.rsi(20),
                      ),
                      onTap: () => _showTermByType(
                        context,
                        ref,
                        TermType.service,
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
                        color: colorScheme.onSurfaceVariant,
                        size: context.rsi(22),
                      ),
                      title: Text(
                        '개인정보처리방침',
                        style: TextStyle(fontSize: context.rs(14)),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: context.rsi(20),
                      ),
                      onTap: () => _showTermByType(
                        context,
                        ref,
                        TermType.privacy,
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
