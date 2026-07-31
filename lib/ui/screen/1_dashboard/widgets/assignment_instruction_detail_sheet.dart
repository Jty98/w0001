import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_capabilities.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/data/model/worker_dashboard_models.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/presentation/viewmodel/worker_supply_map_providers.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/schedule_memo_editor_shared.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_blocks_display.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/widget/map_route_action_buttons.dart';
import 'package:w0001/util/work_instruction_blocks_resolve.dart';
import 'package:w0001/util/worker_api_user_messages.dart';
import 'package:w0001/util/map_navigation_launcher.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 내 일정 배정 상세·현장 작업 내용 상세에서 동일하게 사용하는 리치 블록 해석.
List<WorkerAnnouncementBlock> assignmentInstructionRichBlocks(
  ScheduleMemoRead m,
) {
  return resolveAssignmentInstructionBlocks(
    instructionBlocks: m.instructionBlocks,
    memoFallback: m.memo,
  );
}

bool assignmentInstructionHasPlainMemo(String memo) {
  final t = memo.trim();
  if (t.isEmpty) return false;
  return !WorkerAnnouncementQuillCodec.isQuillEnvelopeText(t);
}

bool assignmentInstructionPlainMemoVisible({
  required bool isAssignment,
  required String memo,
  required List<WorkerAnnouncementBlock> rich,
}) {
  if (!assignmentInstructionHasPlainMemo(memo)) return false;
  if (isAssignment && rich.isNotEmpty) return false;
  return true;
}

/// 작업지시 바텀시트 안 Quill 읽기 영역 높이 — 화면 전체 비율 대신 시트에 맞춤.
double assignmentInstructionSheetQuillHeight(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  final top = MediaQuery.paddingOf(context).top;
  final bottom = MediaQuery.paddingOf(context).bottom;
  // 시트 헤더·동료 스트립·카드 등 대략 차지하는 높이.
  const headerReserve = 240.0;
  final avail = h - top - bottom - headerReserve;
  return avail.clamp(200.0, h * 0.45);
}

const _assignmentWeekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

String assignmentInstructionDateLabel(DateTime day) {
  final weekday = _assignmentWeekdayKo[day.weekday - 1];
  return '${day.year}년 ${day.month}월 ${day.day}일 ($weekday)';
}

String assignmentInstructionDateLabelFromIso(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  final iso = t.length >= 10 ? t.substring(0, 10) : t;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return t;
  return assignmentInstructionDateLabel(
    DateTime(dt.year, dt.month, dt.day),
  );
}

/// 현장 투입·내 일정 배정 바텀시트 공통 상단 — 현장명 · 역할 · 날짜.
class AssignmentInstructionSheetHeader extends ConsumerWidget {
  const AssignmentInstructionSheetHeader({
    super.key,
    required this.placeName,
    required this.dateLabel,
    this.workrole = '',
    this.placeAddress = '',
  });

  final String placeName;
  final String dateLabel;
  final String workrole;
  final String placeAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final pname = placeName.trim().isEmpty ? '현장' : placeName.trim();
    final role = workrole.trim();
    final address = placeAddress.trim();
    final query = '$pname $address'.trim();

