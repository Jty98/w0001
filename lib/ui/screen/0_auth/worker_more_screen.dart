import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/widgets/settings_logout_section.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업자 전용 더보기 허브
class WorkerMoreScreen extends StatelessWidget {
  const WorkerMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(12),
            context.rsi(16),
            context.rsi(24),
          ),
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: context.rsi(4),
                bottom: context.rsi(16),
              ),
              child: Text(
                '더보기',
                style: TextStyle(
                  fontSize: context.rs(24),
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const ProfileSectionTitle('메뉴'),
            SizedBox(height: context.rsi(8)),
            ProfileInsetPanel(
              padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.settings_outlined,
                      color: colorScheme.primary,
                      size: context.rsi(22),
                    ),
                    title: Text(
                      '설정',
                      style: TextStyle(fontSize: context.rs(14)),
                    ),
                    subtitle: Text(
                      '프로필, 알림, 근로 정보, 앱 설정',
                      style: TextStyle(fontSize: context.rs(12)),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: context.rsi(20),
                    ),
                    onTap: () => context.push('/settings/worker-settings'),
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
                      '근로·정산 내역',
                      style: TextStyle(fontSize: context.rs(14)),
                    ),
                    subtitle: Text(
                      '기간별 합계·현장별 투입·근무 건수',
                      style: TextStyle(fontSize: context.rs(12)),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: context.rsi(20),
                    ),
                    onTap: () => context.push('/settings/earnings'),
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
                      '현장 사전',
                      style: TextStyle(fontSize: context.rs(14)),
                    ),
                    subtitle: Text(
                      '자재/용어/시공사례/공정 가이드',
                      style: TextStyle(fontSize: context.rs(12)),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: context.rsi(20),
                    ),
                    onTap: () => context.push('/settings/field-knowledge'),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.rsi(20)),
            const SettingsLogoutSection(),
            SizedBox(height: context.rsi(8)),
          ],
        ),
      ),
    );
  }
}
