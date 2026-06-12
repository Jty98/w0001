import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/worker_skills_match.dart';

extension HumanWorkerSkillsDisplay on HumanModel {
  String? get displayPrimarySpecialty {
    final p = primarySpecialty?.trim() ?? '';
    return p.isNotEmpty ? p : null;
  }

  List<String> get displayExtraSpecialties {
    return workerSkillsExtrasExcludingPrimary(
      specialties,
      primary: displayPrimarySpecialty,
    );
  }

  String get effectiveDefaultWorkRole {
    final p = displayPrimarySpecialty;
    if (p != null) return p;
    return hdefaultRole.trim();
  }

  bool get hasWorkerProfileSkills =>
      displayPrimarySpecialty != null || displayExtraSpecialties.isNotEmpty;
}

/// 인력·목록 UI 공통 라벨 (앱 등록 / 워커 자가 입력 동일 표기).
const String kHumanSkillLabelPrimary = '대표 작업';
const String kHumanSkillLabelExtra = '추가 작업';

/// 화면 표시용 대표·추가 작업 (폼에서 고른 역할 미리보기 반영).
class HumanSkillsDisplayData {
  const HumanSkillsDisplayData({
    this.primary,
    this.extras = const [],
    this.payrollRole,
  });

  final String? primary;
  final List<String> extras;

  /// 인건비 기본 역할(관리자 설정) — 워커 프로필 대표와 다를 때만 표시.
  final String? payrollRole;

  bool get isEmpty =>
      (primary == null || primary!.isEmpty) &&
      extras.isEmpty &&
      (payrollRole == null || payrollRole!.isEmpty);
}

HumanSkillsDisplayData resolveHumanSkillsDisplay(
  HumanModel human, {
  String? formRolePreview,
}) {
  final formRole = formRolePreview?.trim() ?? '';
  final profilePrimary = human.displayPrimarySpecialty;
  final extras = human.displayExtraSpecialties;

  String? primary = profilePrimary;
  String? payroll;

  if (primary == null || primary.isEmpty) {
    primary = formRole.isNotEmpty
        ? formRole
        : (human.hdefaultRole.trim().isNotEmpty
            ? human.hdefaultRole.trim()
            : null);
  } else if (formRole.isNotEmpty &&
      formRole != primary &&
      !extras.contains(formRole)) {
    payroll = formRole;
  } else if (formRole.isNotEmpty && formRole == primary) {
    payroll = null;
  } else if (human.hdefaultRole.trim().isNotEmpty &&
      human.hdefaultRole.trim() != primary &&
      !extras.contains(human.hdefaultRole.trim()) &&
      formRole.isEmpty) {
    payroll = human.hdefaultRole.trim();
  }

  return HumanSkillsDisplayData(
    primary: primary,
    extras: extras,
    payrollRole: payroll,
  );
}

/// 회원 [UserRead]와 인력 목록으로 연결된 [HumanRead] 조회.
HumanRead? findHumanReadForMember(UserRead u, List<HumanRead> humans) {
  int? hid;
  if (u.workerHid != null && u.workerHid! > 0) {
    hid = u.workerHid;
  } else {
    final uname = u.uname.trim();
    for (final h in humans) {
      if (h.hdelete != 0) continue;
      if (h.hname.trim() == uname) {
        hid = h.hid;
        break;
      }
    }
    if (hid == null) {
      final uidDigits = u.uid.replaceAll(RegExp(r'\D'), '');
      if (uidDigits.length >= 4) {
        for (final h in humans) {
          if (h.hdelete != 0) continue;
          final nd = h.hnumber.replaceAll(RegExp(r'\D'), '');
          if (nd.isNotEmpty && nd == uidDigits) {
            hid = h.hid;
            break;
          }
        }
      }
    }
  }
  if (hid == null) return null;
  for (final h in humans) {
    if (h.hid == hid && h.hdelete == 0) return h;
  }
  return null;
}

/// 회원관리 카드·상세용 — 인력 레코드 우선, 없으면 회원 JSON 스킬.
HumanModel humanModelForMemberSkills(
  UserRead u, {
  HumanRead? linkedHuman,
}) {
  if (linkedHuman != null) {
    final m = humanReadToModel(linkedHuman);
    if (m.hasWorkerProfileSkills) return m;
    if (u.primarySpecialty != null || u.specialties.isNotEmpty) {
      return HumanModel(
        hid: m.hid,
        hname: m.hname,
        hnumber: m.hnumber,
        hmemo: m.hmemo,
        hdailyWage: m.hdailyWage,
        hdefaultRole: m.hdefaultRole,
        primarySpecialty: u.primarySpecialty ?? m.primarySpecialty,
        specialties: u.specialties.isNotEmpty ? u.specialties : m.specialties,
        hstar: m.hstar,
        hdelete: m.hdelete,
      );
    }
    return m;
  }
  return HumanModel(
    hid: u.workerHid,
    hname: u.uname,
    hnumber: '',
    primarySpecialty: u.primarySpecialty,
    specialties: u.specialties,
    hdefaultRole: '',
    hstar: 0,
    hdelete: 0,
  );
}