    return AppInsetCard(
      padding: ResponsiveLayout.symmetric(
        context,
        horizontal: 16,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.rs(44),
            height: context.rs(44),
            alignment: Alignment.center,
            decoration: AppSectionCardStyles.iconBadgeDecoration(context, cs),
            child: Icon(
              Icons.apartment_rounded,
              color: cs.primary,
              size: context.rsi(24),
            ),
          ),
          rsH(context, 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pname,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: cs.onSurface,
                  ),
                ),
                if (role.isNotEmpty) ...[
                  rsV(context, 4),
                  Text(
                    '공정 · $role',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (dateLabel.trim().isNotEmpty) ...[
                  rsV(context, 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: context.rsi(14),
                        color: cs.primary,
                      ),
                      rsH(context, 6),
                      Expanded(
                        child: Text(
                          dateLabel.trim(),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (address.isNotEmpty) ...[
                  rsV(context, 8),
                  Container(
                    padding: ResponsiveLayout.only(
                      context,
                      left: 10,
                      top: 8,
                      right: 10,
                      bottom: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: context.rsi(15),
                              color: cs.primary,
                            ),
                            rsH(context, 6),
                            Expanded(
                              child: Text(
                                address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                        rsV(context, 7),
                        MapRouteActionButtons(
                          compact: true,
                          onCopyAddress: () async {
                            await Clipboard.setData(
                              ClipboardData(text: address),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('현장 주소를 복사했습니다.'),
                              ),
                            );
                          },
                          onKakao: () async {
                            if (query.isEmpty) return;
                            final kakaoLocal =
                                ref.read(kakaoLocalMapApiProvider);
                            final resolved = await kakaoLocal.resolveBestMatch(
                              address: address,
                              keyword: pname,
                            );
                            if (resolved != null) {
                              await MapNavigationLauncher.openKakaoNaviRoute(
                                destinationName: resolved.name.trim().isEmpty
                                    ? query
                                    : resolved.name,
                                latitude: resolved.latitude,
                                longitude: resolved.longitude,
                              );
                              return;
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('경로 좌표를 찾지 못해 카카오내비 안내를 시작할 수 없습니다.'),
                              ),
                            );
                          },
                          onTmap: () async {
                            if (query.isEmpty) return;
                            await MapNavigationLauncher.openTmapSearch(query);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget assignmentInstructionTaskLine(
  BuildContext context,
  String tasktimeRaw,
) {
  final t = tasktimeRaw.trim();
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final asClock = parseScheduleMemoTaskTime(t);
  final label = asClock != null ? '시각 $t' : t;
  return Text(
    label,
    style: (asClock != null ? tt.titleMedium : tt.bodySmall)?.copyWith(
      fontWeight: asClock != null ? FontWeight.w900 : FontWeight.w600,
      height: asClock != null ? 1.05 : 1.35,
      color: asClock != null ? cs.primary : cs.onSurface,
    ),
  );
}

/// 가로 스크롤 인원 칩 — 고정 너비·말줄임으로 영역 밖으로 튀어나오지 않음.
class AssignmentPeerHorizontalStrip extends StatelessWidget {
  const AssignmentPeerHorizontalStrip({
    super.key,
    required this.sectionTitle,
    required this.loading,
    this.errorLine,
    required this.entries,
  });

  final String sectionTitle;
  final bool loading;
  final String? errorLine;
  final List<AssignmentPeerChipData> entries;

  static double _rowHeight(BuildContext context) => context.rs(118);
  static double _chipWidth(BuildContext context) => context.rs(168);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rowHeight = _rowHeight(context);
    final chipWidth = _chipWidth(context);

    return AppInsetCard(
      padding: ResponsiveLayout.only(context,
          left: 14, top: 14, right: 14, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: context.rs(36),
                height: context.rs(36),
                alignment: Alignment.center,
                decoration:
                    AppSectionCardStyles.iconBadgeDecoration(context, cs),
                child: Icon(
                  Icons.groups_2_outlined,
                  size: context.rsi(18),
                  color: cs.primary,
                ),
              ),
              rsH(context, 10),
              Expanded(
                child: Text(
                  sectionTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (!loading)
                Container(
                  padding: ResponsiveLayout.symmetric(
                    context,
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.appIconBadge,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.appBorder),
                  ),
                  child: Text(
                    errorLine != null ? '!' : '${entries.length}명',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),
          rsV(context, 12),
          if (loading)
            SizedBox(
              height: rowHeight,
              child: Skeletonizer(
                enabled: true,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.hardEdge,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: 4,
                  separatorBuilder: (_, __) => rsH(context, 10),
                  itemBuilder: (ctx, i) {
                    return SizedBox(
                      width: chipWidth,
                      child: AppInsetTile(
                        padding: ResponsiveLayout.all(ctx, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '작업자',
                              style: tt.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            rsV(ctx, 6),
                            Text(
                              '역할 · 세부',
                              style: tt.bodySmall?.copyWith(height: 1.25),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          else if (errorLine != null)
            Text(
              errorLine!,
              style: tt.bodyMedium?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            )
          else if (entries.isEmpty)
            Text(
              '표시할 다른 인력이 없습니다.',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            )
          else
            SizedBox(
              height: rowHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.hardEdge,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: entries.length,
                separatorBuilder: (_, __) => rsH(context, 10),
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  return Tooltip(
                    message: e.tooltip,
                    waitDuration: const Duration(milliseconds: 520),
                    child: SizedBox(
                      width: chipWidth,
                      child: AppInsetTile(
                        padding: ResponsiveLayout.all(ctx, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: context.rs(14),
                                  backgroundColor: cs.appIconBadge,
                                  child: Icon(
                                    Icons.person_outline,
                                    size: context.rsi(16),
                                    color: cs.primary,
                                  ),
                                ),
                                rsH(ctx, 8),
                                Expanded(
                                  child: Text(
                                    e.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            rsV(ctx, 8),
                            Text(
                              e.roleLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class AssignmentPeerChipData {
  const AssignmentPeerChipData({
    required this.name,
    required this.roleLine,
    required this.tooltip,
  });

  final String name;
  final String roleLine;
  final String tooltip;
}

/// 배정 · 현장 행 공통 — 작업 내용(상단 현장·역할·날짜는 [AssignmentInstructionSheetHeader]).
class AssignmentInstructionDetailCard extends StatelessWidget {
  const AssignmentInstructionDetailCard({
    super.key,
    required this.richBlocks,
    required this.memoPlain,
    required this.isAssignment,
    required this.tasktime,
    this.workrole,
    this.slotLabelAboveWork,
    this.quillViewportHeight,
    this.quillViewportHeightFactor,
  });

  final List<WorkerAnnouncementBlock> richBlocks;
  final String memoPlain;
  final bool isAssignment;
  final String tasktime;
  final String? workrole;

  /// 여러 카드 묶음일 때 등 (선택).
  final String? slotLabelAboveWork;

  /// 바텀시트 등 좁은 영역 — null이면 [WorkerAnnouncementBlocksDisplay] 기본(화면 비율).
  final double? quillViewportHeight;
  final double? quillViewportHeightFactor;

  factory AssignmentInstructionDetailCard.fromScheduleMemo(
    ScheduleMemoRead m, {
    double? quillViewportHeight,
    double? quillViewportHeightFactor,
  }) {
    return AssignmentInstructionDetailCard(
      richBlocks: assignmentInstructionRichBlocks(m),
      memoPlain: m.memo,
      isAssignment: m.isAssignment,
      tasktime: m.tasktime.trim(),
      workrole: m.isAssignment ? m.workrole.trim() : null,
      quillViewportHeight: quillViewportHeight,
      quillViewportHeightFactor: quillViewportHeightFactor,
    );
  }

  factory AssignmentInstructionDetailCard.fromPlaceWorkerRow({
    required List<WorkerAnnouncementBlock> instructionBlocks,
    String? workrole,
    String? slotLabelAboveWork,
    double? quillViewportHeight,
    double? quillViewportHeightFactor,
  }) {
    return AssignmentInstructionDetailCard(
      richBlocks: instructionBlocks,
      memoPlain: '',
      isAssignment: true,
      tasktime: '',
      workrole: workrole?.trim(),
      slotLabelAboveWork: slotLabelAboveWork,
      quillViewportHeight: quillViewportHeight,
      quillViewportHeightFactor: quillViewportHeightFactor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rich = richBlocks;
    final plainVisible = assignmentInstructionPlainMemoVisible(
      isAssignment: isAssignment,
      memo: memoPlain,
      rich: rich,
    );
    final richEmpty = workInstructionBlocksLookEmpty(rich);
    final role = workrole?.trim() ?? '';
    final roleLabel = role.isEmpty ? null : '공정 · $role';

    return AppSectionCard(
      icon: Icons.assignment_outlined,
      title: '작업 내용',
      subtitle: slotLabelAboveWork,
      denseHeader: true,
      contentPadding: ResponsiveLayout.only(context,
          left: 12, top: 8, right: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (role.isNotEmpty) ...[
            AppInsetTile(
              padding: ResponsiveLayout.only(context,
                  left: 12, top: 10, right: 12, bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.view_timeline_rounded,
                      color: cs.primary, size: context.rs(18)),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: Text(
                      roleLabel!,
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.rsi(10)),
          ] else ...[
            AppInsetTile(
              padding: ResponsiveLayout.only(context,
                  left: 12, top: 10, right: 12, bottom: 10),
              child: Text(
                '공정 정보가 등록되지 않았습니다.',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: context.rsi(10)),
          ],
          AppInsetTile(
            padding: ResponsiveLayout.only(context,
                left: 12, top: 10, right: 12, bottom: 10),
            child: richEmpty
                ? Text(
                    '등록된 작업 내용 본문이 없습니다.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : WorkerAnnouncementBlocksDisplay(
                    blocks: rich,
                    quillViewportHeight: quillViewportHeight,
                    quillViewportHeightFactor:
                        quillViewportHeightFactor ?? 0.52,
                  ),
          ),
          if (plainVisible) ...[
            const SizedBox(height: 12),
            Text(
              '메모',
              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SelectableText(memoPlain.trim(), style: tt.bodyLarge),
          ],
          if (tasktime.isNotEmpty) ...[
            const SizedBox(height: 12),
            assignmentInstructionTaskLine(context, tasktime),
          ],
        ],
      ),
    );
  }
}

bool _mightResolvePlacePidForMemo(ScheduleMemoRead m, UserRead me) {
  final p = m.placePid;
  if (p != null && p > 0) return true;
  if (me.role.canAccessDashboardPlacesInfo) {
    return m.title.trim().isNotEmpty;
  }
  return false;
}

Future<int?> _resolveScheduleMemoPlacePid(
  WidgetRef ref,
  ScheduleMemoRead m,
) async {
  final direct = m.placePid;
  if (direct != null && direct > 0) return direct;

  final me = ref.read(authSessionProvider).asData?.value;
  if (me == null || !me.role.canAccessDashboardPlacesInfo) return null;

  final t = m.title.trim();
  if (t.isEmpty) return null;

  try {
    final places = await ref.read(dashboardRemoteUseCaseProvider).placesInfo();
    for (final p in places) {
      final pid = p.pid;
      if (pid != null && pid > 0 && p.pname.trim() == t) {
        return pid;
      }
    }
  } catch (_) {}
  return null;
}

void showAssignmentInstructionDetailSheet(
  BuildContext context,
  ScheduleMemoRead memo,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetCtx) => _AssignmentScheduleMemoSheetBody(memo: memo),
  );
}

class _CoworkLoadResult {
  const _CoworkLoadResult({
    this.showBand = false,
    this.errorLine,
    this.peers = const [],
  });

  final bool showBand;
  final String? errorLine;
  final List<CoworkerOnSite> peers;
}

class _AssignmentScheduleMemoSheetBody extends ConsumerStatefulWidget {
  const _AssignmentScheduleMemoSheetBody({required this.memo});

  final ScheduleMemoRead memo;

  @override
  ConsumerState<_AssignmentScheduleMemoSheetBody> createState() =>
      _AssignmentScheduleMemoSheetBodyState();
}

class _AssignmentScheduleMemoSheetBodyState
    extends ConsumerState<_AssignmentScheduleMemoSheetBody> {
  late final Future<_CoworkLoadResult> _coworkFuture;

  @override
  void initState() {
    super.initState();
    _coworkFuture = _loadCoworkers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(placeListProvider.notifier).initialize();
    });
  }

  Future<_CoworkLoadResult> _loadCoworkers() async {
    final me = ref.read(authSessionProvider).asData?.value;
    if (me == null || !me.isWorker) {
      return const _CoworkLoadResult();
    }
    if (!_mightResolvePlacePidForMemo(widget.memo, me)) {
      return const _CoworkLoadResult();
    }
    final pid = await _resolveScheduleMemoPlacePid(ref, widget.memo);
    if (pid == null || pid <= 0) {
      return const _CoworkLoadResult();
    }
    final raw = widget.memo.taskdate.trim();
    final day = raw.length >= 10 ? raw.substring(0, 10) : raw;
    try {
      final api = ref.read(workerDashboardRemoteApiProvider);
      final list = await api.fetchCoworkers(pid, day);
      final others = excludeSelfFromCoworkers(
        list,
        workerHid: me.workerHid,
        viewerUname: me.uname,
      );
      return _CoworkLoadResult(showBand: true, peers: others);
    } on HttpClientException catch (e) {
      return _CoworkLoadResult(
        showBand: true,
        errorLine: workerDashboardFriendlyMessageKo(e) ?? '동료 목록을 불러오지 못했습니다.',
      );
    } catch (_) {
      return const _CoworkLoadResult(
        showBand: true,
        errorLine: '동료 목록을 불러오지 못했습니다.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final me = ref.watch(authSessionProvider).asData?.value;
    final placesState = ref.watch(placeListProvider);
    final byPid = <int, PlaceInfoModel>{
      for (final p in placesState.placeList)
        if ((p.pid ?? 0) > 0) p.pid!: p,
    };
    final memoPid = widget.memo.placePid;
    PlaceInfoModel? resolvedPlace;
    if (memoPid != null && memoPid > 0) {
      resolvedPlace = byPid[memoPid];
    } else {
      final targetName = widget.memo.title.trim();
      if (targetName.isNotEmpty) {
        for (final p in placesState.placeList) {
          if (p.pname.trim() == targetName) {
            resolvedPlace = p;
            break;
          }
        }
      }
    }
    final resolvedAddress = resolvedPlace?.paddress.trim() ?? '';

    return FutureBuilder<_CoworkLoadResult>(
      future: _coworkFuture,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final res = snap.data;
        final err = res?.errorLine;
        final peers = res?.peers ?? const <CoworkerOnSite>[];
        final showStrip =
            me?.isWorker == true && (loading || (res?.showBand ?? false));

        Widget? coworkerBand;
        if (showStrip) {
          coworkerBand = AssignmentPeerHorizontalStrip(
            sectionTitle: '같은 날 투입 동료',
            loading: loading && res == null,
            errorLine: err,
            entries: [
              for (final c in peers)
                AssignmentPeerChipData(
                  name: c.workerName.trim().isEmpty
                      ? '이름 없음'
                      : c.workerName.trim(),
                  roleLine:
                      c.workrole.trim().isEmpty ? '역할 미지정' : c.workrole.trim(),
                  tooltip: '인력 번호 ${c.hid}',
                ),
            ],
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.rsi(20),
            context.rsi(4),
            context.rsi(20),
            context.rsi(20) + bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AssignmentInstructionSheetHeader(
                placeName: widget.memo.title.trim().isEmpty
                    ? '현장 배정'
                    : widget.memo.title.trim(),
                workrole: widget.memo.isAssignment ? widget.memo.workrole : '',
                dateLabel:
                    assignmentInstructionDateLabelFromIso(widget.memo.taskdate),
                placeAddress: resolvedAddress,
              ),
              rsV(context, 16),
              if (coworkerBand != null) ...[
                coworkerBand,
                rsV(context, 16),
              ],
              AssignmentInstructionDetailCard.fromScheduleMemo(
                widget.memo,
                quillViewportHeight:
                    assignmentInstructionSheetQuillHeight(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
