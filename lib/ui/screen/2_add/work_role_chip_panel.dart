import 'package:flutter/material.dart';
import 'package:w0001/ui/screen/2_add/work_role_suggestions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 금액추가·항목 수정 — 공정 / 인력 역할 / 자주 쓰는 역할(직접입력 포함).
class WorkRoleChipPanel extends StatelessWidget {
  const WorkRoleChipPanel({
    super.key,
    required this.selectedWorkRole,
    required this.processTasks,
    required this.workerSkills,
    required this.onSelectRole,
    this.processTasksLoading = false,
    this.customRoleController,
    this.onApplyCustomRole,
    this.showApplyHint = true,
    this.dense = false,
  });

  final String? selectedWorkRole;
  final List<String> processTasks;
  final List<String> workerSkills;
  final bool processTasksLoading;
  final TextEditingController? customRoleController;
  final void Function(String role)? onApplyCustomRole;
  final void Function(String role) onSelectRole;
  final bool showApplyHint;
  final bool dense;

  static const double _chipRowHeight = 36;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final shownElsewhere = [...processTasks, ...workerSkills];
    final frequent = frequentRoleChips(alreadyShown: shownElsewhere);
    final showCustomField =
        selectedWorkRole == '직접입력' && customRoleController != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showApplyHint) ...[
          Text(
            '선택한 역할은 오늘 추가한 인력 전원에 적용됩니다.',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          SizedBox(height: context.rsi(dense ? 8 : 10)),
        ],
        if (processTasksLoading)
          Padding(
            padding: EdgeInsets.only(bottom: context.rsi(dense ? 6 : 8)),
            child: LinearProgressIndicator(
              minHeight: 2,
              borderRadius: BorderRadius.circular(2),
              color: cs.primary.withValues(alpha: 0.45),
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        if (processTasks.isNotEmpty)
          _RoleSection(
            icon: Icons.view_timeline_rounded,
            title: '오늘 공정',
            accent: cs.tertiary,
            dense: dense,
            child: _HorizontalRoleChips(
              height: context.rs(_chipRowHeight),
              labels: processTasks,
              selected: selectedWorkRole,
              accent: cs.tertiary,
              onTap: onSelectRole,
            ),
          ),
        if (workerSkills.isNotEmpty) ...[
          SizedBox(height: context.rsi(dense ? 10 : 12)),
          _RoleSection(
            icon: Icons.engineering_outlined,
            title: '이 인력 역할',
            accent: cs.primary,
            dense: dense,
            child: _HorizontalRoleChips(
              height: context.rs(_chipRowHeight),
              labels: workerSkills,
              selected: selectedWorkRole,
              accent: cs.primary,
              onTap: onSelectRole,
            ),
          ),
        ],
        SizedBox(height: context.rsi(dense ? 10 : 12)),
        _RoleSection(
          icon: Icons.apps_rounded,
          title: '자주 쓰는 역할',
          accent: cs.secondary,
          dense: dense,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HorizontalRoleChips(
                height: context.rs(_chipRowHeight),
                labels: frequent,
                selected: selectedWorkRole,
                accent: cs.secondary,
                onTap: onSelectRole,
              ),
              if (showCustomField) ...[
                SizedBox(height: context.rsi(dense ? 8 : 10)),
                TextField(
                  controller: customRoleController,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '작업 내용을 입력하세요',
                    prefixIcon: Icon(
                      Icons.edit_note_rounded,
                      size: context.rs(20),
                      color: cs.primary.withValues(alpha: 0.85),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: cs.surface,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: context.rsi(12),
                      vertical: context.rsi(11),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rsi(12)),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rsi(12)),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rsi(12)),
                      borderSide: BorderSide(color: cs.primary, width: 1.4),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) {
                    final t = v.trim();
                    if (t.isEmpty) return;
                    onApplyCustomRole?.call(t);
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.icon,
    required this.title,
    required this.accent,
    required this.child,
    required this.dense,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final Widget child;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: context.rs(22),
              height: context.rs(22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(context.rsi(6)),
              ),
              child: Icon(icon, size: context.rs(13), color: accent),
            ),
            SizedBox(width: context.rsi(7)),
            Text(
              title,
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rsi(dense ? 6 : 7)),
        child,
      ],
    );
  }
}

class _HorizontalRoleChips extends StatelessWidget {
  const _HorizontalRoleChips({
    required this.height,
    required this.labels,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final double height;
  final List<String> labels;
  final String? selected;
  final Color accent;
  final void Function(String role) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(context.rsi(12)),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.rsi(12)),
        child: SizedBox(
          height: height + context.rsi(12),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(8),
              vertical: context.rsi(6),
            ),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            itemCount: labels.length,
            separatorBuilder: (_, __) => SizedBox(width: context.rsi(6)),
            itemBuilder: (context, index) {
              final label = labels[index];
              return _RoleChip(
                label: label,
                selected: selected == label,
                accent: accent,
                onTap: () => onTap(label),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  bool get _isCustomEntry => label == '직접입력';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = selected
        ? accent.withValues(alpha: 0.2)
        : cs.surface.withValues(alpha: 0.92);
    final border = selected
        ? accent.withValues(alpha: 0.65)
        : cs.outlineVariant.withValues(alpha: 0.28);
    final fg = selected ? cs.onSurface : cs.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.rsi(18)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(_isCustomEntry ? 10 : 12),
            vertical: context.rsi(6),
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(context.rsi(18)),
            border: Border.all(color: border, width: selected ? 1.25 : 1),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCustomEntry) ...[
                Icon(
                  Icons.draw_outlined,
                  size: context.rs(14),
                  color: selected ? accent : cs.onSurfaceVariant,
                ),
                SizedBox(width: context.rsi(4)),
              ],
              Text(
                label,
                style: tt.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: fg,
                  height: 1.1,
                ),
              ),
              if (selected && !_isCustomEntry) ...[
                SizedBox(width: context.rsi(4)),
                Icon(Icons.check_rounded, size: context.rs(14), color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 항목 수정 다이얼로그용 역할 초기 칩.
(String? chip, String customInitial) workRoleInitialSelection(
  String wrole, {
  Iterable<String> processTasks = const [],
  Iterable<String> workerSkills = const [],
}) {
  final t = wrole.trim();
  if (t.isEmpty) return (null, '');
  if (isKnownSelectableWorkRole(
    t,
    processTasks: processTasks,
    workerSkills: workerSkills,
  )) {
    return (t, '');
  }
  return ('직접입력', wrole);
}
