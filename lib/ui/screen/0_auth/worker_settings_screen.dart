import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/datasources/local/worker_supply_map_preferences_storage.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/presentation/viewmodel/large_text_mode_provider.dart';
import 'package:w0001/presentation/viewmodel/terms_providers.dart';
import 'package:w0001/presentation/viewmodel/theme_mode_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_supply_map_providers.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_private_info_entry.dart';
import 'package:w0001/ui/screen/0_auth/widgets/terms_detail_sheet.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
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
      builder: (ctx) => const AppLoadingIndicator(
        size: 74,
        label: '약관 불러오는 중...',
      ),
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
      final detail =
          await ref.read(termsUseCaseProvider).getTermDetail(term.id);

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
                    '비밀번호·전화번호·세무정산·역할·스킬',
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

              const ProfileSectionTitle('근로 정보'),
              SizedBox(height: context.rsi(8)),
              ProfileInsetPanel(
                padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
                child: const WorkerPrivateInfoEntry(embedded: true),
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

              const ProfileSectionTitle('지도'),
              SizedBox(height: context.rsi(8)),
              ProfileInsetPanel(
                padding: EdgeInsets.all(context.rsi(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주유소 유종 가격 표시',
                      style: TextStyle(
                        fontSize: context.rs(14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: context.rsi(4)),
                    Text(
                      '지도 탭 주유소 유종 표시 방식을 선택하세요',
                      style: TextStyle(
                        fontSize: context.rs(12),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: context.rsi(10)),
                    Consumer(
                      builder: (context, ref, _) {
                        final selectedMode =
                            ref.watch(workerSupplyFuelPriceDisplayModeProvider);
                        Widget modeButton(
                          WorkerSupplyFuelPriceDisplayMode mode,
                          String label,
                        ) {
                          final isSelected = selectedMode == mode;
                          return Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                ref
                                    .read(
                                        workerSupplyFuelPriceDisplayModeProvider
                                            .notifier)
                                    .setMode(mode);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rsi(10),
                                  vertical: context.rsi(10),
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: context.rs(13),
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Row(
                          children: [
                            modeButton(
                              WorkerSupplyFuelPriceDisplayMode.gasoline,
                              '휘발유',
                            ),
                            SizedBox(width: context.rsi(8)),
                            modeButton(
                              WorkerSupplyFuelPriceDisplayMode.diesel,
                              '경유',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
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
                        Icons.info_outline,
                        color: colorScheme.primary,
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
                        color: colorScheme.primary,
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
                        color: colorScheme.primary,
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
            ],
          ),
        ),
      ),
    );
  }
}
