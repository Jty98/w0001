import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/presentation/viewmodel/user_notifications_providers.dart';
import 'package:w0001/theme/app_colors.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 상황판 앱바 — 알림함 진입 + 미읽음 주황 점.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(userNotificationUnreadCountProvider);

    return IconButton(
      tooltip: unread > 0 ? '알림 $unread건' : '알림',
      onPressed: () => context.push('/dashboard/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.primaryColor,
        smallSize: context.rs(9),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
