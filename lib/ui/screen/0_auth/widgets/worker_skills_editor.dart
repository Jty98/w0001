import 'package:flutter/material.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/ui/widget/keyboard_aware.dart';
import 'package:w0001/util/worker_skills_display.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';

/// 주특기 선택 프리셋 — `직접입력`·`기타` 제외(직접 입력 필드로 대체).
const _kPrimarySpecialtyPresets = <String>[
  '다기능공',
  '전기',
  '목수',
  '철거',
  '설비',
  '페인트',
  '사인물',
  '금속',
  '조공',
];

/// 회원가입·프로필·인력 관리 — 주특기 입력 폼.
class WorkerSkillsEditor extends StatefulWidget {
  const WorkerSkillsEditor({
    super.key,
    this.compact = false,
    this.onChanged,
    this.initialHuman,
    this.initialPrimarySpecialty,
    this.readOnlyUntilEdit = false,
  });

  final bool compact;
  final VoidCallback? onChanged;
  final HumanModel? initialHuman;
  final String? initialPrimarySpecialty;
  final bool readOnlyUntilEdit;

  @override
  WorkerSkillsEditorState createState() => WorkerSkillsEditorState();
}

class WorkerSkillsEditorState extends State<WorkerSkillsEditor> {
  static final _presetSet = _kPrimarySpecialtyPresets.toSet();

  static const _presetIcons = <String, IconData>{
    '다기능공': Icons.handyman_outlined,
    '전기': Icons.electrical_services_outlined,
    '목수': Icons.carpenter_outlined,
    '철거': Icons.construction_outlined,
    '설비': Icons.plumbing_outlined,
    '페인트': Icons.format_paint_outlined,
    '사인물': Icons.signpost_outlined,
    '금속': Icons.hardware_outlined,
    '조공': Icons.engineering_outlined,
  };

  final _primary = TextEditingController();
  var _editing = false;

  String get primaryTrimmed => _primary.text.trim();
  bool get hasPrimary => primaryTrimmed.isNotEmpty;
  bool get isEditingPrimary =>
      !widget.readOnlyUntilEdit || _editing || !hasPrimary;

  void _mutate(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
  }

  @override
  void initState() {
    super.initState();
    _editing = !widget.readOnlyUntilEdit;
    final h = widget.initialHuman;
    if (h != null) {
      _applyHumanData(h);
    } else {
      _primary.text = widget.initialPrimarySpecialty?.trim() ?? '';
    }
  }

  @override
  void didUpdateWidget(WorkerSkillsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final h = widget.initialHuman;
    if (h != null && h.hid != oldWidget.initialHuman?.hid) {
      _applyHumanData(h);
      if (widget.readOnlyUntilEdit) _editing = false;
      return;
    }
    if (h == null &&
        widget.initialPrimarySpecialty != oldWidget.initialPrimarySpecialty &&
        !isEditingPrimary) {
      _primary.text = widget.initialPrimarySpecialty?.trim() ?? '';
    }
  }

  void _applyHumanData(HumanModel human) {
    final profilePrimary = human.displayPrimarySpecialty;
    final legacyPayroll = human.hdefaultRole.trim();
    final primary = profilePrimary ??
        (legacyPayroll.isNotEmpty && !isWorkerSiteRank(legacyPayroll)
            ? legacyPayroll
            : null);
    _primary.text = primary ?? '';
  }

  @override
  void dispose() {
    _primary.dispose();
    super.dispose();
  }

  WorkerProfileRead toProfile({
    String workerRank = '',
    String career = '',
  }) {
    final p = primaryTrimmed;
    return WorkerProfileRead(
      primarySpecialty: p.isEmpty ? null : p,
      workerRank: workerRank,
      career: career,
    );
  }

  void loadFromHuman(HumanModel human) {
    _applyHumanData(human);
    if (widget.readOnlyUntilEdit) _editing = false;
    if (mounted) setState(() {});
  }

  void clearForm() {
    _primary.clear();
    if (widget.readOnlyUntilEdit) _editing = false;
  }

  void cancelPrimaryEdit() {
    final h = widget.initialHuman;
    if (h != null) {
      _applyHumanData(h);
    } else {
      _primary.text = widget.initialPrimarySpecialty?.trim() ?? '';
    }
    setState(() => _editing = false);
    widget.onChanged?.call();
  }

  bool _isPreset(String value) => _presetSet.contains(value);

  void _selectPreset(String label) => _mutate(() => _primary.text = label);

