import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_site_guide_providers.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_screen.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_site_info_dialog.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_worker_instruction_week_peek.dart';
import 'package:w0001/navigation/place_navigation.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 공사금액 대비 영업이익률(표시만). `공사금액 ≤ 0` 이면 퍼센트 생략.
String _formatProfitAmountAndMarginPct(int profit, int contractTotal) {
  final money = getPrice(price: profit);
  if (contractTotal <= 0) return money;
  final pct = (profit / contractTotal) * 100.0;
  return '$money (${pct.toStringAsFixed(1)}%)';
}

EdgeInsets _placeDetailOuterPadding(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final h = (size.width * 0.038).clamp(context.rs(10), context.rs(22));
  final v = (size.height * 0.014).clamp(context.rs(8), context.rs(14));
  return EdgeInsets.fromLTRB(h, v, h, v * 1.05);
}

/// 금액 요약 카드와 메뉴 리스트 사이 간격(기기 shortest side 기준).
double _placeSummaryMenuGap(BuildContext context) =>
    (MediaQuery.sizeOf(context).shortestSide * 0.012)
        .clamp(context.rs(4), context.rs(8));

double _placeMenuListGap(BuildContext context) =>
    (MediaQuery.sizeOf(context).shortestSide * 0.016).clamp(5.0, 8.0);

/// 폰이면 전폭, 태블릿·폴더블 넓은 폭에서는 가독성을 위해 최대 560.
double _placeDetailContentMaxWidth(double screenWidth) =>
    screenWidth > 600 ? 560.0 : screenWidth;

/// `Sliver*` 경로에서는 자식 안에 [LayoutBuilder]가 있으면 intrinsic 측정 시 예외가 날 수 있다.
/// 본 화면 [ConstrainedBox](maxWidth) + 바깥 [Padding]과 같은 폭을 [MediaQuery]로 맞춘다.
double _placeDetailSummaryCardLayoutWidth(BuildContext context) {
  final mq = MediaQuery.sizeOf(context);
  final contentMaxW = _placeDetailContentMaxWidth(mq.width);
  final columnW = math.min(mq.width, contentMaxW);
  final outer = _placeDetailOuterPadding(context);
  final inner = columnW - outer.horizontal;
  if (!inner.isFinite || inner <= 0) return 320;
  return inner.clamp(120.0, 2000.0);
}

PlaceInfoModel _placeSyncedWithList(WidgetRef ref, PlaceInfoModel initial) {
  final pid = initial.pid;
  if (pid == null) return initial;
  for (final p in ref.watch(placeListProvider).placeList) {
    if (p.pid == pid) return p;
  }
  return initial;
}

class PlaceDetailScreen extends ConsumerWidget {
  final PlaceInfoModel placeInfo;

