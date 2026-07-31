import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/notification_settings_model.dart';
import 'package:w0001/presentation/viewmodel/notification_settings_providers.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/responsive_page_shell.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 알림 설정 화면
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('알림 설정'),
        backgroundColor: colorScheme.surface,
      ),
      body: ResponsivePageShell(
        child: settingsAsync.when(
          data: (settings) => _buildContent(context, ref, settings),
          loading: () => const AppLoadingIndicator(label: '알림 설정 불러오는 중...'),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '알림 설정을 불러올 수 없습니다',
                  style: TextStyle(
                    fontSize: context.rs(16),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: context.rsi(16)),
                OutlinedButton(
                  onPressed: () {
                    ref
                        .read(notificationSettingsNotifierProvider.notifier)
                        .refresh();
                  },
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings settings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppRefreshIndicator(
      onRefresh: () async {
        await ref.read(notificationSettingsNotifierProvider.notifier).sync();
      },
      child: ListView(
        padding: EdgeInsets.symmetric(
          vertical: context.rsi(16),
          horizontal: context.rsi(20),
        ),
        children: [
          Text(
            '받고 싶은 알림을 선택하세요',
            style: TextStyle(
              fontSize: context.rs(14),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.rsi(20)),

          // 알림 카테고리 섹션
          _buildSection(
            context,
            title: '작업 관련',
            items: [
              NotificationType.workAssignment,
              NotificationType.workInstruction,
              NotificationType.photoUpload,
            ],
            settings: settings,
            ref: ref,
          ),

          SizedBox(height: context.rsi(24)),

          _buildSection(
            context,
            title: '공지사항',
            items: [
              NotificationType.announcementGlobal,
              NotificationType.announcementPlace,
            ],
            settings: settings,
            ref: ref,
          ),

          SizedBox(height: context.rsi(24)),

          SizedBox(height: context.rsi(32)),

          // 안내 문구
          Container(
            padding: EdgeInsets.all(context.rsi(16)),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(context.rsi(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: context.rsi(20),
                      color: colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: context.rsi(8)),
                    Text(
                      '알림 설정 안내',
                      style: TextStyle(
                        fontSize: context.rs(14),
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rsi(12)),
                Text(
                  '• 계정 관련 알림(승인, 정지 등)은 항상 수신됩니다.\n'
                  '• 기기 설정에서 알림을 끈 경우 여기서 켜도 알림이 오지 않습니다.\n'
                  '• 설정은 즉시 적용되며 서버에 자동 저장됩니다.',
                  style: TextStyle(
                    fontSize: context.rs(13),
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<NotificationType> items,
    required NotificationSettings settings,
    required WidgetRef ref,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: context.rsi(4),
            bottom: context.rsi(12),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: context.rs(16),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(context.rsi(12)),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final type = entry.value;
              final isLast = index == items.length - 1;

              return _buildSettingItem(
                context,
                ref: ref,
                type: type,
                isEnabled: settings.isEnabled(type),
                isLast: isLast,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required WidgetRef ref,
    required NotificationType type,
    required bool isEnabled,
    required bool isLast,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ref
                  .read(notificationSettingsNotifierProvider.notifier)
                  .toggle(type);
            },
            borderRadius: isLast
                ? BorderRadius.vertical(
                    bottom: Radius.circular(context.rsi(12)),
                  )
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rsi(16),
                vertical: context.rsi(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: context.rs(15),
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: isEnabled,
                    onChanged: (value) {
                      ref
                          .read(notificationSettingsNotifierProvider.notifier)
                          .toggle(type);
                    },
                    activeColor: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            indent: context.rsi(16),
            color: colorScheme.outlineVariant,
          ),
      ],
    );
  }
}
