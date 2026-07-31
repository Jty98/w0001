import 'package:flutter/material.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_person_row.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

class PlaceWorkforceTaskCard extends StatefulWidget {
  const PlaceWorkforceTaskCard({
    super.key,
    required this.taskName,
    required this.accentIndex,
    required this.rowsForTask,
    required this.canEdit,
    required this.humanName,
    this.onAddWorkforce,
    this.onEdit,
    this.onDelete,
  });

  final String taskName;
  final int accentIndex;
  final List<PlaceWorkDayRead> rowsForTask;
  final bool canEdit;
  final String Function(int hid) humanName;
  final VoidCallback? onAddWorkforce;
  final void Function(PlaceWorkDayRead row)? onEdit;
  final void Function(PlaceWorkDayRead row)? onDelete;

  @override
  State<PlaceWorkforceTaskCard> createState() => _PlaceWorkforceTaskCardState();
}

class _PlaceWorkforceTaskCardState extends State<PlaceWorkforceTaskCard> {
  var _peopleExpanded = true;

  static const _accents = <Color>[
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stripe = _accents[widget.accentIndex.abs() % _accents.length];

    return DecoratedBox(
      decoration: AppSectionCardStyles.cardDecoration(context),
      child: ClipRRect(
        borderRadius: AppSectionCardStyles.borderRadius(context),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(12),
                context.rsi(10),
                context.rsi(10),
                context.rsi(8),
              ),
              child: LayoutBuilder(
                builder: (ctx, c) {
                  final stackBtn = c.maxWidth < context.rs(340);
                  final btn = widget.onAddWorkforce == null
                      ? null
                      : FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rsi(12),
                              vertical: context.rsi(7),
                            ),
                            minimumSize: Size(0, context.rs(34)),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: widget.onAddWorkforce,
                          icon: Icon(
                            Icons.person_add_alt_1_outlined,
                            size: context.rs(17),
                          ),
                          label: Text(
                            '인력 투입',
                            style: tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                  final hasPeople = widget.rowsForTask.isNotEmpty;
                  final rosterToggle = hasPeople
                      ? IconButton(
                          tooltip:
                              _peopleExpanded ? '이 공정 인원 목록 접기' : '인원 목록 펼치기',
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(
                            () => _peopleExpanded = !_peopleExpanded,
                          ),
                          icon: Icon(
                            _peopleExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                        )
                      : null;
                  final headerRow = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: context.rs(36),
                        height: context.rs(36),
                        alignment: Alignment.center,
                        decoration: AppSectionCardStyles.iconBadgeDecoration(
                          context,
                          cs,
                        ),
                        child: Icon(
                          Icons.construction_rounded,
                          color: stripe,
                          size: context.rs(18),
                        ),
                      ),
                      SizedBox(width: context.rsi(8)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.taskName,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: cs.onSurface,
                              ),
                            ),
                            SizedBox(height: context.rsi(1)),
                            Text(
                              widget.rowsForTask.isEmpty
                                  ? '투입 인원 추가'
                                  : '${widget.rowsForTask.length}명',
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (rosterToggle != null) rosterToggle,
                      if (!stackBtn && btn != null) btn,
                    ],
                  );
                  if (stackBtn && btn != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        headerRow,
                        SizedBox(height: context.rsi(12)),
                        btn,
                      ],
                    );
                  }
                  return headerRow;
                },
              ),
            ),
            const AppInsetDivider(),
            if (widget.rowsForTask.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.rsi(14),
                  context.rsi(8),
                  context.rsi(14),
                  context.rsi(12),
                ),
                child: Text(
                  '아직 이 공정 투입이 없습니다.',
                  style: tt.labelMedium?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              )
            else
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _peopleExpanded
                    ? Padding(
                        padding: EdgeInsets.only(bottom: context.rsi(4)),
                        child: Column(
                          children: [
                            for (var i = 0; i < widget.rowsForTask.length; i++)
                              PlaceWorkforcePersonRow(
                                compact: true,
                                name: widget.humanName(
                                  widget.rowsForTask[i].hid,
                                ),
                                wageLabel: getPrice(
                                  price: widget.rowsForTask[i].dailywage,
                                ),
                                settled: widget.rowsForTask[i].paid == 1,
                                canEdit: widget.canEdit,
                                hasWorkInstruction:
                                    !workInstructionBlocksLookEmpty(
                                  widget
                                      .rowsForTask[i].resolvedInstructionBlocks,
                                ),
                                roleLabel: widget.rowsForTask[i].workrole
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : widget.rowsForTask[i].workrole.trim(),
                                onEdit: widget.onEdit != null && widget.canEdit
                                    ? () => widget.onEdit!(
                                          widget.rowsForTask[i],
                                        )
                                    : null,
                                onDelete:
                                    widget.onDelete != null && widget.canEdit
                                        ? () => widget.onDelete!(
                                              widget.rowsForTask[i],
                                            )
                                        : null,
                                showBottomDivider:
                                    i < widget.rowsForTask.length - 1,
                              ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
          ],
        ),
      ),
    );
  }
}