bool memberShouldShowWorkerSkills(UserRead u) =>
    u.role == UserRole.worker ||
    u.primarySpecialty != null ||
    u.specialties.isNotEmpty;

/// 회원관리 목록 — 대표 주특기 한 줄 (없으면 [emptyLabel]).
String memberListPrimarySpecialty(
  UserRead u, {
  HumanRead? linkedHuman,
  String emptyLabel = '주특기 미등록',
}) {
  final m = humanModelForMemberSkills(u, linkedHuman: linkedHuman);
  final primary = resolveHumanSkillsDisplay(m).primary?.trim();
  if (primary != null && primary.isNotEmpty) return primary;
  return emptyLabel;
}

/// 드롭다운·한 줄 부제.
String humanSkillsOneLine(HumanModel h, {String? formRolePreview}) {
  final d = resolveHumanSkillsDisplay(h, formRolePreview: formRolePreview);
  final lines = <String>[];
  if (d.primary != null && d.primary!.isNotEmpty) {
    lines.add('$kHumanSkillLabelPrimary: ${d.primary}');
  }
  if (d.extras.isNotEmpty) {
    lines.add('$kHumanSkillLabelExtra: ${d.extras.join(', ')}');
  }
  if (d.payrollRole != null && d.payrollRole!.isNotEmpty) {
    lines.add('인건비 기본: ${d.payrollRole}');
  }
  return lines.isEmpty ? '작업 정보 미등록' : lines.join('  |  ');
}

/// 목록·카드용 — 한 줄(최대 2줄).
class HumanSkillsInlineLine extends StatelessWidget {
  const HumanSkillsInlineLine({
    super.key,
    required this.human,
    this.formRolePreview,
    this.showEmptyHint = true,
    this.maxLines = 2,
  });

  final HumanModel human;
  final String? formRolePreview;
  final bool showEmptyHint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = resolveHumanSkillsDisplay(
      human,
      formRolePreview: formRolePreview,
    );

