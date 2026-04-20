import 'package:flutter/material.dart';

class AlarmRingingScreen extends StatelessWidget {
  const AlarmRingingScreen({
    super.key,
    required this.title,
    required this.body,
    required this.timeText,
    required this.onStop,
  });

  final String title;
  final String body;
  final String timeText;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm, size: 52, color: cs.primary),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                  if (body.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () async => onStop(),
                    icon: const Icon(Icons.notifications_off_outlined),
                    label: const Text('알람 끄기'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatHm(DateTime d) {
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
