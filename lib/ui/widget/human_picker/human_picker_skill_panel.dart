import 'package:flutter/material.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/human_picker_display.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

/// 인력 검색·초대·투입 바텀시트 — 이름 아래 작업 정보(컴팩트).
class HumanPickerSkillPanel extends StatelessWidget {
  const HumanPickerSkillPanel({
    super.key,
    required this.human,
    this.showRrn = true,
  });

  final HumanModel human;
  final bool showRrn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final d = resolveHumanSkillsDisplay(human);
    final rrn = showRrn ? humanPickerRrnSubtitle(human.hnumber) : '';

    final primary = d.primary?.trim();
    final hasPrimary = primary != null && primary.isNotEmpty;
    final extras = d.extras;
    final hasSkills = hasPrimary || extras.isNotEmpty;
    final hasWage = human.hdailyWage > 0;

    if (rrn.isEmpty && !hasSkills && !hasWage) {
      return Text(
        '작업 정보 미등록',
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
          height: 1.2,
        ),
      );
    }

    final labelStyle = tt.labelSmall?.copyWith(
      fontSize: context.rs(10),
      fontWeight: FontWeight.w700,
      color: cs.onSurfaceVariant,
      height: 1.15,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rrn.isNotEmpty) ...[
          Text(
            rrn,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.9),
              letterSpacing: 0.15,
              height: 1.15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasSkills || hasWage) SizedBox(height: context.rsi(4)),
        ],
        if (hasSkills)
          _SkillLine(
            label: '작업',
            labelStyle: labelStyle,
            child: _MergedSkillsScroll(
              primary: hasPrimary ? primary : null,
              extras: extras,
            ),
          ),
        if (hasWage) ...[
          if (hasSkills) SizedBox(height: context.rsi(3)),
          _SkillLine(
            label: '인건비',
            labelStyle: labelStyle,
            child: Text(
              getPrice(price: human.hdailyWage),
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                height: 1.15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// 대표 작업(강조) + 추가 작업 — 한 줄 가로 스크롤.
class _MergedSkillsScroll extends StatelessWidget {
  const _MergedSkillsScroll({
    required this.primary,
    required this.extras,
  });

  final String? primary;
  final List<String> extras;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final extraStyle = tt.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      height: 1.15,
    );
    final primaryStyle = tt.labelSmall?.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );

    final p = primary?.trim();
    final items = <Widget>[];
    if (p != null && p.isNotEmpty) {
      items.add(Text(p, style: primaryStyle));
    }
    for (final extra in extras) {
      final t = extra.trim();
      if (t.isEmpty) continue;
      if (items.isNotEmpty) {
        items.add(SizedBox(width: context.rsi(8)));
      }
      items.add(Text(t, style: extraStyle));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: context.rs(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: items,
        ),
      ),
    );
  }
}

/// 이름 옆 현장 역할 — 테두리 없이 이름과 자연스럽게 이어지는 인라인 태그.
class HumanPickerSiteRankBadge extends StatelessWidget {
  const HumanPickerSiteRankBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(6),
        vertical: context.rsi(2),
      ),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.labelSmall?.copyWith(
          fontSize: context.rs(11),
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.72),
          height: 1.1,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _SkillLine extends StatelessWidget {
  const _SkillLine({
    required this.label,
    required this.child,
    required this.labelStyle,
  });

  final String label;
  final Widget child;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: context.rsi(44),
          child: Text(label, style: labelStyle),
        ),
        Expanded(child: child),
      ],
    );
  }
}
