import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/presentation/viewmodel/worker_profile_notifier.dart';
import 'package:w0001/ui/screen/0_auth/widgets/worker_skills_editor.dart';
import 'package:w0001/util/responsive_layout.dart';

/// `GET/PUT /users/me/worker-profile` — 주특기 표시·수정.
class ProfileWorkerSkillsSection extends ConsumerStatefulWidget {
  const ProfileWorkerSkillsSection({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<ProfileWorkerSkillsSection> createState() =>
      _ProfileWorkerSkillsSectionState();
}

class _ProfileWorkerSkillsSectionState
    extends ConsumerState<ProfileWorkerSkillsSection> {
  final _editorKey = GlobalKey<WorkerSkillsEditorState>();
  var _editing = false;

  bool _isProfileEmpty(WorkerProfileRead pr) =>
      pr.primarySpecialty?.trim().isEmpty ?? true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workerProfileProvider);

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => Skeletonizer(
        enabled: true,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.rsi(widget.compact ? 16 : 28),
          ),
          child: WorkerSkillsEditor(
            compact: widget.compact,
            readOnlyUntilEdit: true,
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(context.rsi(16)),
        child: Text('$e'),
      ),
      data: (p) {
        final pr = p ?? const WorkerProfileRead();
        final showEditForm = _editing || _isProfileEmpty(pr);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            WorkerSkillsEditor(
              key: _editorKey,
              compact: widget.compact,
              initialPrimarySpecialty: pr.primarySpecialty,
              readOnlyUntilEdit: !showEditForm,
              onChanged: showEditForm ? () => setState(() {}) : null,
            ),
            if (!showEditForm) ...[
              SizedBox(height: context.rsi(widget.compact ? 12 : 16)),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: Icon(Icons.edit_outlined, size: context.rsi(18)),
                  label: const Text('수정'),
                ),
              ),
            ] else ...[
              SizedBox(height: context.rsi(widget.compact ? 10 : 14)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final serverPr =
                            ref.read(workerProfileProvider).asData?.value ?? pr;
                        _editorKey.currentState?.cancelPrimaryEdit();
                        setState(() {
                          _editing = _isProfileEmpty(serverPr);
                        });
                      },
                      child: const Text('취소'),
                    ),
                  ),
                  SizedBox(width: context.rsi(10)),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_editorKey.currentState?.hasPrimary ?? false)
                          ? () async {
                              try {
                                final serverPr = ref
                                        .read(workerProfileProvider)
                                        .asData
                                        ?.value ??
                                    pr;
                                final draft =
                                    _editorKey.currentState!.toProfile(
                                  workerRank: serverPr.workerRank,
                                  career: serverPr.career,
                                );
                                await ref
                                    .read(workerProfileProvider.notifier)
                                    .save(
                                      WorkerProfileRead(
                                        uid: serverPr.uid,
                                        primarySpecialty:
                                            draft.primarySpecialty,
                                        workerRank: serverPr.workerRank,
                                        career: serverPr.career,
                                      ),
                                    );
                                if (!context.mounted) return;
                                setState(() => _editing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('워커 프로필을 저장했습니다.'),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          : null,
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
              if (!(_editorKey.currentState?.hasPrimary ?? false))
                Padding(
                  padding: EdgeInsets.only(
                    top: context.rsi(widget.compact ? 6 : 8),
                  ),
                  child: Text(
                    '주특기를 입력한 뒤 저장할 수 있어요.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