  const PlaceDetailScreen({super.key, required this.placeInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = _placeSyncedWithList(ref, placeInfo);
    final me = ref.watch(authSessionProvider).asData?.value;
    final isManagement = me?.isManagementRole ?? false;
    final isWorker = me?.isWorker ?? false;
    final showWorkforce = me != null && me.isManagementRole;

    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.sizeOf(context);
    final outerPad = _placeDetailOuterPadding(context);
    final contentMaxW = _placeDetailContentMaxWidth(mq.width);
    final gapMid =
        (mq.shortestSide * 0.022).clamp(context.rs(6), context.rs(14));
    final summaryMenuGap = _placeSummaryMenuGap(context);

    final menuItems = <_PlaceMenuItem>[
      _PlaceMenuItem(
        title: '현장 공지',
        icon: Icons.campaign_rounded,
        accentColor: cs.primary,
        onTap: () => context.push('/place/detail/announcements', extra: place),
      ),
      _PlaceMenuItem(
        title: '공정표',
        icon: Icons.calendar_view_month_rounded,
        accentColor: const Color(0xFF6750A4),
        onTap: () =>
            context.push('/place/detail/process-schedule', extra: place),
      ),
      _PlaceMenuItem(
        title: '작업 체크리스트',
        icon: Icons.checklist_rounded,
        accentColor: const Color(0xFF2E7D32),
        onTap: () => context.push('/place/detail/checklist', extra: place),
      ),
      _PlaceMenuItem(
        title: '문서관리',
        icon: Icons.folder_open_rounded,
        accentColor: cs.secondary,
        onTap: () => context.push('/place/detail/images', extra: place),
      ),
      if (!isWorker)
        _PlaceMenuItem(
          title: '금액관리',
          icon: Icons.account_balance_wallet_rounded,
          accentColor: cs.tertiary,
          onTap: () => context.push('/place/detail/cost', extra: place),
        ),
      if (showWorkforce)
        _PlaceMenuItem(
          title: '작업지시',
          icon: Icons.assignment_rounded,
          accentColor: const Color(0xFF006A6A),
          onTap: () => context.push(
            '/place/detail/workforce',
            extra: PlaceWorkforceRouteExtra(placeInfo: place),
          ),
        ),
      if (isManagement)
        _PlaceMenuItem(
          title: '인력 초대',
          icon: Icons.person_add_rounded,
          accentColor: const Color(0xFFB3261E),
          onTap: () => context.push('/place/detail/members', extra: place),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: placeSubrouteBackLeading(context),
        title: Text(
          place.pname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '현장 정보 · 인수인계',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              // ✅ 미리 데이터 로드 시작 (비동기, 백그라운드)
              final pid = place.pid;
              if (pid != null) {
                ref.read(placeSiteGuideByPidProvider(pid).notifier).load();
              }

              // ✅ 즉시 다이얼로그 열기 (로딩 중이면 스켈레톤 표시)
              showPlaceSiteInfoDialog(
                context,
                ref: ref,
                place: place,
                showManagementMoney: isManagement,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxW),
            child: Padding(
              padding: outerPad,
              child: isWorker
                  ? _WorkerPlaceDetailColumn(
                      gapMid: gapMid,
                      place: place,
                      menuItems: menuItems,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isManagement) ...[
                          _PlaceDetailSummaryCard(place: place),
                          SizedBox(height: summaryMenuGap),
                        ],
                        Expanded(
                          child: _PlaceMenuList(menuItems: menuItems),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceDetailSummaryCard extends StatelessWidget {
  const _PlaceDetailSummaryCard({required this.place});

  final PlaceInfoModel place;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalRevenue = place.pfirstrevenue + place.totalAdditionalRevenue;
    final balance = (place.pcontractTotal - totalRevenue) < 0
        ? 0
        : (place.pcontractTotal - totalRevenue);
    final totalCost = place.mTotal + place.wTotal;
    final profit = totalRevenue - totalCost;

    final lw = _placeDetailSummaryCardLayoutWidth(context);
    final padH = (lw * 0.028).clamp(context.rs(9), context.rs(14));
    final padV = (lw * 0.020).clamp(context.rs(6), context.rs(9));

    return AppSectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: '금액 요약',
      denseHeader: true,
      contentPadding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
      child: _MgmtMoneyGrid(
        colorScheme: cs,
        layoutWidth: lw,
        contract: place.pcontractTotal,
        collected: totalRevenue,
        balance: balance,
        cost: totalCost,
        profit: profit,
      ),
    );
  }
}

class _MgmtMoneyGrid extends StatelessWidget {
  const _MgmtMoneyGrid({
    required this.colorScheme,
    required this.layoutWidth,
    required this.contract,
    required this.collected,
    required this.balance,
    required this.cost,
    required this.profit,
  });

  final ColorScheme colorScheme;
  final double layoutWidth;
  final int contract;
  final int collected;
  final int balance;
  final int cost;
  final int profit;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final profitAccent = profit >= 0 ? cs.primary : cs.error;
    final gap = (layoutWidth * 0.015).clamp(5.0, 9.0);
    final tilePadH = (layoutWidth * 0.020).clamp(7.0, 10.0);
    final tilePadV = (layoutWidth * 0.016).clamp(5.0, 8.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _TintedMoneyTile(
                label: '공사금액',
                value: getPrice(price: contract),
                accent: cs.tertiary,
                icon: Icons.description_outlined,
                layoutWidth: layoutWidth,
                padding:
                    EdgeInsets.fromLTRB(tilePadH, tilePadV, tilePadH, tilePadV),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _TintedMoneyTile(
                label: '수금액',
                value: getPrice(price: collected),
                accent: cs.primary,
                icon: Icons.account_balance_wallet_outlined,
                layoutWidth: layoutWidth,
                padding:
                    EdgeInsets.fromLTRB(tilePadH, tilePadV, tilePadH, tilePadV),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _TintedMoneyTile(
                label: '잔금',
                value: getPrice(price: balance),
                accent: cs.secondary,
                icon: Icons.request_quote_outlined,
                layoutWidth: layoutWidth,
                padding:
                    EdgeInsets.fromLTRB(tilePadH, tilePadV, tilePadH, tilePadV),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _TintedMoneyTile(
                label: '공사원가',
                value: getPrice(price: cost),
                accent: cs.tertiaryContainer,
                icon: Icons.payments_outlined,
                layoutWidth: layoutWidth,
                padding:
                    EdgeInsets.fromLTRB(tilePadH, tilePadV, tilePadH, tilePadV),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        AppInsetTile(
          padding: EdgeInsets.symmetric(
            horizontal: (layoutWidth * 0.024).clamp(8.0, 12.0),
            vertical: (layoutWidth * 0.020).clamp(6.0, 9.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.trending_up_rounded,
                  size: (layoutWidth * 0.040).clamp(14.0, 17.0),
                  color: profitAccent),
              SizedBox(width: (layoutWidth * 0.014).clamp(5.0, 8.0)),
              Expanded(
                flex: 2,
                child: Text(
                  '현재 영업이익',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
              Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatProfitAmountAndMarginPct(profit, contract),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: profitAccent,
                        ),
                    maxLines: 1,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TintedMoneyTile extends StatelessWidget {
  const _TintedMoneyTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    required this.layoutWidth,
    required this.padding,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;
  final double layoutWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final iconSz = (layoutWidth * 0.038).clamp(context.rs(13), context.rs(16));

    return AppInsetTile(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: iconSz + 6,
                height: iconSz + 6,
                alignment: Alignment.center,
                decoration:
                    AppSectionCardStyles.iconBadgeDecoration(context, cs),
                child: Icon(icon, size: iconSz, color: accent),
              ),
              SizedBox(width: (layoutWidth * 0.014).clamp(4.0, 7.0)),
              Expanded(
                child: Text(
                  label,
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(
              height:
                  (layoutWidth * 0.014).clamp(context.rs(4), context.rs(7))),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
                color: cs.onSurface,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceMenuItem {
  final String title;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _PlaceMenuItem({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });
}

class _PlaceMenuList extends StatelessWidget {
  const _PlaceMenuList({required this.menuItems});

  final List<_PlaceMenuItem> menuItems;

  @override
  Widget build(BuildContext context) {
    if (menuItems.isEmpty) return const SizedBox.shrink();

    final gap = _placeMenuListGap(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < menuItems.length; i++) ...[
          Expanded(
            child: _ModernMenuCard(item: menuItems[i]),
          ),
          if (i < menuItems.length - 1) SizedBox(height: gap),
        ],
      ],
    );
  }
}

/// 작업자 하단: 요약 아래 — 작업 내용 주간 캘린더 + 메뉴 리스트.
class _WorkerPlaceDetailColumn extends StatelessWidget {
  const _WorkerPlaceDetailColumn({
    required this.gapMid,
    required this.place,
    required this.menuItems,
  });

  final double gapMid;
  final PlaceInfoModel place;
  final List<_PlaceMenuItem> menuItems;

  @override
  Widget build(BuildContext context) {
    final hasPid = place.pid != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPid) PlaceWorkerInstructionWeekPeek(place: place),
        if (hasPid) SizedBox(height: gapMid * 0.4),
        Expanded(
          child: _PlaceMenuList(menuItems: menuItems),
        ),
      ],
    );
  }
}

class _ModernMenuCard extends StatelessWidget {
  const _ModernMenuCard({required this.item});

  final _PlaceMenuItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final side = MediaQuery.sizeOf(context).shortestSide;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotH = constraints.maxHeight;
        final compact = slotH.isFinite &&
            slotH > 0 &&
            slotH < (side * 0.14).clamp(46.0, 56.0);
        final padH = (side * 0.04).clamp(12.0, 16.0);
        final padV = compact
            ? (slotH * 0.12).clamp(4.0, 8.0)
            : (side * 0.028).clamp(6.0, 12.0);
        final iconBox = compact
            ? (slotH * 0.72).clamp(30.0, 40.0)
            : (side * 0.11).clamp(36.0, 44.0);
        final iconSz = (iconBox * 0.52).clamp(18.0, 24.0);
        final chevronSz = compact
            ? (slotH * 0.30).clamp(12.0, 16.0)
            : (side * 0.042).clamp(14.0, 17.0);
        final gap = (side * 0.032).clamp(8.0, 14.0);
        final cardRadius = AppSectionCardStyles.borderRadius(context);

        return DecoratedBox(
          decoration: AppSectionCardStyles.cardDecoration(context),
          child: ClipRRect(
            borderRadius: cardRadius,
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.onTap,
                borderRadius: cardRadius,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                  child: Row(
                    children: [
                      Container(
                        width: 3.5,
                        height: iconBox,
                        decoration: BoxDecoration(
                          color: item.accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: gap),
                      Container(
                        width: iconBox,
                        height: iconBox,
                        alignment: Alignment.center,
                        decoration: AppSectionCardStyles.iconBadgeDecoration(
                          context,
                          cs,
                        ),
                        child: Icon(
                          item.icon,
                          color: item.accentColor,
                          size: iconSz,
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item.title,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: gap * 0.5),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        size: chevronSz,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