    if (d.isEmpty) {
      if (!showEmptyHint) return const SizedBox.shrink();
      return Text(
        '작업 정보 미등록',
        style: TextStyle(
          fontSize: 11,
          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
        ),
      );
    }

    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: cs.onSurfaceVariant,
    );
    final primaryStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: cs.primary,
    );
    final extraStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: cs.onSurface.withValues(alpha: 0.88),
    );
    final sepStyle = TextStyle(
      fontSize: 11,
      color: cs.outlineVariant,
    );

    final spans = <InlineSpan>[];

    if (d.primary != null && d.primary!.isNotEmpty) {
      spans.addAll([
        TextSpan(
          text: '$kHumanSkillLabelPrimary ',
          style: labelStyle.copyWith(color: cs.primary),
        ),
        TextSpan(text: d.primary, style: primaryStyle),
      ]);
    }

    if (d.extras.isNotEmpty) {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: '   ', style: sepStyle));
        spans.add(TextSpan(text: '|', style: sepStyle));
        spans.add(TextSpan(text: '   ', style: sepStyle));
      }
      spans.add(TextSpan(text: '$kHumanSkillLabelExtra ', style: labelStyle));
      spans.add(TextSpan(text: d.extras.join(', '), style: extraStyle));
    }

    if (d.payrollRole != null && d.payrollRole!.isNotEmpty) {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: '   ', style: sepStyle));
        spans.add(TextSpan(text: '|', style: sepStyle));
        spans.add(TextSpan(text: '   ', style: sepStyle));
      }
      spans.add(TextSpan(text: '인건비 기본 ', style: labelStyle));
      spans.add(TextSpan(text: d.payrollRole, style: extraStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 목록·카드용 — 대표 작업 칩 + 추가 작업 가로 스크롤.
class HumanSkillsChipRow extends StatelessWidget {
  const HumanSkillsChipRow({
    super.key,
    required this.human,
    this.formRolePreview,
    this.showEmptyHint = true,
    this.extraScrollHeight = 30,
    this.showSectionLabels = false,
  });

  final HumanModel human;
  final String? formRolePreview;
  final bool showEmptyHint;

  /// 추가 작업 가로 스크롤 영역 높이.
  final double extraScrollHeight;

  /// 인력 수정 다이얼로그 등 — 구역 제목 표시.
  final bool showSectionLabels;

  static const double _chipGap = 6;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = resolveHumanSkillsDisplay(
      human,
      formRolePreview: formRolePreview,
    );

    if (d.isEmpty) {
      if (!showEmptyHint) return const SizedBox.shrink();
      return Text(
        '작업 정보 미등록',
        style: TextStyle(
          fontSize: 11,
          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
        ),
      );
    }

    final primary = d.primary;
    final extras = d.extras;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSectionLabels && primary != null && primary.isNotEmpty) ...[
          _sectionLabel(context, kHumanSkillLabelPrimary),
          const SizedBox(height: 4),
        ],
        if (primary != null && primary.isNotEmpty)
          _HumanSkillChip(
            label: primary,
            style: _HumanSkillChipStyle.primary,
            leadingIcon: Icons.workspace_premium_outlined,
          ),
        if (showSectionLabels &&
            (extras.isNotEmpty ||
                (d.payrollRole != null && d.payrollRole!.isNotEmpty))) ...[
          SizedBox(height: primary != null && primary.isNotEmpty ? _chipGap + 4 : 0),
          _sectionLabel(context, kHumanSkillLabelExtra),
          const SizedBox(height: 4),
        ],
        if (extras.isNotEmpty) ...[
          if (!showSectionLabels &&
              primary != null &&
              primary.isNotEmpty)
            const SizedBox(height: _chipGap),
          _HumanSkillsExtraScrollRow(
            labels: extras,
            height: extraScrollHeight,
          ),
        ],
        if (d.payrollRole != null && d.payrollRole!.isNotEmpty) ...[
          if (primary != null || extras.isNotEmpty) const SizedBox(height: _chipGap),
          _HumanSkillChip(
            label: d.payrollRole!,
            style: _HumanSkillChipStyle.muted,
            leadingIcon: Icons.payments_outlined,
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: cs.onSurfaceVariant,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// 주특기 제외 — 그 밖에 스킬 칩만 가로 스크롤.
class _HumanSkillsExtraScrollRow extends StatelessWidget {
  const _HumanSkillsExtraScrollRow({
    required this.labels,
    required this.height,
  });

  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: HumanSkillsChipRow._chipGap),
                _HumanSkillChip(
                  label: labels[i],
                  style: _HumanSkillChipStyle.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _HumanSkillChipStyle { primary, secondary, muted }

class _HumanSkillChip extends StatelessWidget {
  const _HumanSkillChip({
    required this.label,
    required this.style,
    this.leadingIcon,
  });

  final String label;
  final _HumanSkillChipStyle style;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color bg;
    final Color fg;
    final Color? border;
    final FontWeight weight;

    switch (style) {
      case _HumanSkillChipStyle.primary:
        bg = cs.primaryContainer.withValues(alpha: 0.72);
        fg = cs.onPrimaryContainer;
        border = cs.primary.withValues(alpha: 0.35);
        weight = FontWeight.w800;
      case _HumanSkillChipStyle.secondary:
        bg = cs.surfaceContainerHighest.withValues(alpha: 0.55);
        fg = cs.onSurface.withValues(alpha: 0.9);
        border = cs.outlineVariant.withValues(alpha: 0.55);
        weight = FontWeight.w600;
      case _HumanSkillChipStyle.muted:
        bg = cs.surfaceContainerHighest.withValues(alpha: 0.35);
        fg = cs.onSurfaceVariant;
        border = cs.outlineVariant.withValues(alpha: 0.4);
        weight = FontWeight.w600;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 14, color: fg.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: weight,
                color: fg,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [HumanSkillsInlineLine] 래퍼 (기존 호출부 호환).
class HumanSkillsListRow extends StatelessWidget {
  const HumanSkillsListRow({
    super.key,
    required this.human,
    this.showEmptyHint = true,
    this.compact = true,
  });

  final HumanModel human;
  final bool showEmptyHint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return HumanSkillsInlineLine(
      human: human,
      showEmptyHint: showEmptyHint,
      maxLines: compact ? 2 : 3,
    );
  }
}

/// 사람 관리 — 폼 아래 작업 정보 미리보기(역할 칩 선택 반영).
class HumanWorkerSkillsPanel extends StatelessWidget {
  const HumanWorkerSkillsPanel({
    super.key,
    required this.human,
    this.formRolePreview = '',
  });

  final HumanModel human;
  final String formRolePreview;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.preview_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  '작업 정보 미리보기',
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '위에서 고른 역할이 아래에 바로 반영됩니다.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            HumanSkillsChipRow(
              human: human,
              formRolePreview: formRolePreview,
              showSectionLabels: true,
              showEmptyHint: true,
              extraScrollHeight: 32,
            ),
          ],
        ),
      ),
    );
  }
}
