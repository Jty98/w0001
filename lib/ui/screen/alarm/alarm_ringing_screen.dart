import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

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
    final tt = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm, size: context.rs(52), color: cs.primary),
                  SizedBox(height: context.rsi(18)),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: context.rsi(10)),
                  Text(
                    timeText,
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                  if (body.trim().isNotEmpty) ...[
                    SizedBox(height: context.rsi(14)),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  SizedBox(height: context.rsi(28)),
                  FilledButton.icon(
                    onPressed: () async => onStop(),
                    icon: const Icon(Icons.notifications_off_outlined),
                    label: const Text('알람 끄기'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(double.infinity, context.rs(52)),
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
