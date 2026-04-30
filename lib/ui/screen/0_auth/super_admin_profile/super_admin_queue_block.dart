import 'package:flutter/material.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_empty_banner.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_member_card.dart';

class SuperAdminQueueBlock extends StatelessWidget {
  const SuperAdminQueueBlock({
    super.key,
    required this.subtitle,
    required this.items,
    required this.error,
    required this.icon,
    required this.emptyMessage,
    required this.handlers,
    required this.onRetryReload,
  });

  final String subtitle;
  final List<UserRead> items;
  final Object? error;
  final IconData icon;
  final String emptyMessage;
  final SuperAdminMemberHandlers handlers;
  final VoidCallback onRetryReload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: cs.primary.withValues(alpha: 0.9)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onPrimaryContainer,
                        height: 1,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: cs.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '불러오기 실패: $error',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.error,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onRetryReload,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('다시 불러오기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (items.isEmpty)
            SuperAdminEmptyBanner(message: emptyMessage, icon: Icons.inbox_outlined)
          else
            ...items.map(
              (u) => SuperAdminMemberCard(user: u, handlers: handlers),
            ),
        ],
      ),
    );
  }
}