  IconData _iconForPreset(String preset) =>
      _presetIcons[preset] ?? Icons.build_outlined;

  Color _borderColor(ColorScheme cs, {required bool selected}) {
    if (selected) {
      return cs.onSurface.withValues(alpha: 0.38);
    }
    return cs.outlineVariant.withValues(alpha: 0.55);
  }

  Widget _sectionShell({
    required BuildContext context,
    required Widget child,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pad = context.rsi(widget.compact ? 12 : 14);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(context.rsi(16)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  size: context.rs(18),
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                ),
                SizedBox(width: context.rsi(8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '주특기',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          color: cs.onSurface,
                        ),
                      ),
                      SizedBox(height: context.rsi(2)),
                      Text(
                        isEditingPrimary
                            ? '분야를 선택하거나 직접 입력해 주세요.'
                            : '현장에서 일하게될 주특기입니다.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            SizedBox(height: context.rsi(12)),
            child,
          ],
        ),
      ),
    );
  }

  Widget _readOnlyCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final value = primaryTrimmed;
    final empty = value.isEmpty;
    final icon = empty ? Icons.star_outline_rounded : _iconForPreset(value);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(14),
        vertical: context.rsi(widget.compact ? 12 : 14),
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(context.rsi(12)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.48)),
      ),
      child: Row(
        children: [
          Container(
            width: context.rs(widget.compact ? 36 : 40),
            height: context.rs(widget.compact ? 36 : 40),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh.withValues(alpha: 0.65),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: context.rs(18),
              color: cs.onSurfaceVariant,
            ),
          ),
          SizedBox(width: context.rsi(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '선택된 주특기',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: context.rsi(2)),
                Text(
                  empty ? '미등록' : value,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: empty ? cs.onSurfaceVariant : cs.onSurface,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetGrid(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const crossAxisCount = 3;
    final iconSize = context.rs(widget.compact ? 20 : 22);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: context.rsi(8),
        crossAxisSpacing: context.rsi(8),
        childAspectRatio: 1.08,
      ),
      itemCount: _kPrimarySpecialtyPresets.length,
      itemBuilder: (context, index) {
        final preset = _kPrimarySpecialtyPresets[index];
        final selected = primaryTrimmed == preset;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectPreset(preset),
            borderRadius: BorderRadius.circular(context.rsi(12)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected
                    ? cs.surfaceContainerHigh.withValues(alpha: 0.75)
                    : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(context.rsi(12)),
                border: Border.all(
                  color: _borderColor(cs, selected: selected),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconForPreset(preset),
                    size: iconSize,
                    color: selected
                        ? cs.onSurface
                        : cs.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                  SizedBox(height: context.rsi(6)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.rsi(4)),
                    child: Text(
                      preset,
                      style: tt.labelSmall?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? cs.onSurface : cs.onSurfaceVariant,
                        height: 1.15,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _directInputField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final customActive = hasPrimary && !_isPreset(primaryTrimmed);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.rsi(10)),
      borderSide: BorderSide(
        color: customActive
            ? cs.onSurface.withValues(alpha: 0.32)
            : cs.outlineVariant.withValues(alpha: 0.5),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: context.rsi(4)),
        Row(
          children: [
            Icon(
              Icons.edit_outlined,
              size: context.rs(16),
              color: cs.onSurfaceVariant,
            ),
            SizedBox(width: context.rsi(6)),
            Text(
              '직접 입력',
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rsi(8)),
        AppTextField(
          controller: _primary,
          scrollPadding: keyboardScrollPadding(context, extra: 96),
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: '목록에 없는 분야 (예: 방수, 타일)',
            isDense: widget.compact,
            filled: true,
            fillColor: cs.surfaceContainerLowest,
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: cs.onSurface.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.rsi(14),
              vertical: context.rsi(widget.compact ? 11 : 12),
            ),
          ),
          textInputAction: TextInputAction.done,
          onChanged: (_) => _mutate(() {}),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (!isEditingPrimary) {
      return _sectionShell(
        context: context,
        trailing: TextButton(
          onPressed: () => setState(() => _editing = true),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: context.rsi(6)),
          ),
          child: Text(
            '수정',
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        child: _readOnlyCard(context),
      );
    }

    return _sectionShell(
      context: context,
      trailing: widget.readOnlyUntilEdit && hasPrimary
          ? TextButton(
              onPressed: cancelPrimaryEdit,
              child: Text(
                '취소',
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _presetGrid(context),
          _directInputField(context),
        ],
      ),
    );
  }
}