/// 공정표와 역할명이 맞지 않는 투입(공정외 투입) — 인원 목록 접기.
class PlaceWorkforceOtherRolesCollapsibleCard extends StatefulWidget {
  const PlaceWorkforceOtherRolesCollapsibleCard({
    super.key,
    required this.otherRows,
    required this.canEdit,
    required this.humanName,
    this.onEditRow,
    this.onDeleteRow,
  });

  final List<PlaceWorkDayRead> otherRows;
  final bool canEdit;
  final String Function(int hid) humanName;
  final void Function(PlaceWorkDayRead row)? onEditRow;
  final void Function(PlaceWorkDayRead row)? onDeleteRow;

  @override
  State<PlaceWorkforceOtherRolesCollapsibleCard> createState() =>
      _PlaceWorkforceOtherRolesCollapsibleCardState();
}

class _PlaceWorkforceOtherRolesCollapsibleCardState
    extends State<PlaceWorkforceOtherRolesCollapsibleCard> {
  var _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final n = widget.otherRows.length;

    return DecoratedBox(
      decoration: AppSectionCardStyles.cardDecoration(context),
      child: ClipRRect(
        borderRadius: AppSectionCardStyles.borderRadius(context),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(12),
                  vertical: context.rsi(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.rs(36),
                      height: context.rs(36),
                      alignment: Alignment.center,
                      decoration: AppSectionCardStyles.iconBadgeDecoration(
                        context,
                        cs,
                      ),
                      child: Icon(
                        Icons.badge_outlined,
                        color: cs.primary,
                        size: context.rs(18),
                      ),
                    ),
                    SizedBox(width: context.rsi(8)),
                    Expanded(
                      child: Text(
                        '공정외 투입 · $n명',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const AppInsetDivider(),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Column(
                      children: List.generate(widget.otherRows.length, (i) {
                        final r = widget.otherRows[i];
                        return PlaceWorkforcePersonRow(
                          compact: true,
                          name: widget.humanName(r.hid),
                          wageLabel: getPrice(price: r.dailywage),
                          settled: r.paid == 1,
                          canEdit: widget.canEdit,
                          hasWorkInstruction: !workInstructionBlocksLookEmpty(
                            r.resolvedInstructionBlocks,
                          ),
                          roleLabel: r.workrole.trim().isEmpty
                              ? '역할 없음'
                              : r.workrole.trim(),
                          onEdit: widget.canEdit && widget.onEditRow != null
                              ? () => widget.onEditRow!(r)
                              : null,
                          onDelete: widget.canEdit && widget.onDeleteRow != null
                              ? () => widget.onDeleteRow!(r)
                              : null,
                          showBottomDivider: i < widget.otherRows.length - 1,
                        );
                      }),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
