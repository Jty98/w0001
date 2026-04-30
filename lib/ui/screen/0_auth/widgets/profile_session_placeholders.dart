import 'package:flutter/material.dart';

class ProfileMissingSessionBody extends StatelessWidget {
  const ProfileMissingSessionBody({
    super.key,
    required this.onRetryLoad,
  });

  final VoidCallback onRetryLoad;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('로그인 정보가 없습니다.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetryLoad,
            child: const Text('내 정보 불러오기'),
          ),
        ],
      ),
    );
  }
}

class ProfileSessionErrorBody extends StatelessWidget {
  const ProfileSessionErrorBody({
    super.key,
    required this.message,
    required this.onRetryLoad,
  });

  final String message;
  final VoidCallback onRetryLoad;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetryLoad,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
