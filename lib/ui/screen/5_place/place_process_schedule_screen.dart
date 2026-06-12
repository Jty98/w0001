import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_chart_views.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_dialogs.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_screen.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_dim.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_helpers.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_layout_segment.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_share_actions.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인테리어 공정표 — [placeProcessScheduleProvider] + 로컬/원격 저장소.
class PlaceProcessScheduleScreen extends ConsumerStatefulWidget {
  const PlaceProcessScheduleScreen({super.key, required this.placeInfo});

  final PlaceInfoModel placeInfo;

  @override
  ConsumerState<PlaceProcessScheduleScreen> createState() =>
      _PlaceProcessScheduleScreenState();
}

class _PlaceProcessScheduleScreenState
    extends ConsumerState<PlaceProcessScheduleScreen> {
  final TransformationController _transform = TransformationController();
  final GlobalKey _interactiveKey = GlobalKey();

  late final ScrollController _hHeader;
  late final ScrollController _hBody;
  late final ScrollController _vLeft;
  late final ScrollController _vBody;

  var _gateH = false;
  var _gateV = false;
  var _exiting = false;

  ProcessScheduleLayout _layout = ProcessScheduleLayout.stickyHeaders;

  /// 롱프레스 후 연속 칠하기 중 스크롤과 충돌 방지.
  var _brushScrollLock = false;

  Timer? _longPressBrushTimer;

  /// 롱프레스가 완료되어 손가락을 뗄 때까지 연속 칠하기 세션.
  var _brushPaintingSession = false;

  Offset? _pointerAnchorLocal;
  DateTime? _pointerDownAt;
  var _schedulePointerDown = false;

  /// 움직임이 크면 스크롤 의도로 간주해 롱프레스를 취소합니다.
  var _brushGestureCancelledByScroll = false;

  bool? _brushFillOn;
  (int, int)? _brushLastPair;

  ProcessScheduleFamilyArg get _scheduleKey => (
        pid: widget.placeInfo.pid ?? 0,
        pstart: widget.placeInfo.pstart,
        pend: widget.placeInfo.pend,
      );

  List<DateTime> _columnDates(ProcessScheduleData d) =>
      ProcessScheduleEditor.columnDates(d);

  void _openWorkforceForDay(DateTime day) {
    final p = widget.placeInfo;
    if (p.pid == null) return;
    context.push(
      '/place/detail/workforce',
      extra: PlaceWorkforceRouteExtra(
        placeInfo: p,
        initialWorkDate: DateTime(day.year, day.month, day.day),
      ),
    );
  }

  static const Duration _longPressBrushDuration = Duration(milliseconds: 480);

  /// 스크롤로 간주하기 전까지 허용하는 이동(px).
  static const double _scrollSlopPx = 14;

  void _cancelLongPressBrushTimer() {
    _longPressBrushTimer?.cancel();
    _longPressBrushTimer = null;
  }

  (int, int)? _hitBrushCell(Offset local, ProcessScheduleData d) {
    if (local.dx < 0 || local.dy < 0) return null;
    final cellW = ProcessScheduleChartDim.cellW(context);
    final cellH = ProcessScheduleChartDim.cellH(context);
    final di = local.dx ~/ cellW;
    final ti = local.dy ~/ cellH;
    if (di < 0 || di >= d.dayCount) return null;
    if (ti < 0 || ti >= d.tasks.length) return null;
    return (ti, di);
  }

  void _onStickyChartPointerDown(PointerDownEvent e) {
    if (_layout != ProcessScheduleLayout.stickyHeaders) return;
    _cancelLongPressBrushTimer();
    _pointerAnchorLocal = e.localPosition;
    _pointerDownAt = DateTime.now();
    _schedulePointerDown = true;
    _brushGestureCancelledByScroll = false;
    _brushPaintingSession = false;
    _brushFillOn = null;
    _brushLastPair = null;

    _longPressBrushTimer = Timer(_longPressBrushDuration, () {
      if (!mounted) return;
      if (!_schedulePointerDown || _brushGestureCancelledByScroll) return;
      final fresh = ref.read(placeProcessScheduleProvider(_scheduleKey)).data;
      final anchor = _pointerAnchorLocal;
      if (anchor == null) return;
      final hit = _hitBrushCell(anchor, fresh);
      if (hit == null) return;
      final wasOn = fresh.tasks[hit.$1].scheduledDayIndices.contains(hit.$2);
      _brushPaintingSession = true;
      _brushFillOn = !wasOn;
      _brushLastPair = hit;
      ref
          .read(placeProcessScheduleProvider(_scheduleKey).notifier)
          .applyDayPaint(hit.$1, hit.$2, _brushFillOn!);
      setState(() => _brushScrollLock = true);
    });
  }

  void _onStickyChartPointerMove(PointerMoveEvent e, ProcessScheduleData d) {
    if (_layout != ProcessScheduleLayout.stickyHeaders) return;
    final anchor = _pointerAnchorLocal;
    if (anchor == null) return;
    final dist = (e.localPosition - anchor).distance;

    if (!_brushPaintingSession && dist > _scrollSlopPx) {
      _brushGestureCancelledByScroll = true;
      _cancelLongPressBrushTimer();
    }

    if (!_brushPaintingSession || _brushFillOn == null) return;

    final notifier =
        ref.read(placeProcessScheduleProvider(_scheduleKey).notifier);
    final hit = _hitBrushCell(e.localPosition, d);
    if (hit == null) return;
    final last = _brushLastPair;
    if (last != null && last.$1 == hit.$1 && last.$2 == hit.$2) return;
    _brushLastPair = hit;
    notifier.applyDayPaint(hit.$1, hit.$2, _brushFillOn!);
  }

  void _onStickyChartPointerUp(PointerUpEvent e, ProcessScheduleData d) {
    if (_layout != ProcessScheduleLayout.stickyHeaders) return;
    _cancelLongPressBrushTimer();
    _schedulePointerDown = false;

    final notifier =
        ref.read(placeProcessScheduleProvider(_scheduleKey).notifier);

    if (_brushPaintingSession) {
      setState(() {
        _brushPaintingSession = false;
        _brushScrollLock = false;
      });
      _brushFillOn = null;
      _brushLastPair = null;
      _pointerAnchorLocal = null;
      _pointerDownAt = null;
      return;
    }

    if (!_brushGestureCancelledByScroll &&
        _pointerAnchorLocal != null &&
        _pointerDownAt != null) {
      final elapsed = DateTime.now().difference(_pointerDownAt!);
      if (elapsed < _longPressBrushDuration) {
        final hit = _hitBrushCell(_pointerAnchorLocal!, d);
        if (hit != null) {
          notifier.toggleCell(hit.$1, hit.$2);
        }
      }
    }

    _pointerAnchorLocal = null;
    _pointerDownAt = null;
    _brushFillOn = null;
    _brushLastPair = null;
  }

  void _onStickyChartPointerCancel() {
    _cancelLongPressBrushTimer();
    _schedulePointerDown = false;
    if (_brushPaintingSession) {
      setState(() {
        _brushPaintingSession = false;
        _brushScrollLock = false;
      });
    }
    _brushPaintingSession = false;
    _pointerAnchorLocal = null;
    _pointerDownAt = null;
    _brushFillOn = null;
    _brushLastPair = null;
  }

  void _toggleCell(int taskIndex, int dayIndex) {
    ref
        .read(placeProcessScheduleProvider(_scheduleKey).notifier)
        .toggleCell(taskIndex, dayIndex);
  }

  @override
  void initState() {
    super.initState();
    _hHeader = ScrollController();
    _hBody = ScrollController();
    _vLeft = ScrollController();
    _vBody = ScrollController();
    _hHeader.addListener(_syncHFromHeader);
    _hBody.addListener(_syncHFromBody);
    _vLeft.addListener(_syncVFromLeft);
    _vBody.addListener(_syncVFromBody);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _lockLandscape();
      if (!mounted) return;
      if (_layout == ProcessScheduleLayout.overview) {
        _scheduleFitChartToViewport();
      }
    });
  }

  Future<void> _openAddProcessDialog() async {
    final schedule = ref.read(placeProcessScheduleProvider(_scheduleKey));
    final d = schedule.data;
    if (!schedule.isReady || d.dayCount == 0) return;
    final dates = _columnDates(d);
    final dateLabels = [
      for (var i = 0; i < dates.length; i++) scheduleDateHeaderLabel(dates[i]),
    ];

    final result = await showDialog<AddProcessDialogResult>(
      context: context,
      builder: (ctx) => AddProcessDialog(dateLabels: dateLabels),
    );

    if (result == null || !mounted) return;
    final last = d.dayCount - 1;
    final lo = result.startIdx.clamp(0, last);
    var hi = result.endIdx.clamp(0, last);
    if (hi < lo) hi = lo;

    ref
        .read(placeProcessScheduleProvider(_scheduleKey).notifier)
        .addProcess(result.name, lo, hi);
    if (_layout == ProcessScheduleLayout.overview) {
      _scheduleFitChartToViewport();
    }
  }

  Future<void> _openPlacePeriodEditor(BuildContext context) async {
    final schedule = ref.read(placeProcessScheduleProvider(_scheduleKey));
    final data = schedule.data;
    if (!schedule.isReady || data.dayCount < 1) return;

    final gridStart = ProcessScheduleEditor.dayAtGridIndex(data, 0);
    final gridEnd =
        ProcessScheduleEditor.dayAtGridIndex(data, data.dayCount - 1);

    final dates = placePeriodDatePool(gridStart, gridEnd);
    final dateLabels = [for (final d in dates) periodDropdownLabel(d)];
    final last = dates.length - 1;
    final initialSi = indexNearestDay(dates, gridStart).clamp(0, last).toInt();
    final initialEi =
        indexNearestDay(dates, gridEnd).clamp(initialSi, last).toInt();

    final savedStartEnd = savedPlacePeriodDates(widget.placeInfo);
    final savedStart = savedStartEnd.$1;
    final savedEnd = savedStartEnd.$2;
    final savedLine = savedStart != null && savedEnd != null
        ? '${formatDateDotKo(savedStart)} ~ ${formatDateDotKo(savedEnd)}'
        : null;

    final picked = await showDialog<({DateTime start, DateTime end})?>(
      context: context,
      builder: (dialogCtx) => PlacePeriodDropdownDialog(
        dates: dates,
        dateLabels: dateLabels,
        initialStartIdx: initialSi,
        initialEndIdx: initialEi,
        savedLine: savedLine,
      ),
    );

    if (picked == null) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(placeProcessScheduleProvider(_scheduleKey).notifier)
          .applyPlaceWorkPeriodAndSyncPlaceMaster(
            widget.placeInfo,
            picked.start,
            picked.end,
          );
      if (!mounted) return;
      await FetchData.fetchAllData();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('현장 공사 기간이 저장되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('현장 기간 저장에 실패했습니다: $e')),
      );
      return;
    }

    if (_layout == ProcessScheduleLayout.overview) {
      _scheduleFitChartToViewport();
    } else {
      _jumpScrollsToOrigin();
    }
  }

  void _fitChartToViewport(ProcessScheduleData d, Size viewport) {
    final cw = chartContentW(context, d);
    final ch = chartContentH(context, d);
    if (viewport.width <= 0 || viewport.height <= 0 || cw <= 0 || ch <= 0) {
      return;
    }
    final s = math.min(viewport.width / cw, viewport.height / ch);
    final clamped = s.clamp(ProcessScheduleChartDim.viewerMinScale, 1.0);
    final scaledW = cw * clamped;
    final scaledH = ch * clamped;
    final dx = (viewport.width - scaledW) / 2;
    final dy = (viewport.height - scaledH) / 2;
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(clamped, clamped, 1, 1);
  }

  void _scheduleFitChartToViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final schedule = ref.read(placeProcessScheduleProvider(_scheduleKey));
      final box =
          _interactiveKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      _fitChartToViewport(schedule.data, box.size);
    });
  }

  Future<void> _unlockPortraitOnly() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _lockLandscape() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitToPortraitThenPop() async {
    if (_exiting) return;
    _exiting = true;
    try {
      final canEdit = ref.read(authSessionProvider).maybeWhen(
            data: (u) => u?.role.canEditProcessSchedule ?? false,
            orElse: () => false,
          );

      if (canEdit) {
        final notifier =
            ref.read(placeProcessScheduleProvider(_scheduleKey).notifier);
        try {
          await notifier.persist(syncPlaceMaster: widget.placeInfo);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  PlaceProcessScheduleNotifier.messageForPersistError(e),
                ),
              ),
            );
          }
          return;
        }
      }
      await _unlockPortraitOnly();
      if (!mounted) return;
      context.pop();
    } finally {
      _exiting = false;
    }
  }

  void _syncHFromHeader() {
    if (!mounted || _gateH) return;
    if (!_hHeader.hasClients || !_hBody.hasClients) return;
    final o = _hHeader.offset;
    if ((_hBody.offset - o).abs() < 0.5) return;
    _gateH = true;
    _hBody.jumpTo(o);
    _gateH = false;
  }

  void _syncHFromBody() {
    if (!mounted || _gateH) return;
    if (!_hHeader.hasClients || !_hBody.hasClients) return;
    final o = _hBody.offset;
    if ((_hHeader.offset - o).abs() < 0.5) return;
    _gateH = true;
    _hHeader.jumpTo(o);
    _gateH = false;
  }

  void _syncVFromLeft() {
    if (!mounted || _gateV) return;
    if (!_vLeft.hasClients || !_vBody.hasClients) return;
    final o = _vLeft.offset;
    if ((_vBody.offset - o).abs() < 0.5) return;
    _gateV = true;
    _vBody.jumpTo(o);
    _gateV = false;
  }

  void _syncVFromBody() {
    if (!mounted || _gateV) return;
    if (!_vLeft.hasClients || !_vBody.hasClients) return;
    final o = _vBody.offset;
    if ((_vLeft.offset - o).abs() < 0.5) return;
    _gateV = true;
    _vLeft.jumpTo(o);
    _gateV = false;
  }

  void _jumpScrollsToOrigin() {
    void j(ScrollController c) {
      if (c.hasClients) c.jumpTo(0);
    }

    j(_hHeader);
    j(_hBody);
    j(_vLeft);
    j(_vBody);
  }

  @override
  void dispose() {
    _hHeader.removeListener(_syncHFromHeader);
    _hBody.removeListener(_syncHFromBody);
    _vLeft.removeListener(_syncVFromLeft);
    _vBody.removeListener(_syncVFromBody);
    _hHeader.dispose();
    _hBody.dispose();
    _vLeft.dispose();
    _vBody.dispose();
    _transform.dispose();
    _cancelLongPressBrushTimer();
    unawaited(_unlockPortraitOnly());
    super.dispose();
  }

  EdgeInsets _obstructionInsets(BuildContext context) {
    final mq = MediaQuery.of(context);
    double mx(double a, double b) => a > b ? a : b;
    return EdgeInsets.fromLTRB(
      mx(mq.padding.left, mq.viewPadding.left),
      mx(mq.padding.top, mq.viewPadding.top),
      mx(mq.padding.right, mq.viewPadding.right),
      mx(mq.padding.bottom, mq.viewPadding.bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final viewSize = MediaQuery.sizeOf(context);
    final compactAppBar =
        viewSize.height < 720 || viewSize.shortestSide < 400;
    final readOnly = ref.watch(authSessionProvider).maybeWhen(
          data: (u) => u != null && !u.role.canEditProcessSchedule,
          orElse: () => false,
        );
    final canWorkforceFromHeader = ref.watch(authSessionProvider).maybeWhen(
          data: (u) => u != null && u.isManagementRole,
          orElse: () => false,
        );
    final schedule = ref.watch(placeProcessScheduleProvider(_scheduleKey));
    final d = schedule.data;
    final dates = _columnDates(d);
    final labelCentersByRow = [
      for (final t in d.tasks) ProcessScheduleEditor.labelCenterDayIndices(t),
    ];

    return BackButtonListener(
      onBackButtonPressed: () async {
        await _exitToPortraitThenPop();
        return true;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          unawaited(_exitToPortraitThenPop());
        },
        child: Padding(
        padding: _obstructionInsets(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.surface,
                Color.lerp(cs.surface, cs.surfaceContainerLow, 0.35)!,
              ],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              toolbarHeight: compactAppBar ? 56 : kToolbarHeight,
              titleSpacing: compactAppBar ? 10 : 16,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                style: compactAppBar
                    ? IconButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    : null,
                onPressed: () => unawaited(_exitToPortraitThenPop()),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.placeInfo.pname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (compactAppBar ? tt.titleSmall : tt.titleMedium)
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: compactAppBar ? 1.15 : null,
                    ),
                  ),
                  Text(
                    schedule.isReady && d.dayCount > 0
                        ? compactGridPeriodLine(d)
                        : '공정표',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (compactAppBar ? tt.labelMedium : tt.labelLarge)
                        ?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: compactAppBar ? 1.1 : null,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: '공유',
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: schedule.isReady && d.dayCount > 0
                      ? () => unawaited(
                            showProcessScheduleShareSheet(
                              context: context,
                              cs: cs,
                              data: d,
                              placeName: widget.placeInfo.pname,
                            ),
                          )
                      : null,
                ),
                if (_layout == ProcessScheduleLayout.overview)
                  IconButton(
                    tooltip: '화면에 맞춤',
                    icon: const Icon(Icons.fit_screen_rounded),
                    onPressed: _scheduleFitChartToViewport,
                  ),
                if (!readOnly)
                  Padding(
                    padding: EdgeInsets.only(
                      right: context.rs(compactAppBar ? 6 : 10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.72),
                          shape: const StadiumBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: schedule.isReady
                                ? () =>
                                    unawaited(_openPlacePeriodEditor(context))
                                : null,
                            child: Padding(
                              padding: ResponsiveLayout.symmetric(
                                context,
                                horizontal: compactAppBar ? 10 : 12,
                                vertical: compactAppBar ? 5 : 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_calendar_rounded,
                                    size: context.rsi(compactAppBar ? 17 : 18),
                                    color: schedule.isReady
                                        ? cs.primary
                                        : cs.onSurfaceVariant
                                            .withValues(alpha: 0.45),
                                  ),
                                  rsH(context, compactAppBar ? 4 : 6),
                                  Text(
                                    schedule.isReady && d.dayCount > 0
                                        ? '기간 수정'
                                        : '공사 기간',
                                    style: (compactAppBar
                                            ? tt.labelMedium
                                            : tt.labelLarge)
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                      color: schedule.isReady
                                          ? cs.onSurface
                                          : cs.onSurfaceVariant
                                              .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        rsH(context, compactAppBar ? 6 : 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: ResponsiveLayout.symmetric(
                              context,
                              horizontal: compactAppBar ? 10 : 12,
                              vertical: compactAppBar ? 5 : 8,
                            ),
                            visualDensity: compactAppBar
                                ? VisualDensity.compact
                                : VisualDensity.standard,
                            minimumSize: compactAppBar
                                ? Size(context.rs(40), context.rs(34))
                                : null,
                            tapTargetSize: compactAppBar
                                ? MaterialTapTargetSize.shrinkWrap
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(context.rs(18)),
                            ),
                            elevation: 0,
                          ),
                          onPressed:
                              schedule.isReady ? _openAddProcessDialog : null,
                          icon: Icon(
                            Icons.add_rounded,
                            size: context.rsi(compactAppBar ? 18 : 19),
                          ),
                          label: Text(
                            '공정 추가',
                            style: (compactAppBar
                                    ? tt.labelMedium
                                    : tt.titleSmall)
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            body: !schedule.isReady
                ? Skeletonizer(
                    enabled: true,
                    child: Padding(
                      padding: ResponsiveLayout.all(context, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: context.rs(46),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(context.rs(12)),
                            ),
                            child: Text(
                              '보기 모드',
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          rsV(context, 12),
                          Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(context.rs(16)),
                              ),
                              child: Text(
                                '공정표',
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (schedule.loadError != null)
                        Padding(
                          padding: ResponsiveLayout.only(
                            context,
                            left: 16,
                            top: 4,
                            right: 16,
                          ),
                          child: Material(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(context.rs(12)),
                            child: Padding(
                              padding: ResponsiveLayout.symmetric(
                                context,
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: cs.onErrorContainer,
                                    size: context.rsi(22),
                                  ),
                                  rsH(context, 8),
                                  Expanded(
                                    child: Text(
                                      schedule.loadError!,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onErrorContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '닫기',
                                    onPressed: () {
                                      ref
                                          .read(
                                            placeProcessScheduleProvider(
                                              _scheduleKey,
                                            ).notifier,
                                          )
                                          .clearLoadError();
                                    },
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: cs.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: ResponsiveLayout.only(
                          context,
                          left: 16,
                          top: 4,
                          right: 16,
                          bottom: 8,
                        ),
                        child: ProcessScheduleLayoutSegment(
                          layout: _layout,
                          radius: ProcessScheduleChartDim.segmentRadius(context),
                          onChanged: (v) {
                            setState(() => _layout = v);
                            if (v == ProcessScheduleLayout.overview) {
                              _scheduleFitChartToViewport();
                            } else {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _jumpScrollsToOrigin();
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: ResponsiveLayout.only(
                            context,
                            left: 12,
                            right: 12,
                            bottom: 12,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(context.rs(16)),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.shadow.withValues(alpha: 0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: cs.outlineVariant.withValues(alpha: 0.4),
                              ),
                              color: cs.surfaceContainerLowest.withValues(
                                alpha: 0.92,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(context.rs(15)),
                              child: _layout ==
                                      ProcessScheduleLayout.stickyHeaders
                                  ? ProcessScheduleStickyScrollChart(
                                      cs: cs,
                                      data: d,
                                      dates: dates,
                                      labelCentersByRow: labelCentersByRow,
                                      hHeader: _hHeader,
                                      hBody: _hBody,
                                      vLeft: _vLeft,
                                      vBody: _vBody,
                                      brushScrollLock: _brushScrollLock,
                                      readOnly: readOnly,
                                      onStickyPointerDown: (e) =>
                                          _onStickyChartPointerDown(e),
                                      onStickyPointerMove: (e) =>
                                          _onStickyChartPointerMove(e, d),
                                      onStickyPointerUp: (e) =>
                                          _onStickyChartPointerUp(e, d),
                                      onStickyPointerCancel:
                                          _onStickyChartPointerCancel,
                                      onDateHeaderTap: canWorkforceFromHeader
                                          ? _openWorkforceForDay
                                          : null,
                                    )
                                  : LayoutBuilder(
                                      builder: (ctx, bc) {
                                        return InteractiveViewer(
                                          key: _interactiveKey,
                                          transformationController: _transform,
                                          minScale: ProcessScheduleChartDim
                                              .viewerMinScale,
                                          maxScale: ProcessScheduleChartDim
                                              .viewerMaxScale,
                                          constrained: false,
                                          boundaryMargin:
                                              EdgeInsets.all(context.rs(320)),
                                          clipBehavior: Clip.hardEdge,
                                          child: ProcessScheduleOverviewChart(
                                            cs: cs,
                                            data: d,
                                            dates: dates,
                                            labelCentersByRow:
                                                labelCentersByRow,
                                            onCellTap: readOnly
                                                ? (_, __) {}
                                                : _toggleCell,
                                            onDateHeaderTap:
                                                canWorkforceFromHeader
                                                    ? _openWorkforceForDay
                                                    : null,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ),
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
