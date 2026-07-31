import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_profile_notifier.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/responsive_layout.dart';

/// `GET /users/me/worker-profile` — 현장 역할·경력 (조회 전용).
class ProfileWorkerRankCareerSection extends ConsumerWidget {
  const ProfileWorkerRankCareerSection({super.key, this.compact = false});

  final bool compact;

  String _rankLabel(String rank) => rank.trim().isEmpty ? '미선택' : rank.trim();

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: context.rs(18), color: cs.primary),
        SizedBox(width: context.rsi(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              SizedBox(height: context.rsi(2)),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _careerLabel(WorkerProfileRead pr, {String? sessionCareer}) {
    final fromProfile = CareerInputUtils.formatForDisplay(pr.career);
    if (fromProfile.isNotEmpty) return fromProfile;
    final fallback = CareerInputUtils.formatForDisplay(sessionCareer ?? '');
    if (fallback.isNotEmpty) return fallback;
    return '미등록';
  }

  Widget _readOnly(
    BuildContext context,
    WorkerProfileRead pr, {
    String? sessionCareer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoRow(
          context,
          icon: Icons.badge_outlined,
          label: '현장 역할',
          value: _rankLabel(pr.workerRank),
        ),
        SizedBox(height: context.rsi(compact ? 8 : 10)),
        _infoRow(
          context,
          icon: Icons.history_edu_outlined,
          label: '경력',
          value: _careerLabel(pr, sessionCareer: sessionCareer),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workerProfileProvider);
    final sessionCareer = ref.watch(authSessionProvider).asData?.value?.career;

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => Skeletonizer(
        enabled: true,
        child: _readOnly(
          context,
          const WorkerProfileRead(workerRank: '기공', career: '5년'),
        ),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(context.rsi(16)),
        child: Text('$e'),
      ),
      data: (p) => _readOnly(
        context,
        p ?? const WorkerProfileRead(),
        sessionCareer: sessionCareer,
      ),
    );
  }
}
