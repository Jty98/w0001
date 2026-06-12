import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/presentation/viewmodel/worker_profile_notifier.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_rank_career_fields.dart';
import 'package:w0001/util/responsive_layout.dart';

/// `GET/PUT /users/me/worker-profile` — 현장 역할·경력.
class ProfileWorkerRankCareerSection extends ConsumerStatefulWidget {
  const ProfileWorkerRankCareerSection({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<ProfileWorkerRankCareerSection> createState() =>
      _ProfileWorkerRankCareerSectionState();
}

class _ProfileWorkerRankCareerSectionState
    extends ConsumerState<ProfileWorkerRankCareerSection> {
  final _fieldsKey = GlobalKey<WorkerRankCareerFieldsState>();
  var _editing = false;

  String _rankLabel(String rank) =>
      rank.trim().isEmpty ? '미선택' : rank.trim();

  Widget _readOnly(WorkerProfileRead pr, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoRow(
          context,
          icon: Icons.badge_outlined,
          label: '현장 역할',
          value: _rankLabel(pr.workerRank),
        ),
        SizedBox(height: context.rsi(widget.compact ? 8 : 10)),
        _infoRow(
          context,
          icon: Icons.history_edu_outlined,
          label: '경력',
          value: pr.career.trim().isEmpty ? '미등록' : pr.career.trim(),
          multiline: true,
        ),
        SizedBox(height: context.rsi(widget.compact ? 12 : 16)),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _editing = true),
            icon: Icon(Icons.edit_outlined, size: context.rsi(18)),
            label: const Text('수정'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: context.rsi(16),
                vertical: context.rsi(8),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.rs(8)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool multiline = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
                maxLines: multiline ? null : 1,
                overflow: multiline ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workerProfileProvider);
    final cs = Theme.of(context).colorScheme;

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => Skeletonizer(
        enabled: true,
        child: _readOnly(
          const WorkerProfileRead(workerRank: '기공', career: '현장 경력'),
          cs,
        ),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(context.rsi(16)),
        child: Text('$e'),
      ),
      data: (p) {
        final pr = p ?? const WorkerProfileRead();
        if (!_editing) {
          return _readOnly(pr, cs);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorkerRankCareerFields(
              key: _fieldsKey,
              initialRank: pr.workerRank,
              initialCareer: pr.career,
              compact: widget.compact,
            ),
            SizedBox(height: context.rsi(widget.compact ? 10 : 14)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _editing = false),
                    child: const Text('취소'),
                  ),
                ),
                SizedBox(width: context.rsi(10)),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final fields = _fieldsKey.currentState;
                      if (fields == null) return;
                      try {
                        await ref.read(workerProfileProvider.notifier).save(
                              fields.mergeInto(pr),
                            );
                        if (!context.mounted) return;
                        setState(() => _editing = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('현장 역할·경력을 저장했습니다.')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    },
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
