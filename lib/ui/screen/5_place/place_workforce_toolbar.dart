import 'package:flutter/material.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 좁은 폭에서 줄 바꿈·Wrap으로 버튼이 잘리지 않게 한다.
class PlaceWorkforceDayToolbar extends StatelessWidget {
  const PlaceWorkforceDayToolbar({
    super.key,
    required this.selectedDay,
    required this.rosterListExpanded,
    required this.onToggleRosterList,
    required this.canEdit,
    required this.onAddProcess,
    required this.onAddWorkforceOnly,
  });

  final DateTime selectedDay;
  /// 캘린더 아래 투입 목록 전체 표시 여부.
  final bool rosterListExpanded;
  final VoidCallback onToggleRosterList;
  final bool canEdit;
  final VoidCallback onAddProcess;
  final VoidCallback onAddWorkforceOnly;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final narrow = c.maxWidth < 380;
        final shortScreen = MediaQuery.sizeOf(ctx).height < 720;
        final compact = shortScreen || narrow;
        final tt = Theme.of(ctx).textTheme;
        final title = Text(
          formatDateTimeToKorean(selectedDay),
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: compact ? 1.2 : null,
          ),
        );
        final rosterToggle = IconButton(
          tooltip: rosterListExpanded ? '투입 목록 접기' : '투입 목록 펼치기',
          onPressed: onToggleRosterList,
          icon: Icon(
            rosterListExpanded
                ? Icons.unfold_less_rounded
                : Icons.unfold_more_rounded,
          ),
        );
        final actions = canEdit
            ? <Widget>[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: ctx.rsi(compact ? 6 : 8),
                      vertical: ctx.rsi(compact ? 2 : 4),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: compact
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                  ),
                  onPressed: onAddProcess,
                  icon: Icon(
                    Icons.add_task_outlined,
                    size: ctx.rs(compact ? 18 : 20),
                  ),
                  label: Text(
                    '공정 추가',
                    style: tt.labelLarge,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: ctx.rsi(compact ? 6 : 8),
                      vertical: ctx.rsi(compact ? 2 : 4),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: compact
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                  ),
                  onPressed: onAddWorkforceOnly,
                  icon: Icon(
                    Icons.person_add_alt_1_outlined,
                    size: ctx.rs(compact ? 18 : 20),
                  ),
                  label: Text(
                    '기타 투입',
                    style: tt.labelLarge,
                  ),
                ),
              ]
            : <Widget>[];

        final barPad = EdgeInsets.fromLTRB(
          ctx.rsi(compact ? 12 : 16),
          ctx.rsi(compact ? 4 : 8),
          ctx.rsi(compact ? 12 : 16),
          ctx.rsi(compact ? 2 : 4),
        );

        if (narrow && actions.isNotEmpty) {
          return Padding(
            padding: barPad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: title),
                    rosterToggle,
                  ],
                ),
                SizedBox(height: ctx.rsi(compact ? 4 : 6)),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: ctx.rsi(2),
                  runSpacing: 0,
                  children: actions,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: barPad,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              rosterToggle,
              ...actions,
            ],
          ),
        );
      },
    );
  }
}
