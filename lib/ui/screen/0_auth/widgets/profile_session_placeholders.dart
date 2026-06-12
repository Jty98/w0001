import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

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

/// GET `/auth/me` 최초 로딩 시 프로필 화면 스켈레톤.
class ProfileSessionLoadingBody extends StatelessWidget {
  const ProfileSessionLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Skeletonizer(
      enabled: true,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.rsi(18),
            context.rsi(14),
            context.rsi(18),
            context.rsi(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: context.rs(28),
                    backgroundColor: cs.surfaceContainerHighest,
                    child: const Icon(Icons.person_outline),
                  ),
                  SizedBox(width: context.rsi(14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '사용자 이름',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: context.rsi(6)),
                        Text(
                          '역할 · 소속',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.rsi(22)),
              Text(
                '내 정보',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: context.rsi(10)),
              Material(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(context.rsi(16)),
                child: Padding(
                  padding: EdgeInsets.all(context.rsi(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('아이디'),
                      SizedBox(height: 8),
                      Text('승인 상태'),
                      SizedBox(height: 8),
                      Text('계정 유형'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.rsi(22)),
              Text(
                '워커 프로필',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: context.rsi(10)),
              Material(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(context.rsi(16)),
                child: Padding(
                  padding: EdgeInsets.all(context.rsi(16)),
                  child: const Text('주특기 · 스킬 영역'),
                ),
              ),
            ],
          ),
        ),
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
        padding: EdgeInsets.all(context.rsi(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: context.rs(48), color: cs.error),
            SizedBox(height: context.rsi(12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium,
            ),
            SizedBox(height: context.rsi(20)),
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
