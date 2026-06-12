import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/presentation/viewmodel/worker_profile_notifier.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/util/worker_skills_match.dart';
import 'package:w0001/util/responsive_layout.dart';

/// `GET/PUT /users/me/worker-profile` — 주특기·그 외 스킬을 **구역별로** 나눠 표시.
class ProfileWorkerSkillsSection extends ConsumerStatefulWidget {
  const ProfileWorkerSkillsSection({super.key, this.compact = false});

  /// 워커 단독 프로필에서 세로 여백·글자 크기 축소.
  final bool compact;

  @override
  ConsumerState<ProfileWorkerSkillsSection> createState() =>
      _ProfileWorkerSkillsSectionState();
}

class _ProfileWorkerSkillsSectionState
    extends ConsumerState<ProfileWorkerSkillsSection> {
  static final _fixedPresets =
      kWorkRolePresets.where((e) => e != '직접입력').toSet();

  final _primary = TextEditingController();
  final _customSkill = TextEditingController();
  final _skills = <String>[];
  var _directCustomMode = false;
  var _editing = false;

  double _g1(BuildContext c) => c.rsi(widget.compact ? 6 : 8);
  double _g2(BuildContext c) => c.rsi(widget.compact ? 8 : 10);
  double _g3(BuildContext c) => c.rsi(widget.compact ? 10 : 14);
  double _gSection(BuildContext c) => c.rsi(widget.compact ? 10 : 14);

  @override
  void dispose() {
    _primary.dispose();
    _customSkill.dispose();
    super.dispose();
  }

  String get _primaryTrimmed => _primary.text.trim();

  bool _isProfileEmpty(WorkerProfileRead pr) {
    final a = pr.primarySpecialty?.trim() ?? '';
    return a.isEmpty && pr.specialties.isEmpty;
  }

  /// 서버·표시 모두 —「그 밖에」에는 대표 주특기와 같은 글자는 넣지 않는다.
  static List<String> _extrasExcludingPrimary(WorkerProfileRead pr) {
    return workerSkillsExtrasExcludingPrimary(
      pr.specialties,
      primary: pr.primarySpecialty,
    );
  }

  void _notifyDuplicateBlocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('대표 주특기와 같은 작업은 추가할 수 없습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _extraDuplicatesPrimary(String skill) {
    final p = _primaryTrimmed;
    return p.isNotEmpty && workerSkillDuplicatesPrimary(skill, p);
  }

  /// 대표 주특기와 같은 문자열은「그 밖에 할 수 있는 작업」에 두지 않는다.
  void _removeExtraMatchingPrimary() {
    final p = _primaryTrimmed;
    if (p.isEmpty) return;
    _skills.removeWhere((s) => workerSkillDuplicatesPrimary(s, p));
  }

  void _applyFromProfile(WorkerProfileRead pr) {
    _primary.text = pr.primarySpecialty ?? '';
    _skills
      ..clear()
      ..addAll(pr.specialties);
    _removeExtraMatchingPrimary();
    _directCustomMode = _skills.any((s) => !_fixedPresets.contains(s));
    _customSkill.clear();
  }

  bool _primaryChipSelected(String label) {
    final t = _primary.text.trim();
    if (label == '직접입력') {
      if (t.isEmpty) return true;
      return !_fixedPresets.contains(t);
    }
    return t == label;
  }

  void _onPrimaryChipSelected(String label, bool selected) {
    setState(() {
      if (label == '직접입력') {
        if (!selected) return;
        if (_fixedPresets.contains(_primary.text.trim())) {
          _primary.clear();
        }
        _removeExtraMatchingPrimary();
        return;
      }
      if (selected) {
        _primary.text = label;
      } else if (_primary.text.trim() == label) {
        _primary.clear();
      }
      _removeExtraMatchingPrimary();
    });
  }

  void _togglePreset(String preset, bool selected) {
    final p = _primaryTrimmed;
    if (selected && p.isNotEmpty && workerSkillDuplicatesPrimary(preset, p)) {
      _notifyDuplicateBlocked();
      return;
    }
    setState(() {
      if (selected) {
        if (!_skills.any((s) => workerSkillsTextEquals(s, preset))) {
          _skills.add(preset);
        }
      } else {
        _skills.removeWhere((s) => workerSkillsTextEquals(s, preset));
      }
    });
  }

  void _toggleDirectCustom(bool selected) {
    setState(() {
      _directCustomMode = selected;
      if (!selected) {
        _skills.removeWhere((s) => !_fixedPresets.contains(s));
        _customSkill.clear();
      }
    });
  }

  void _addCustomSkills() {
    final t = _customSkill.text.trim();
    if (t.isEmpty) return;
    if (_extraDuplicatesPrimary(t)) {
      _notifyDuplicateBlocked();
      _customSkill.clear();
      return;
    }
    setState(() {
      if (!_skills.any((s) => workerSkillsTextEquals(s, t))) {
        _skills.add(t);
      }
      _customSkill.clear();
    });
  }

  bool _directChipSelected() {
    return _directCustomMode ||
        _skills.any((s) => !_fixedPresets.contains(s)) ||
        _customSkill.text.trim().isNotEmpty;
  }

  Widget _zone({
    required BuildContext context,
    required ColorScheme cs,
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(context.rsi(16)),
        border: Border.all(
          color: accent.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _g3(context),
          context.rs(widget.compact ? 8 : 10),
          _g3(context),
          _g3(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: context.rs(widget.compact ? 18 : 20),
                  color: accent,
                ),
                SizedBox(width: _g2(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: context.rsi(widget.compact ? 2 : 3)),
                      Text(
                        subtitle,
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: _g3(context)),
            child,
          ],
        ),
      ),
    );
  }

  /// 아래「그 밖에」칩과 동일한 재질·테두리, 텍스트 길이에 맞게 수축 — 대표만 글자 굵기만 강조.
  Widget _readOnlyPrimaryLine(
    BuildContext context,
    WorkerProfileRead pr,
    ColorScheme cs,
  ) {
    final tt = Theme.of(context).textTheme;
    final t = pr.primarySpecialty?.trim() ?? '';
    final display = t.isNotEmpty ? t : '미등록';
    final placeholder = t.isEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        label: Text(
          display,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: placeholder ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(widget.compact ? 8 : 10),
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.65),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _readOnlySpecialtiesWrap(
    BuildContext context,
    WorkerProfileRead pr,
    ColorScheme cs,
  ) {
    final tt = Theme.of(context).textTheme;
    final extras = _extrasExcludingPrimary(pr);
    if (extras.isEmpty) {
      return Text(
        '등록된 추가 작업이 없습니다.',
        style: tt.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.35,
        ),
      );
    }
    return Wrap(
      spacing: context.rsi(8),
      runSpacing: context.rsi(8),
      children: extras
          .map(
            (s) => Chip(
              label: Text(
                s,
                style: tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: context.rsi(widget.compact ? 8 : 10),
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: cs.surfaceContainerHighest.withValues(
                alpha: 0.65,
              ),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
          )
          .toList(),
    );
  }

  void _cancelEdit(WorkerProfileRead serverPr) {
    _applyFromProfile(serverPr);
    if (!_isProfileEmpty(serverPr)) {
      setState(() => _editing = false);
    } else {
      setState(() {});
    }
  }

  Widget _buildReadOnlyLayout(WorkerProfileRead pr, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _zone(
          context: context,
          cs: cs,
          icon: Icons.workspace_premium_outlined,
          accent: cs.primary,
          title: '대표 주특기',
          subtitle: '현장에서 보여질 대표 분야입니다.',
          child: _readOnlyPrimaryLine(context, pr, cs),
        ),
        SizedBox(height: _gSection(context)),
        _zone(
          context: context,
          cs: cs,
          icon: Icons.handyman_outlined,
          accent: cs.tertiary,
          title: '그 밖에 할 수 있는 작업',
          subtitle: '주특기 외에 추가로 가능한 작업입니다.',
          child: _readOnlySpecialtiesWrap(context, pr, cs),
        ),
        SizedBox(height: context.rsi(widget.compact ? 12 : 16)),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _editing = true;
                _applyFromProfile(pr);
              });
            },
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
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.rsi(widget.compact ? 16 : 28),
              ),
              child: _buildReadOnlyLayout(
                const WorkerProfileRead(
                  primarySpecialty: '대표 주특기',
                  specialties: ['추가 작업', '보조 작업'],
                ),
                cs,
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

        if (!showEditForm) {
          return _buildReadOnlyLayout(pr, cs);
        }

        final showCustomField = _directChipSelected();
        final tt = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _zone(
              context: context,
              cs: cs,
              icon: Icons.workspace_premium_outlined,
              accent: cs.primary,
              title: '대표 주특기',
              subtitle: '한 가지만 정합니다. 칩을 누르거나 아래에 직접 적어 주세요.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < kWorkRolePresets.length; i++) ...[
                          if (i > 0) SizedBox(width: _g1(context)),
                          ChoiceChip(
                            showCheckmark: false,
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rsi(widget.compact ? 3 : 4),
                            ),
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              kWorkRolePresets[i],
                              style: tt.labelSmall,
                            ),
                            selected: _primaryChipSelected(kWorkRolePresets[i]),
                            onSelected: (v) => _onPrimaryChipSelected(
                              kWorkRolePresets[i],
                              v,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: _g2(context)),
                  TextField(
                    controller: _primary,
                    style: tt.bodyMedium,
                    decoration: InputDecoration(
                      labelText: '주특기 · 직접 입력',
                      hintText: '가장 자신 있는 분야 (예: 목수)',
                      isDense: widget.compact,
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                      contentPadding: widget.compact
                          ? EdgeInsets.symmetric(
                              horizontal: context.rsi(12),
                              vertical: context.rsi(10),
                            )
                          : null,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {
                      _removeExtraMatchingPrimary();
                    }),
                  ),
                ],
              ),
            ),
            SizedBox(height: _gSection(context)),
            _zone(
              context: context,
              cs: cs,
              icon: Icons.handyman_outlined,
              accent: cs.tertiary,
              title: '그 밖에 할 수 있는 작업',
              subtitle: '주특기 외에 가능한 일을 골라 넣어 주세요. 여기만 따로 저장됩니다.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < kWorkRolePresets.length; i++) ...[
                          if (i > 0) SizedBox(width: _g1(context)),
                          Builder(
                            builder: (context) {
                              final preset = kWorkRolePresets[i];
                              final isDirectInput = preset == '직접입력';
                              final blockedByPrimary = !isDirectInput &&
                                  _extraDuplicatesPrimary(preset);
                              return FilterChip(
                                showCheckmark: false,
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rsi(widget.compact ? 3 : 4),
                                ),
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  preset,
                                  style: tt.labelSmall,
                                ),
                                selected: isDirectInput
                                    ? _directChipSelected()
                                    : _skills.any(
                                          (s) =>
                                              workerSkillsTextEquals(s, preset),
                                        ) &&
                                        !blockedByPrimary,
                                onSelected: blockedByPrimary
                                    ? null
                                    : (v) {
                                        if (isDirectInput) {
                                          _toggleDirectCustom(v);
                                        } else {
                                          _togglePreset(preset, v);
                                        }
                                      },
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showCustomField) ...[
                    SizedBox(height: _g2(context)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customSkill,
                            style: tt.bodyMedium,
                            decoration: InputDecoration(
                              hintText: '한 가지 입력 후 + (예: 방수)',
                              isDense: widget.compact,
                              border: const OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: context.rsi(12),
                                vertical: context.rsi(
                                  widget.compact ? 10 : 12,
                                ),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addCustomSkills(),
                          ),
                        ),
                        SizedBox(width: _g2(context)),
                        Tooltip(
                          message: '목록에 추가',
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              minimumSize: Size(
                                context.rs(widget.compact ? 44 : 48),
                                context.rs(widget.compact ? 44 : 48),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: _addCustomSkills,
                            child: const Icon(Icons.add),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_skills.isNotEmpty) ...[
                    SizedBox(height: _g2(context)),
                    Text(
                      '선택·추가한 작업',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.outline,
                      ),
                    ),
                    SizedBox(height: _g1(context)),
                    Wrap(
                      spacing: context.rsi(6),
                      runSpacing: context.rsi(4),
                      children: _skills
                          .map(
                            (s) => InputChip(
                              label: Text(
                                s,
                                style: tt.labelSmall,
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              deleteIconColor: cs.error,
                              onDeleted: () =>
                                  setState(() => _skills.remove(s)),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: context.rsi(widget.compact ? 10 : 14)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final serverPr =
                          ref.read(workerProfileProvider).asData?.value ??
                              p ??
                              const WorkerProfileRead();
                      _cancelEdit(serverPr);
                    },
                    child: const Text('취소'),
                  ),
                ),
                SizedBox(width: _g2(context)),
                Expanded(
                  child: FilledButton(
                    onPressed: _primary.text.trim().isEmpty
                        ? null
                        : () async {
                            try {
                              final serverPr =
                                  ref.read(workerProfileProvider).asData?.value ??
                                      p ??
                                      const WorkerProfileRead();
                              await ref
                                  .read(workerProfileProvider.notifier)
                                  .save(
                                    WorkerProfileRead(
                                      uid: serverPr.uid,
                                      primarySpecialty: _primary.text.trim(),
                                      specialties:
                                          workerSkillsExtrasExcludingPrimary(
                                        _skills,
                                        primary: _primary.text.trim(),
                                      ),
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
                          },
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
            if (_primary.text.trim().isEmpty)
              Padding(
                padding: EdgeInsets.only(top: context.rsi(widget.compact ? 6 : 8)),
                child: Text(
                  '대표 주특기를 입력한 뒤 저장할 수 있어요.',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
