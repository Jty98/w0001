import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/user_notification_models.dart';
import 'package:w0001/presentation/viewmodel/user_notifications_providers.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/fcm/fcm_push_router.dart';
import 'package:w0001/util/notifications/notification_time_label.dart';
import 'package:w0001/util/responsive_layout.dart';

class NotificationInboxScreen extends ConsumerStatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  ConsumerState<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState
    extends ConsumerState<NotificationInboxScreen> {
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(userNotificationInboxProvider.notifier).reload();
    });
  }

  Future<void> _openItem(UserNotificationItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(userNotificationInboxProvider.notifier).markRead(item);
      final container = rootProviderContainer;
      if (container != null) {
        final nav = Map<String, dynamic>.from(item.payload);
        nav.putIfAbsent('type', () => item.type);
        await handleFcmNavigationFromData(container, nav);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDeleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알림 모두 지우기'),
        content: const Text('알림함의 모든 내역을 삭제합니다.\n(공지·일정 데이터는 그대로입니다.)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(userNotificationInboxProvider.notifier).deleteAll();
  }

  Future<void> _deleteOne(UserNotificationItem item) async {
    await ref.read(userNotificationInboxProvider.notifier).deleteOne(item);
  }

  Widget _emptyBody(BuildContext context, ColorScheme cs, TextTheme tt) {
    return AppRefreshIndicator(
      onRefresh: () =>
          ref.read(userNotificationInboxProvider.notifier).reload(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(28)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: context.rs(64),
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                  SizedBox(height: context.rsi(16)),
                  Text(
                    '알림이 없습니다',
                    textAlign: TextAlign.center,
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: context.rsi(10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userNotificationInboxProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: async.maybeWhen(
              data: (items) => items.isEmpty ? null : _confirmDeleteAll,
              orElse: () => null,
            ),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const AppLoadingIndicator(label: '알림 불러오는 중...'),
          error: (e, _) => Center(
            child: Padding(
              padding: EdgeInsets.all(context.rsi(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: context.rs(48), color: cs.error),
                  SizedBox(height: context.rsi(12)),
                  Text(
                    '알림을 불러오지 못했습니다',
                    style: tt.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.rsi(8)),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  SizedBox(height: context.rsi(16)),
                  FilledButton(
                    onPressed: () => ref
                        .read(userNotificationInboxProvider.notifier)
                        .reload(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _emptyBody(context, cs, tt);
            }

            return AppRefreshIndicator(
              onRefresh: () =>
                  ref.read(userNotificationInboxProvider.notifier).reload(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: context.rsi(8)),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: context.rsi(16),
                  endIndent: context.rsi(16),
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _NotificationTile(
                    item: item,
                    busy: _busy,
                    onTap: () => _openItem(item),
                    onDelete: () => _deleteOne(item),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.busy,
    required this.onTap,
    required this.onDelete,
  });

  final UserNotificationItem item;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unread = !item.isRead;

    return Dismissible(
      key: ValueKey<String>(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: context.rsi(20)),
        color: cs.errorContainer,
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: unread
            ? AppColors.primaryColor.withValues(alpha: 0.06)
            : Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(16),
              context.rsi(12),
              context.rsi(8),
              context.rsi(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread)
                  Padding(
                    padding: EdgeInsets.only(
                      top: context.rsi(6),
                      right: context.rsi(10),
                    ),
                    child: Container(
                      width: context.rs(8),
                      height: context.rs(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: tt.titleSmall?.copyWith(
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      if (item.body.isNotEmpty) ...[
                        SizedBox(height: context.rsi(4)),
                        Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      SizedBox(height: context.rsi(6)),
                      Text(
                        notificationTimeLabel(item.createdAt),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '삭제',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.close,
                    size: context.rs(20),
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
