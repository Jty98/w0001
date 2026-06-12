import 'package:flutter/material.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 회원가입 위저드 — 상단 진행률·단계 카드 크롬.
class WorkerSignupProgressHeader extends StatelessWidget {
  const WorkerSignupProgressHeader({
    super.key,
    required this.stepLabels,
    required this.activeIndex,
    required this.completedThrough,
  });

  final List<String> stepLabels;
  final int activeIndex;
  final int completedThrough;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = stepLabels.length;
    final progress = total == 0 ? 0.0 : (completedThrough / total).clamp(0.0, 1.0);
    final safeActive = activeIndex.clamp(0, total - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(context.rs(999)),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: context.rs(6),
            backgroundColor: cs.surfaceContainerHighest,
            color: cs.primary,
          ),
        ),
        SizedBox(height: context.rsi(12)),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: context.rs(2),
                    margin: EdgeInsets.symmetric(horizontal: context.rsi(2)),
                    decoration: BoxDecoration(
                      color: i <= completedThrough
                          ? cs.primary.withValues(alpha: 0.55)
                          : cs.outlineVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(context.rs(2)),
                    ),
                  ),
                ),
              _StepDot(
                index: i,
                done: i < completedThrough,
                active: i == safeActive,
              ),
            ],
          ],
        ),
        SizedBox(height: context.rsi(10)),
        Text(
          '${completedThrough.clamp(0, total)} / $total  ${stepLabels[safeActive]}',
          style: tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.done,
    required this.active,
  });

  final int index;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final size = context.rs(28);

    Color bg;
    Color fg;
    Widget child;

    if (done) {
      bg = cs.primary;
      fg = cs.onPrimary;
      child = Icon(Icons.check_rounded, size: context.rs(16), color: fg);
    } else if (active) {
      bg = cs.primaryContainer;
      fg = cs.onPrimaryContainer;
      child = Text(
        '${index + 1}',
        style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: fg),
      );
    } else {
      bg = cs.surfaceContainerHighest;
      fg = cs.onSurfaceVariant;
      child = Text(
        '${index + 1}',
        style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: fg),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: active && !done
            ? Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.5)
            : null,
        boxShadow: active && !done
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.18),
                  blurRadius: context.rs(8),
                  offset: Offset(0, context.rs(2)),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// 단계별 접이식 카드 — 완료 시 요약, 진행 중이면 [child] 폼.
class WorkerSignupStepCard extends StatelessWidget {
  const WorkerSignupStepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.isComplete,
    required this.isActive,
    required this.summary,
    required this.child,
    this.onEdit,
  });

  final int stepNumber;
  final String title;
  final bool isComplete;
  final bool isActive;
  final String? summary;
  final Widget child;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final showForm = isActive && !isComplete;
    final showSummary = isComplete;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: context.rsi(14)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: showForm
                ? cs.surface
                : cs.surfaceContainerLow.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(context.rs(16)),
            border: Border.all(
              color: showForm
                  ? cs.primary.withValues(alpha: 0.28)
                  : cs.outlineVariant.withValues(alpha: 0.35),
              width: showForm ? 1.2 : 1,
            ),
            boxShadow: showForm
                ? [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.06),
                      blurRadius: context.rs(12),
                      offset: Offset(0, context.rs(4)),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(14),
              context.rsi(14),
              context.rsi(14),
              context.rsi(showForm ? 16 : 12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _StepDot(
                      index: stepNumber - 1,
                      done: isComplete,
                      active: isActive && !isComplete,
                    ),
                    SizedBox(width: context.rsi(10)),
                    Expanded(
                      child: Text(
                        title,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (showSummary && onEdit != null)
                      TextButton(
                        onPressed: onEdit,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rsi(8),
                          ),
                        ),
                        child: const Text('수정'),
                      ),
                  ],
                ),
                if (showSummary && summary != null && summary!.isNotEmpty) ...[
                  SizedBox(height: context.rsi(8)),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: context.rs(18),
                        color: cs.primary,
                      ),
                      SizedBox(width: context.rsi(8)),
                      Expanded(
                        child: Text(
                          summary!,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                Visibility(
                  visible: showForm,
                  maintainState: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: context.rsi(14)),
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
