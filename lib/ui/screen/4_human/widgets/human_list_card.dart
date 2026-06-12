import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/worker_skills_display.dart';
import 'package:w0001/util/responsive_layout.dart';

class _HumanCardInfoRow extends StatelessWidget {
  const _HumanCardInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWeight = FontWeight.w600,
    this.maxLines = 2,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final FontWeight valueWeight;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: context.rsi(62),
            child: Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                color: valueColor ?? cs.onSurface,
                fontWeight: valueWeight,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HumanCardCopyableInfoRow extends StatelessWidget {
  const _HumanCardCopyableInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  bool get _canCopy => value.trim().isNotEmpty && value != '-';

  Future<void> _copy(BuildContext context) async {
    if (!_canCopy) return;
    await Clipboard.setData(ClipboardData(text: value.trim()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label을(를) 복사했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: context.rsi(62),
          child: Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(
              color: _canCopy ? cs.primary : cs.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        if (_canCopy) ...[
          SizedBox(width: context.rsi(4)),
          Icon(
            Icons.copy_rounded,
            size: context.rs(14),
            color: cs.primary.withValues(alpha: 0.75),
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rsi(2)),
      child: _canCopy
          ? InkWell(
              onTap: () => _copy(context),
              borderRadius: BorderRadius.circular(context.rsi(6)),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.rsi(1)),
                child: row,
              ),
            )
          : row,
    );
  }
}

class HumanListCard extends ConsumerWidget {
  const HumanListCard({
    super.key,
    required this.index,
    required this.human,
    required this.onTap,
  });

  final int index;
  final HumanModel human;
  final VoidCallback onTap;

  static const double _radius = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isStarred = state.filteredWorkerList[index].hstar != 0;
    final skills = resolveHumanSkillsDisplay(human);
    final siteRole = human.hdefaultRole.trim();
    final primarySkill = skills.primary?.trim();
    final extrasText = skills.extras.isNotEmpty ? skills.extras.join(', ') : '-';
    final contact = _humanContactPhone(human);

    return Slidable(
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          CustomSlidableAction(
            onPressed: (slidableContext) {
              final container = ProviderScope.containerOf(slidableContext);
              showDialog<void>(
                context: slidableContext,
                builder: (dialogCtx) => deleteDialog(
                  onPressed: () async {
                    await vm.updateWorkerDelete(index);
                    await FetchData.fetchAllData();
                    container
                        .read(addCostProvider.notifier)
                        .clearSelectedWorker();
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }
                  },
                ),
              );
            },
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            padding: EdgeInsets.zero,
            child: Icon(Icons.delete_outline_rounded, size: context.rs(20)),
          ),
        ],
      ),
      child: Material(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.88),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.rs(_radius)),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.38),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(10),
              context.rsi(8),
              context.rsi(6),
              context.rsi(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              human.hname,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.25,
                                height: 1.15,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(
                              minWidth: context.rs(30),
                              minHeight: context.rs(30),
                            ),
                            tooltip: '즐겨찾기',
                            onPressed: () =>
                                vm.updateHstarFromWorkerList(index),
                            icon: Icon(
                              isStarred
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: context.rs(19),
                              color: isStarred
                                  ? cs.tertiary
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      _HumanCardInfoRow(
                        label: '일당',
                        value: getPrice(price: human.hdailyWage),
                      ),
                      _HumanCardInfoRow(
                        label: '현장역할',
                        value: siteRole.isNotEmpty ? siteRole : '-',
                      ),
                      _HumanCardInfoRow(
                        label: '주특기',
                        value: primarySkill != null && primarySkill.isNotEmpty
                            ? primarySkill
                            : '-',
                        valueColor: primarySkill != null && primarySkill.isNotEmpty
                            ? cs.primary
                            : cs.onSurfaceVariant.withValues(alpha: 0.8),
                        valueWeight: primarySkill != null && primarySkill.isNotEmpty
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      _HumanCardInfoRow(
                        label: '추가작업',
                        value: extrasText,
                        maxLines: 2,
                      ),
                      _HumanCardInfoRow(
                        label: '주민번호',
                        value: human.hnumber.trim().isNotEmpty
                            ? human.hnumber.trim()
                            : '-',
                        maxLines: 1,
                      ),
                      _HumanCardCopyableInfoRow(
                        label: '연락처',
                        value: contact,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.rsi(2)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: context.rs(20),
                  color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _humanContactPhone(HumanModel human) {
  final linked = human.linkedPhone?.trim();
  if (linked != null && linked.isNotEmpty) return linked;
  final phone = human.hphone?.trim();
  if (phone != null && phone.isNotEmpty) return phone;
  return '-';
}
