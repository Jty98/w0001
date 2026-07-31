import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/human_contact_display.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/theme/app_elevation.dart';
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

class _HumanTypeBadge extends StatelessWidget {
  const _HumanTypeBadge({required this.isMember});

  final bool isMember;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = isMember
        ? cs.primaryContainer.withValues(alpha: 0.65)
        : cs.tertiaryContainer.withValues(alpha: 0.7);
    final fg = isMember ? cs.onPrimaryContainer : cs.onTertiaryContainer;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rsi(8),
        vertical: context.rsi(4),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isMember ? '회원' : '비회원',
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1.0,
        ),
      ),
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
    final human = state.filteredWorkerList[index];
    final isStarred = human.hstar != 0;
    final siteRole = resolveHumanSiteRank(human) ?? '';
    final primarySkill = humanListPrimarySpecialtyLabel(human);
    final verifiedPhone = humanVerifiedPhone(human);
    final manualPhone = humanManualPhone(human);
    final canDeleteFromHumanList = humanIsNonMember(human);
    final isMember = humanIsLinkedAppMember(human);

    final card = DecoratedBox(
      decoration: AppElevation.sectionCard(
        context: context,
        backgroundColor: cs.surface,
        borderRadius: BorderRadius.circular(context.rs(_radius)),
        shadowIntensity: 0.75,
      ),
      child: Material(
        color: Colors.transparent,
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
                          SizedBox(width: context.rsi(6)),
                          _HumanTypeBadge(isMember: isMember),
                          SizedBox(width: context.rsi(2)),
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
                              color:
                                  isStarred ? cs.tertiary : cs.onSurfaceVariant,
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
                        valueColor:
                            primarySkill != null && primarySkill.isNotEmpty
                                ? cs.primary
                                : cs.onSurfaceVariant.withValues(alpha: 0.8),
                        valueWeight:
                            primarySkill != null && primarySkill.isNotEmpty
                                ? FontWeight.w700
                                : FontWeight.w500,
                      ),
                      _HumanCardInfoRow(
                        label: '주민번호',
                        value: human.hnumber.trim().isNotEmpty
                            ? human.hnumber.trim()
                            : '-',
                        maxLines: 1,
                      ),
                      if (verifiedPhone != null)
                        _HumanCardInfoRow(
                          label: kHumanVerifiedPhoneLabel,
                          value: verifiedPhone,
                          maxLines: 1,
                        ),
                      if (manualPhone != null)
                        _HumanCardInfoRow(
                          label: kHumanManualPhoneLabel,
                          value: manualPhone,
                          maxLines: 1,
                        ),
                      if (verifiedPhone == null && manualPhone == null)
                        const _HumanCardInfoRow(
                          label: '연락처',
                          value: '-',
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

    if (!canDeleteFromHumanList) return card;

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
                    await FetchData.onDataChanged(DataChangeEvent.humanSaved);
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
      child: card,
    );
  }
}
