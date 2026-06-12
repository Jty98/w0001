import 'package:flutter/material.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/util/worker_skills_match.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 회원가입·프로필 등 — 주특기·그 밖에 스킬 입력 폼(편집 전용).
class WorkerSkillsEditor extends StatefulWidget {
  const WorkerSkillsEditor({
    super.key,
    this.compact = false,
    this.onChanged,
  });

  final bool compact;
  final VoidCallback? onChanged;

  @override
  WorkerSkillsEditorState createState() => WorkerSkillsEditorState();
}

class WorkerSkillsEditorState extends State<WorkerSkillsEditor> {
  static final _fixedPresets =
      kWorkRolePresets.where((e) => e != '직접입력').toSet();

  final _primary = TextEditingController();
  final _customSkill = TextEditingController();
  final _skills = <String>[];
  var _directCustomMode = false;

  double _g1(BuildContext c) => c.rsi(widget.compact ? 6 : 8);
  double _g2(BuildContext c) => c.rsi(widget.compact ? 8 : 10);
  double _g3(BuildContext c) => c.rsi(widget.compact ? 10 : 14);
  double _gSection(BuildContext c) => c.rsi(widget.compact ? 10 : 14);

  String get primaryTrimmed => _primary.text.trim();

  bool get hasPrimary => primaryTrimmed.isNotEmpty;

  void _mutate(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    _primary.dispose();
    _customSkill.dispose();
    super.dispose();
  }

  WorkerProfileRead toProfile({
    String workerRank = '',
    String career = '',
  }) {
    final p = primaryTrimmed;
    return WorkerProfileRead(
      primarySpecialty: p.isEmpty ? null : p,
      specialties: workerSkillsExtrasExcludingPrimary(_skills, primary: p),
      workerRank: workerRank,
      career: career,
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
    final p = primaryTrimmed;
    return p.isNotEmpty && workerSkillDuplicatesPrimary(skill, p);
  }

  void _removeExtraMatchingPrimary() {
    final p = primaryTrimmed;
    if (p.isEmpty) return;
    _skills.removeWhere((s) => workerSkillDuplicatesPrimary(s, p));
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
    _mutate(() {
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
    final p = primaryTrimmed;
    if (selected && p.isNotEmpty && workerSkillDuplicatesPrimary(preset, p)) {
      _notifyDuplicateBlocked();
      return;
    }
    _mutate(() {
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
    _mutate(() {
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
    _mutate(() {
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
        border: Border.all(color: accent.withValues(alpha: 0.42)),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final showCustomField = _directChipSelected();

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
          subtitle: '한 가지만 정합니다. 칩을 누르거나 직접 입력해 주세요.',
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
                        onSelected: (v) =>
                            _onPrimaryChipSelected(kWorkRolePresets[i], v),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: _g2(context)),
              TextField(
                controller: _primary,
                scrollPadding: keyboardScrollPadding(context, extra: 96),
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
                onChanged: (_) => _mutate(_removeExtraMatchingPrimary),
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
          subtitle: '주특기 외에 가능한 작업을 골라 넣어 주세요. (선택)',
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
                                      (s) => workerSkillsTextEquals(s, preset),
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
                        scrollPadding: keyboardScrollPadding(context, extra: 96),
                        style: tt.bodyMedium,
                        decoration: InputDecoration(
                          hintText: '한 가지 입력 후 +',
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
                          onDeleted: () => _mutate(() => _skills.remove(s)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
