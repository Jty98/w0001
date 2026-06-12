import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_mgmt_view_model.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/util/worker_mgmt_messages.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인력 hid 기준 작업자 메모·평가·트러블 페어 UI (회원 상세·작업자 목록 등에서 공통).
///
/// 데이터는 [workerMgmtHidVmProvider]·[workerMgmtHumanDirectoryProvider]에서 가져온다.
class WorkerMgmtHidContent extends ConsumerStatefulWidget {
  const WorkerMgmtHidContent({
    super.key,
    required this.workerHid,
    required this.displayName,
    this.embedInScrollView = true,
  });

  final int workerHid;
  final String displayName;

  /// `false`이면 이미 상위 [ListView]/[SingleChildScrollView] 안에 둘 때.
  final bool embedInScrollView;

  @override
  ConsumerState<WorkerMgmtHidContent> createState() =>
      WorkerMgmtHidContentState();
}

class WorkerMgmtHidContentState extends ConsumerState<WorkerMgmtHidContent> {
  var _savingMemo = false;
  var _savingConflict = false;

  SuperAdminRemoteUseCase get _uc => ref.read(superAdminRemoteUseCaseProvider);

  int get _self => widget.workerHid;

  Future<void> reload({bool silent = true}) =>
      ref.read(workerMgmtHidVmProvider(_self).notifier).reload(silent: silent);

  String _hname(List<HumanRead> humans, int hid) {
    for (final h in humans) {
      if (h.hid == hid) return h.hname;
    }
    return '이름 없음';
  }

