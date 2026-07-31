import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 캘린더 접기 아래 — 전체 작업지시·투입 목록·공정/투입 액션.
class PlaceWorkforceDayToolbar extends StatelessWidget {
  const PlaceWorkforceDayToolbar({
    super.key,
    required this.rosterListExpanded,
    required this.onToggleRosterList,
    required this.canEdit,
    required this.onAddProcess,
    required this.onAddWorkforceOnly,
    this.siteInstructionLoading = false,
    this.siteInstructionBlocks = const [],
    this.onEditSiteInstruction,
  });

  final bool rosterListExpanded;
  final VoidCallback onToggleRosterList;
  final bool canEdit;
  final VoidCallback onAddProcess;
  final VoidCallback onAddWorkforceOnly;
  final bool siteInstructionLoading;
  final List<WorkerAnnouncementBlock> siteInstructionBlocks;
  final VoidCallback? onEditSiteInstruction;

  bool get _hasSiteInstruction =>
      !workInstructionBlocksLookEmpty(siteInstructionBlocks);

  Widget _iconAction(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? iconColor,
    Widget? iconWidget,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: context.rs(34),
        minHeight: context.rs(34),
      ),
      icon: iconWidget ?? Icon(icon, size: context.rs(20), color: iconColor),
    );
  }

  Widget _siteInstructionButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (siteInstructionLoading) {
      return _iconAction(
        context,
        tooltip: '전체 작업지시 불러오는 중',
        icon: Icons.campaign_outlined,
        onPressed: null,
        iconWidget: SizedBox(
          width: context.rs(18),
          height: context.rs(18),
          child: const HammerLoadingIndicator(size: 18),
        ),
      );
    }

    final has = _hasSiteInstruction;
    return _iconAction(
      context,
      tooltip: has ? '전체 작업지시 (작성됨)' : '전체 작업지시 작성',
      icon: Icons.campaign_outlined,
      onPressed: onEditSiteInstruction,
      iconColor: has ? cs.primary : cs.onSurfaceVariant,
      iconWidget: Badge(
        isLabelVisible: has,
        smallSize: 7,
        backgroundColor: cs.primary,
        child: Icon(
          Icons.campaign_outlined,
          size: context.rs(20),
          color: has ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(8),
        context.rsi(2),
        context.rsi(4),
        context.rsi(2),
      ),
      child: Row(
        children: [
          if (canEdit) _siteInstructionButton(context),
          const Spacer(),
          _iconAction(
            context,
            tooltip: rosterListExpanded ? '투입 목록 접기' : '투입 목록 펼치기',
            icon: rosterListExpanded
                ? Icons.view_agenda_outlined
                : Icons.view_agenda,
            onPressed: onToggleRosterList,
          ),
          if (canEdit) ...[
            _iconAction(
              context,
              tooltip: '공정 추가',
              icon: Icons.add_task_outlined,
              onPressed: onAddProcess,
            ),
            _iconAction(
              context,
              tooltip: '공정외 투입',
              icon: Icons.person_add_alt_1_outlined,
              onPressed: onAddWorkforceOnly,
            ),
          ],
        ],
      ),
    );
  }
}
