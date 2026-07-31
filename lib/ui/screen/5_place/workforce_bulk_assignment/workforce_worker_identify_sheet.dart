import 'package:flutter/material.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/ui/widget/human_picker/human_picker_skill_panel.dart';
import 'package:w0001/ui/widget/worker_profile/worker_profile_info_row.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/human_contact_display.dart';
import 'package:w0001/util/human_work_assignability.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

/// 인력투입 그리드 — 동명이인 구분용 미리보기.
Future<void> showWorkforceWorkerIdentifySheet({
  required BuildContext context,
  required HumanModel human,
  VoidCallback? onEditAssignment,
  Future<void> Function()? onRemoveFromRecent,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => _WorkforceWorkerIdentifyBody(
      human: human,
      onEditAssignment: onEditAssignment,
      onRemoveFromRecent: onRemoveFromRecent,
    ),
  );
}

class _WorkforceWorkerIdentifyBody extends StatelessWidget {
  const _WorkforceWorkerIdentifyBody({
    required this.human,
    this.onEditAssignment,
    this.onRemoveFromRecent,
  });

  final HumanModel human;
  final VoidCallback? onEditAssignment;
  final Future<void> Function()? onRemoveFromRecent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final siteRank = resolveHumanSiteRank(human);
    final career = CareerInputUtils.formatForDisplay(human.career);
    final verifiedPhone = humanVerifiedPhone(human);
    final manualPhone = humanManualPhone(human);
    final defaultRole = human.hdefaultRole.trim();
    final memo = human.hmemo?.trim() ?? '';
    final uid = human.uid?.trim() ?? '';
    final isMember = uid.isNotEmpty;
    final linkedName = human.linkedUserName?.trim() ?? '';
    final assignable = humanCanBeAssignedToWork(human);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(20),
          context.rsi(4),
          context.rsi(20),
          context.rsi(16) + bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: context.rs(26),
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    human.hname.isNotEmpty ? human.hname[0] : '?',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                SizedBox(width: context.rsi(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: context.rsi(6),
                        runSpacing: context.rsi(4),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            human.hname,
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (siteRank != null && siteRank.isNotEmpty)
                            HumanPickerSiteRankBadge(label: siteRank),
                        ],
                      ),
                      SizedBox(height: context.rsi(4)),
                      Text(
                        isMember ? '앱 회원' : '비회원 (직접 등록)',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (!assignable) ...[
                        SizedBox(height: context.rsi(4)),
                        Text(
                          humanWorkAssignBlockMessage(human),
                          style: tt.labelSmall?.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.rsi(14)),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SingleChildScrollView(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(context.rs(14)),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(context.rsi(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HumanPickerSkillPanel(human: human, showRrn: true),
                        if (career.isNotEmpty) ...[
                          SizedBox(height: context.rsi(10)),
                          WorkerProfileInfoRow(
                            icon: Icons.history_edu_outlined,
                            label: '경력',
                            value: career,
                          ),
                        ],
                        if (defaultRole.isNotEmpty &&
                            defaultRole != human.displayPrimarySpecialty) ...[
                          SizedBox(height: context.rsi(2)),
                          WorkerProfileInfoRow(
                            icon: Icons.engineering_outlined,
                            label: '기본 역할',
                            value: defaultRole,
                          ),
                        ],
                        if (human.hdailyWage > 0) ...[
                          SizedBox(height: context.rsi(2)),
                          WorkerProfileInfoRow(
                            icon: Icons.payments_outlined,
                            label: '기본 일당',
                            value: getPrice(price: human.hdailyWage),
                          ),
                        ],
                        if (verifiedPhone != null) ...[
                          SizedBox(height: context.rsi(2)),
                          WorkerProfileInfoRow(
                            icon: Icons.phone_iphone_outlined,
                            label: kHumanVerifiedPhoneLabel,
                            value: verifiedPhone,
                          ),
                        ],
                        if (manualPhone != null &&
                            manualPhone != verifiedPhone) ...[
                          SizedBox(height: context.rsi(2)),
                          WorkerProfileInfoRow(
                            icon: Icons.phone_outlined,
                            label: kHumanManualPhoneLabel,
                            value: manualPhone,
                          ),
                        ],
                        if (isMember) ...[
                          SizedBox(height: context.rsi(2)),
                          WorkerProfileInfoRow(
                            icon: Icons.person_outline,
                            label: '계정',
                            value: linkedName.isNotEmpty
                                ? '$linkedName ($uid)'
                                : uid,
                          ),
                        ],
                        if (memo.isNotEmpty) ...[
                          SizedBox(height: context.rsi(2)),
                          WorkerProfileInfoRow(
                            icon: Icons.sticky_note_2_outlined,
                            label: '메모',
                            value: memo,
                          ),
                        ],
                        if (human.hid != null) ...[
                          SizedBox(height: context.rsi(2)),
                          WorkerProfileInfoRow(
                            icon: Icons.tag_outlined,
                            label: '인력 ID',
                            value: '${human.hid}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (onEditAssignment != null) ...[
              SizedBox(height: context.rsi(12)),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(context);
                  onEditAssignment!();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('이 투입의 역할·일당 수정'),
              ),
            ],
            if (onRemoveFromRecent != null) ...[
              SizedBox(height: context.rsi(8)),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('목록에서 제거'),
                      content: Text(
                        '${human.hname} 님을 이 현장 목록에서 제거할까요?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dctx).pop(false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dctx).pop(true),
                          child: Text(
                            '제거',
                            style: TextStyle(
                              color: Theme.of(dctx).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  Navigator.pop(context);
                  await onRemoveFromRecent!();
                },
                icon: Icon(Icons.delete_outline, color: cs.error),
                label: Text(
                  '이 현장 목록에서 제거',
                  style: TextStyle(color: cs.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
