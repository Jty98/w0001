import 'package:flutter/material.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 작업지시 첫 화면 페이지뷰 높이 — 작은 폰은 목록을 더 주고, 태블릿은 상한을 올린다.
double workInstructionPagerHeight(BuildContext context, double maxHeight) {
  if (!maxHeight.isFinite || maxHeight <= 0) {
    return context.rs(180);
  }
  final compact = context.isCompactDevice;
  final tablet = context.isTabletDevice;
  final frac = compact ? 0.26 : (tablet ? 0.28 : 0.30);
  final minH = context.rs(compact ? 140 : 156);
  final maxH = context.rs(tablet ? 236 : (compact ? 176 : 200));
  return (maxHeight * frac).clamp(minH, maxH);
}

class WorkInstructionPlaceDayStat {
  const WorkInstructionPlaceDayStat({
    required this.pid,
    required this.placeName,
    required this.workerCount,
    required this.processCount,
    required this.laborCost,
    required this.processNames,
  });

  final int pid;
  final String placeName;
  final int workerCount;
  final int processCount;
  final int laborCost;
  final List<String> processNames;
}

class WorkInstructionDayOverview {
  const WorkInstructionDayOverview({
    required this.day,
    required this.places,
  });

  final DateTime day;
  final List<WorkInstructionPlaceDayStat> places;

  int get workerCount => places.fold<int>(0, (sum, p) => sum + p.workerCount);

  int get laborCost => places.fold<int>(0, (sum, p) => sum + p.laborCost);

  int get placeCount => places.length;

  int get processCount => places.fold<int>(0, (sum, p) => sum + p.processCount);
}

WorkInstructionDayOverview buildWorkInstructionDayOverview({
  required DateTime day,
  required List<PlaceWorkDayRead> rows,
  required Map<int, String> placeNameByPid,
}) {
  final key = formatDateTimeToIsoDate(day);
  final byPid = <int, List<PlaceWorkDayRead>>{};
  for (final r in rows) {
    if (normalizeToIsoDateString(r.workdate) != key) continue;
    byPid.putIfAbsent(r.pid, () => []).add(r);
  }
  final places = <WorkInstructionPlaceDayStat>[];
  for (final entry in byPid.entries) {
    final hids = <int>{};
    final roles = <String>{};
    var cost = 0;
    for (final r in entry.value) {
      hids.add(r.hid);
      cost += r.dailywage;
      final role = r.workrole.trim();
      roles.add(role.isEmpty ? '기타' : role);
    }
    final names = roles.toList()..sort();
    final label = placeNameByPid[entry.key]?.trim();
    places.add(
      WorkInstructionPlaceDayStat(
        pid: entry.key,
        placeName:
            (label != null && label.isNotEmpty) ? label : '현장 #${entry.key}',
        workerCount: hids.length,
        processCount: names.length,
        laborCost: cost,
        processNames: names,
      ),
    );
  }
  places.sort((a, b) => b.workerCount.compareTo(a.workerCount));
  return WorkInstructionDayOverview(day: day, places: places);
}

class WorkInstructionOverviewPager extends StatelessWidget {
  const WorkInstructionOverviewPager({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.dayForPage,
    required this.overviewFor,
    required this.pageIndex,
    required this.today,
    required this.loading,
    required this.onPageChanged,
    required this.onSelectPlace,
    required this.onJumpToday,
    this.pageHeight,
  });

  final PageController controller;
  final int itemCount;
  final DateTime Function(int page) dayForPage;
  final WorkInstructionDayOverview Function(DateTime day) overviewFor;
  final int pageIndex;
  final DateTime today;
  final bool loading;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSelectPlace;
  final VoidCallback onJumpToday;
  final double? pageHeight;

  @override
  Widget build(BuildContext context) {
    final todayKey = formatDateTimeToIsoDate(today);
    final current = dayForPage(pageIndex);
    final isToday = formatDateTimeToIsoDate(current) == todayKey;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: context.rsi(6),
              bottom: context.rsi(2),
            ),
            child: isToday
                ? TextButton.icon(
                    onPressed: null,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.today_rounded, size: context.rs(18)),
                    label: const Text('오늘'),
                  )
                : FilledButton.tonalIcon(
                    onPressed: onJumpToday,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.today_rounded, size: context.rs(18)),
                    label: const Text('오늘'),
                  ),
          ),
        ),
        SizedBox(
          height: pageHeight ?? context.rs(188),
          child: PageView.builder(
            controller: controller,
            itemCount: itemCount,
            onPageChanged: onPageChanged,
            itemBuilder: (context, i) {
              final day = dayForPage(i);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: context.rsi(6)),
                child: _DayPageCard(
                  day: day,
                  overview: overviewFor(day),
                  isToday: formatDateTimeToIsoDate(day) == todayKey,
                  loading: loading,
                  onSelectPlace: onSelectPlace,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayPageCard extends StatelessWidget {
  const _DayPageCard({
    required this.day,
    required this.overview,
    required this.isToday,
    required this.loading,
    required this.onSelectPlace,
  });

  final DateTime day;
  final WorkInstructionDayOverview overview;
  final bool isToday;
  final bool loading;
  final ValueChanged<int> onSelectPlace;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: AppSectionCardStyles.cardDecoration(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(14),
          context.rsi(12),
          context.rsi(14),
          context.rsi(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  formatDateTimeWeekDayToString(day),
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (isToday) ...[
                  SizedBox(width: context.rsi(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.rsi(8),
                      vertical: context.rsi(2),
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '오늘',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: context.rsi(8)),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : overview.places.isEmpty
                      ? Center(
                          child: Text(
                            '투입된 현장이 없습니다',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: overview.places.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: context.rsi(6)),
                          itemBuilder: (context, i) {
                            final p = overview.places[i];
                            return _TodayPlaceRow(
                              stat: p,
                              onTap: () => onSelectPlace(p.pid),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPlaceRow extends StatelessWidget {
  const _TodayPlaceRow({required this.stat, required this.onTap});

  final WorkInstructionPlaceDayStat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.appInsetFill,
      borderRadius: BorderRadius.circular(context.rs(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.rs(12)),
        child: Padding(
          padding: EdgeInsets.all(context.rsi(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.placeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: context.rsi(2)),
              Text(
                '공정 ${stat.processCount}개  인력 ${stat.workerCount}명',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (stat.processNames.isNotEmpty) ...[
                SizedBox(height: context.rsi(4)),
                Text(
                  stat.processNames.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WorkInstructionDayStatsCard extends StatelessWidget {
  const WorkInstructionDayStatsCard({
    super.key,
    required this.overview,
  });

  final WorkInstructionDayOverview overview;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rsi(16),
        context.rsi(8),
        context.rsi(16),
        context.rsi(2),
      ),
      child: DecoratedBox(
        decoration: AppSectionCardStyles.cardDecoration(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(12),
            vertical: context.rsi(10),
          ),
          child: Row(
            children: [
              Container(
                width: context.rs(40),
                height: context.rs(40),
                decoration: AppSectionCardStyles.iconBadgeDecoration(
                  context,
                  cs,
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: cs.primary,
                  size: context.rs(22),
                ),
              ),
              SizedBox(width: context.rsi(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '인건비',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      getPrice(price: overview.laborCost),
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '현장 ${overview.placeCount}곳  인력 ${overview.workerCount}명',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