  Future<void> _addMemo() async {
    final memoCtrl = TextEditingController();
    var noteType = 'memo';
    int? rating = 3;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('작업자 메모 / 평가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: AppSegmentedButton.styleFrom(),
                      segments: const [
                        ButtonSegment(
                          value: 'memo',
                          label: Text('메모'),
                          icon: Icon(Icons.note_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: 'evaluation',
                          label: Text('평가'),
                          icon: Icon(Icons.star_outline, size: 18),
                        ),
                      ],
                      selected: {noteType},
                      onSelectionChanged: (s) {
                        setLocal(() => noteType = s.first);
                      },
                    ),
                    if (noteType == 'evaluation') ...[
                      const SizedBox(height: 12),
                      Text('점수', style: Theme.of(ctx).textTheme.labelLarge),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: (rating ?? 3).toDouble(),
                              min: 1,
                              max: 5,
                              divisions: 4,
                              label: '${rating ?? 3}',
                              onChanged: (v) {
                                setLocal(() => rating = v.round());
                              },
                            ),
                          ),
                          Text('${rating ?? 3}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: memoCtrl,
                      autofocus: true,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: '내용',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
    final text = memoCtrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => memoCtrl.dispose());
    if (ok != true || text.isEmpty || !mounted) return;

    setState(() => _savingMemo = true);
    try {
      await _uc.workerMgmtNoteCreate(
        workerHid: _self,
        noteType: noteType,
        memo: text,
        rating: noteType == 'evaluation' ? rating : null,
      );
      await reload(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(workerMgmtUserMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMemo = false);
    }
  }

  Future<({int severity, String note})?> _askSeverityAndNote() async {
    final noteCtrl = TextEditingController();
    var severity = 2;
    final r = await showDialog<({int severity, String note})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('트러블 페어 정보'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('심각도', style: Theme.of(ctx).textTheme.labelLarge),
                Slider(
                  value: severity.toDouble(),
                  min: 1,
                  max: 3,
                  divisions: 2,
                  label: '$severity',
                  onChanged: (v) => setLocal(() => severity = v.round()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '비고 (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                    ctx, (severity: severity, note: noteCtrl.text.trim())),
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => noteCtrl.dispose());
    return r;
  }

  Future<void> _deleteTroublePairChip(int pairId, String partnerLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('트러블 페어 삭제'),
        content: Text(
          '「$partnerLabel」님과의 트러블 페어를 삭제할까요?\n삭제 후에는 같은 현장에 함께 투입할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _savingConflict = true);
    try {
      await _uc.workerMgmtConflictDelete(pairId);
      await reload(silent: true);
      ref.invalidate(workerMgmtConflictsHubProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('트러블 페어를 삭제했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(workerMgmtUserMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingConflict = false);
    }
  }

  Future<void> _editTroublePartners() async {
    final self = _self;
    final vm = ref.read(workerMgmtHidVmProvider(_self));
    final humans = ref.read(workerMgmtHumanDirectoryProvider).humans;
    final prevMap = {
      for (final e in vm.troublePairs) e.partnerHid: e.pairId,
    };
    final candidates = humans
        .where((h) => h.hdelete == 0 && h.hid != self)
        .toList()
      ..sort((a, b) => a.hname.compareTo(b.hname));
    final selected = Set<int>.from(vm.troublePairs.map((e) => e.partnerHid));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('트러블 인력 선택'),
              content: SizedBox(
                width: double.maxFinite,
                height: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${widget.displayName} 님과 같은 현장에 함께 투입되면 경고됩니다. 체크 해제 시 페어가 삭제됩니다.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (ctx, i) {
                          final h = candidates[i];
                          return CheckboxListTile(
                            value: selected.contains(h.hid),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  selected.add(h.hid);
                                } else {
                                  selected.remove(h.hid);
                                }
                              });
                            },
                            title: Text(h.hname),
                            subtitle: h.hnumber.isNotEmpty
                                ? Text(
                                    h.hnumber,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'ok'),
                  child: const Text('적용'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted || result != 'ok') return;
    final prev = prevMap.keys.toSet();
    final toAdd = selected.difference(prev);
    final toRemove = prev.difference(selected);
    if (toAdd.isEmpty && toRemove.isEmpty) return;

    ({int severity, String note})? pack;
    if (toAdd.isNotEmpty) {
      pack = await _askSeverityAndNote();
      if (!mounted || pack == null) return;
    }

    setState(() => _savingConflict = true);
    try {
      if (toRemove.isNotEmpty) {
        var missingId = false;
        for (final hid in toRemove) {
          final pid = prevMap[hid];
          if (pid != null) {
            await _uc.workerMgmtConflictDelete(pid);
          } else {
            missingId = true;
          }
        }
        if (missingId && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '일부 페어는 삭제에 필요한 번호가 없습니다. 새로고침 후 다시 시도해 주세요.',
              ),
            ),
          );
        }
      }
      if (toAdd.isNotEmpty && pack != null) {
        for (final other in toAdd) {
          await _uc.workerMgmtConflictUpsert(
            workerAHid: self,
            workerBHid: other,
            severity: pack.severity,
            note: pack.note,
            active: true,
          );
        }
      }
      await reload(silent: true);
      ref.invalidate(workerMgmtConflictsHubProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('트러블 페어를 반영했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(workerMgmtUserMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingConflict = false);
    }
  }

  Widget _mgmtSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        context.rsi(18),
        context.rsi(16),
        context.rsi(18),
        context.rsi(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: EdgeInsets.all(context.rsi(10)),
                  child: Icon(icon,
                      size: context.rs(22), color: cs.onPrimaryContainer),
                ),
              ),
              SizedBox(width: context.rsi(12)),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: context.rsi(16)),
          child,
        ],
      ),
    );
  }

  Widget _noteTile(
    BuildContext context,
    WorkerMgmtNoteRead n,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isEval = n.noteType == 'evaluation';
    final surface = cs.surfaceContainerHighest.withValues(alpha: 0.55);
    return Padding(
      padding: EdgeInsets.only(bottom: context.rsi(10)),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(context.rsi(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isEval ? Icons.star_rounded : Icons.sticky_note_2_outlined,
                    size: context.rs(20),
                    color: isEval ? cs.tertiary : cs.primary,
                  ),
                  SizedBox(width: context.rsi(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rsi(10),
                      vertical: context.rsi(4),
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isEval ? cs.tertiaryContainer : cs.primaryContainer)
                              .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isEval ? '평가' : '메모',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isEval
                            ? cs.onTertiaryContainer
                            : cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (isEval && n.rating != null) ...[
                    SizedBox(width: context.rsi(8)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: EdgeInsets.only(right: context.rsi(2)),
                          child: Icon(
                            i < (n.rating ?? 0)
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: context.rs(16),
                            color: cs.tertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (n.authorUid != null && n.authorUid!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '작성 · ${n.authorUid}',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                n.memo,
                style: tt.bodyMedium?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final vm = ref.watch(workerMgmtHidVmProvider(widget.workerHid));
    final humans = ref.watch(workerMgmtHumanDirectoryProvider).humans;

    if (vm.initialLoading && vm.notes.isEmpty && vm.troublePairs.isEmpty) {
      return Skeletonizer(
        enabled: true,
        child: Padding(
          padding: EdgeInsets.only(top: context.rsi(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _mgmtSection(
                context: context,
                icon: Icons.rate_review_rounded,
                title: '관리 메모 · 평가',
                trailing: const SizedBox(width: 44, height: 44),
                child: const Text(
                  '메모·평가 기록이 여기에 표시됩니다.',
                  style: TextStyle(height: 1.35),
                ),
              ),
              const SizedBox(height: 16),
              _mgmtSection(
                context: context,
                icon: Icons.groups_outlined,
                title: '트러블 페어',
                trailing: const SizedBox(width: 88, height: 40),
                child: const Text(
                  '등록된 트러블 페어가 여기에 표시됩니다.',
                  style: TextStyle(height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (vm.loadError != null && vm.notes.isEmpty && vm.troublePairs.isEmpty) {
      return Container(
        padding: EdgeInsets.all(context.rsi(20)),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: cs.error),
                SizedBox(width: context.rsi(8)),
                Expanded(
                  child: Text(
                    workerMgmtUserMessage(vm.loadError!),
                    style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rsi(12)),
            FilledButton.tonalIcon(
              onPressed: vm.refreshing
                  ? null
                  : () => ref
                      .read(workerMgmtHidVmProvider(widget.workerHid).notifier)
                      .reload(silent: false),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final memoTrailing = _savingMemo
        ? Skeletonizer(
            enabled: true,
            child: IconButton.filledTonal(
              tooltip: '메모·평가 추가',
              onPressed: null,
              icon: const Icon(Icons.add_rounded),
            ),
          )
        : IconButton.filledTonal(
            tooltip: '메모·평가 추가',
            onPressed: _addMemo,
            icon: const Icon(Icons.add_rounded),
          );

    final memoChild = vm.notes.isEmpty
        ? Text(
            '아직 남긴 기록이 없습니다. 우측 버튼으로 메모나 평가를 추가해 보세요.',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: vm.notes.map((n) => _noteTile(context, n)).toList(),
          );

    final troubleTrailing = _savingConflict
        ? Skeletonizer(
            enabled: true,
            child: Padding(
              padding: EdgeInsets.only(right: context.rsi(4)),
              child: FilledButton.tonalIcon(
                onPressed: null,
                icon: Icon(Icons.edit_rounded, size: context.rs(18)),
                label: const Text('편집'),
                style: FilledButton.styleFrom(
                  padding:
                      EdgeInsets.symmetric(horizontal: context.rsi(16)),
                ),
              ),
            ),
          )
        : FilledButton.tonalIcon(
            onPressed: _editTroublePartners,
            icon: Icon(Icons.edit_rounded, size: context.rs(18)),
            label: const Text('편집'),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
            ),
          );

    final troubleChild = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '같은 현장에 함께 투입되면 저장 단계에서 경고됩니다.',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        SizedBox(height: context.rsi(12)),
        if (vm.troublePairs.isEmpty)
          Text(
            '등록된 트러블 인력이 없습니다.',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: context.rsi(8),
            runSpacing: context.rsi(8),
            children: vm.troublePairs.map((e) {
              final id = e.partnerHid;
              final label = _hname(humans, id);
              final pairId = e.pairId;
              final canDelete = pairId != null && !_savingConflict;
              return Material(
                color: cs.tertiaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: context.rsi(10),
                    right: context.rsi(4),
                    top: context.rsi(6),
                    bottom: context.rsi(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: context.rs(18),
                        color: cs.tertiary,
                      ),
                      SizedBox(width: context.rsi(6)),
                      Text(
                        label,
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (canDelete)
                        IconButton(
                          tooltip: '페어 삭제',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: () =>
                              _deleteTroublePairChip(pairId, label),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mgmtSection(
          context: context,
          icon: Icons.rate_review_rounded,
          title: '관리 메모 · 평가',
          trailing: memoTrailing,
          child: memoChild,
        ),
        const SizedBox(height: 16),
        _mgmtSection(
          context: context,
          icon: Icons.groups_outlined,
          title: '트러블 인력',
          trailing: troubleTrailing,
          child: troubleChild,
        ),
      ],
    );

    if (widget.embedInScrollView) {
      return SingleChildScrollView(child: body);
    }
    return body;
  }
}
