import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:kpostal/kpostal.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/widget/add_text_field.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/domain/place_list_display.dart';
import 'package:w0001/domain/place_work_period_display.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_elevation.dart';
import 'package:w0001/theme/app_section_card.dart';

/// DB 문자열 → 캘린더 초기 구간 (파싱 실패 시 null).
(DateTime?, DateTime?) _parsedPlaceRange(PlaceInfoModel element) {
  try {
    if (element.pstart.isEmpty) return (null, null);
    final s = DateTime.parse(element.pstart);
    final dStart = DateTime(s.year, s.month, s.day);
    if (element.pend == '0' || element.pend.isEmpty) {
      return (dStart, dStart);
    }
    final p = DateTime.parse(element.pend);
    final dEnd = DateTime(p.year, p.month, p.day);
    return (dStart, dEnd);
  } catch (_) {
    return (null, null);
  }
}

String _formatYmdKorean(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

String _formatPendLineForDialog(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) {
    return iso.isEmpty ? '—' : iso;
  }
  return _formatYmdKorean(DateTime(d.year, d.month, d.day));
}

/// 완료 슬라이드 시 저장할 `pend`(ISO). 취소면 null.
Future<String?> _showCompletePendChoiceDialog(
  BuildContext context,
  PlaceInfoModel element,
) async {
  final existingIso = pendWhenTogglingToComplete(element);
  final now = DateTime.now();
  final todayIso = now.toIso8601String();

  DateTime firstSelectableDay() {
    try {
      if (element.pstart.trim().isEmpty) return DateTime(2000);
      final s = DateTime.parse(element.pstart);
      return DateTime(s.year, s.month, s.day);
    } catch (_) {
      return DateTime(2000);
    }
  }

  Future<void> pickCustomEnd(BuildContext ctx) async {
    final lo = firstSelectableDay();
    final anchor = DateTime.tryParse(existingIso) ??
        DateTime(now.year, now.month, now.day);
    final initialDay =
        DateTime(anchor.year, anchor.month, anchor.day).isBefore(lo)
            ? lo
            : DateTime(anchor.year, anchor.month, anchor.day);

    final picked = await showDialog<DateTime?>(
      context: ctx,
      builder: (_) => _PickCompletionEndDialog(
        firstSelectableDay: lo,
        initialSelectedDay: initialDay,
      ),
    );
    if (picked != null && ctx.mounted) {
      Navigator.of(ctx).pop(
        DateTime(picked.year, picked.month, picked.day).toIso8601String(),
      );
    }
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('완료 처리'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '공사 종료일을 선택합니다. 완료 후에도 진행중으로 바꿀 때 종료일 값은 유지됩니다.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => Navigator.of(ctx).pop(existingIso),
                child: Padding(
                  padding: ResponsiveLayout.symmetric(ctx, vertical: 8),
                  child: Text(
                    '기존 종료일로 저장\n(${_formatPendLineForDialog(existingIso)})',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              rsV(ctx, 8),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(todayIso),
                child: Padding(
                  padding: ResponsiveLayout.symmetric(ctx, vertical: 8),
                  child: Text(
                    '오늘 종료로 저장\n(${_formatYmdKorean(DateTime(now.year, now.month, now.day))})',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              rsV(ctx, 8),
              OutlinedButton(
                onPressed: () => pickCustomEnd(ctx),
                child: Padding(
                  padding: ResponsiveLayout.symmetric(ctx, vertical: 10),
                  child: Text(
                    '직접 선택…',
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
        ],
      );
    },
  );
}

/// 완료 처리에서 「직접 선택」 시 사용 — 앱 공통 [ScrollableCalendarWidget] 단일일 선택.
class _PickCompletionEndDialog extends StatefulWidget {
  const _PickCompletionEndDialog({
    required this.firstSelectableDay,
    required this.initialSelectedDay,
  });

  final DateTime firstSelectableDay;
  final DateTime initialSelectedDay;

  @override
  State<_PickCompletionEndDialog> createState() =>
      _PickCompletionEndDialogState();
}

class _PickCompletionEndDialogState extends State<_PickCompletionEndDialog> {
  late DateTime _pickedDay;
  bool _readyForUserInput = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initialSelectedDay;
    _pickedDay = DateTime(i.year, i.month, i.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _readyForUserInput = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final calHeight = (screenH * 0.34).clamp(240.0, 310.0).toDouble();
    final lo = widget.firstSelectableDay;
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rs(16)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.rs(440)),
        child: Padding(
          padding: ResponsiveLayout.only(context,
              left: 10, top: 14, right: 10, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '종료일 선택',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              rsV(context, 10),
              SizedBox(
                height: calHeight,
                width: double.infinity,
                child: ScrollableCalendarWidget(
                  height: calHeight,
                  initialRangeStart: lo,
                  initialRangeEnd: lo,
                  initialSelectedDay: _pickedDay,
                  useSingleDaySelection: true,
                  showViewModeToggle: false,
                  showRangeSummarySection: false,
                  disableDateSelectionHighlight: true,
                  onDayPicked: (d) {
                    if (!_readyForUserInput) return;
                    setState(() {
                      _pickedDay = DateTime(d.year, d.month, d.day);
                    });
                  },
                ),
              ),
              rsV(context, 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop<DateTime?>(null),
                    child: Text(
                      '취소',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop<DateTime>(_pickedDay),
                    child: Text(
                      '확인',
                      style: TextStyle(color: cs.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceScreen extends ConsumerWidget {
  const PlaceScreen({super.key});

  static const String _addressSeparator = ' ';

  (String, String) _splitAddress(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return ('', '');
    if (t.contains(_addressSeparator)) {
      final parts = t.split(_addressSeparator);
      final main = parts.isNotEmpty ? parts.first.trim() : '';
      final detail = parts.length > 1
          ? parts.sublist(1).join(_addressSeparator).trim()
          : '';
      return (main, detail);
    }
    return (t, '');
  }

  String _joinAddress(String main, String detail) {
    final m = main.trim();
    final d = detail.trim();
    if (m.isEmpty && d.isEmpty) return '';
    if (d.isEmpty) return m;
    if (m.isEmpty) return d;
    return '$m$_addressSeparator$d';
  }

  Future<void> _openAddressSearch(
    BuildContext context,
    TextEditingController addressController,
  ) async {
    Kpostal? result;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => KpostalView(
          callback: (Kpostal value) {
            result = value;
          },
        ),
      ),
    );
    final selected = result;
    if (selected == null) return;
    final road = selected.address.trim();
    final jibun = selected.jibunAddress.trim();
    final picked = road.isNotEmpty ? road : jibun;
    if (picked.isNotEmpty) {
      addressController.text = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placeListProvider);
    final viewModel = ref.read(placeListProvider.notifier);
    final canManagePlaces =
        ref.watch(authSessionProvider).asData?.value?.isManagementRole ?? false;
    final isInitialSkeleton = !state.hasLoadedOnce ||
        (state.isLoading &&
            state.placeList.isEmpty &&
            state.filteredPlaceList.isEmpty);

    return _PlaceListBootstrap(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: _PlaceListChrome.pageBackground(
            Theme.of(context).colorScheme,
          ),
          appBar: AppBar(
            title: const Text('현장 관리'),
            actions: [
              if (canManagePlaces)
                _buildAppBarIconButton(context, ref, viewModel),
            ],
          ),
          body: Padding(
            padding: ResponsiveLayout.symmetric(context, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildSegmentButton(context, state, viewModel),
                _PlaceListSearchSortBar(state: state, viewModel: viewModel),
                Expanded(
                  child: AppRefreshIndicator(
                    enabled: !isInitialSkeleton,
                    onRefresh: viewModel.fetchAllPlace,
                    child: _buildListView(
                      context,
                      ref,
                      state,
                      viewModel,
                      canManagePlaces: canManagePlaces,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    WidgetRef ref,
    PlaceListState state,
    PlaceListViewModel viewModel, {
    required bool canManagePlaces,
  }) {
    if (state.loadError != null &&
        state.placeList.isEmpty &&
        !state.isLoading) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(context.rs(24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.loadError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    rsV(context, 16),
                    FilledButton.icon(
                      onPressed: () => viewModel.fetchAllPlace(force: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 불러오기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!state.hasLoadedOnce ||
        (state.isLoading &&
            state.placeList.isEmpty &&
            state.filteredPlaceList.isEmpty)) {
      // 테마 변경 시 스켈레톤도 재생성
      final brightness = Theme.of(context).brightness;

      return Skeletonizer(
        enabled: true,
        child: ListView.builder(
          key: ValueKey('place_skeleton_$brightness'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: context.rs(8),
            bottom: context.rs(24),
          ),
          itemCount: 8,
          itemBuilder: (ctx, i) => Padding(
            padding: EdgeInsets.only(bottom: context.rs(10)),
            child: DecoratedBox(
              decoration: AppSectionCardStyles.cardDecoration(ctx),
              child: ClipRRect(
                borderRadius: AppSectionCardStyles.borderRadius(ctx),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text('현장 이름 ${i + 1}'),
                    subtitle: Text(
                      '주소 · 공사 기간',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (state.filteredPlaceList.isEmpty) {
      final searching = state.searchQuery.trim().isNotEmpty;
      final msg = searching
          ? '검색 결과가 없습니다.'
          : (state.placeState == PlaceState.incomplete
              ? '진행중인 현장이 없습니다.'
              : '완료된 현장이 없습니다.');
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                msg,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    // 테마 변경 시 리스트를 재생성하기 위해 brightness를 key로 사용
    return _PlaceInfiniteListView(
      viewModel: viewModel,
      canManagePlaces: canManagePlaces,
      buildTile: (ctx, index) {
        final list = ref.read(placeListProvider).filteredPlaceList;
        return _buildPlaceListTile(
          context: ctx,
          ref: ref,
          element: list[index],
          index: index,
          viewModel: viewModel,
          canManagePlaces: canManagePlaces,
        );
      },
    );
  }

  Padding _buildSegmentButton(
    BuildContext context,
    PlaceListState state,
    PlaceListViewModel viewModel,
  ) {
    return Padding(
      padding: ResponsiveLayout.symmetric(context, vertical: 10),
      child: CupertinoSlidingSegmentedControl<PlaceState>(
        groupValue: state.placeState,
        children: const {
          PlaceState.incomplete: Text('진행중'),
          PlaceState.complete: Text('완료'),
        },
        onValueChanged: viewModel.stateValueChanged,
      ),
    );
  }

  Widget _buildAppBarIconButton(
    BuildContext context,
    WidgetRef ref,
    PlaceListViewModel viewModel,
  ) {
    return IconButton(
      tooltip: '현장 추가',
      onPressed: () {
        viewModel.setPlaceDialogDateRange(null, null);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          unawaited(_showAddPlaceDialog(context, ref, viewModel));
        });
      },
      icon: const Icon(Icons.add),
    );
  }

  Future<void> _showAddPlaceDialog(
    BuildContext context,
    WidgetRef ref,
    PlaceListViewModel viewModel,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _placeDialog(
        isAdd: true,
        initialCalendarStart: null,
        initialCalendarEnd: null,
        onConfirm: (_, __) async {
          await viewModel.insertPlace();
          final cur = ref.read(placeListProvider);
          if (cur.updateText.isEmpty) {
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            viewModel.resetTextController();
          }
        },
        nameController: viewModel.placeNameController,
        revenueController: viewModel.placeRevenueController,
        contractTotalController: viewModel.placeContractTotalController,
        addressController: viewModel.placeAddressController,
        onPlaceDateRangeChanged: viewModel.setPlaceDialogDateRange,
      ),
    );
    if (!context.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      viewModel.resetTextController();
    });
  }

  Dialog _placeDialog({
    required bool isAdd,
    required TextEditingController nameController,
    required TextEditingController revenueController,
    required TextEditingController contractTotalController,
    required TextEditingController addressController,
    required Future<void> Function(DateTime? rangeStart, DateTime? rangeEnd)
        onConfirm,
    DateTime? initialCalendarStart,
    DateTime? initialCalendarEnd,
    void Function(DateTime? start, DateTime? end)? onPlaceDateRangeChanged,
  }) {
    return Dialog(
      child: Builder(
        builder: (context) {
          final screenH = MediaQuery.sizeOf(context).height;
          final maxHeight = (screenH * 0.82).clamp(560.0, 760.0).toDouble();
          final calendarHeight =
              (screenH * 0.34).clamp(250.0, 320.0).toDouble();
          DateTime? rangeStart = initialCalendarStart;
          DateTime? rangeEnd = initialCalendarEnd ?? initialCalendarStart;
          final (initialMainAddress, initialDetailAddress) =
              _splitAddress(addressController.text);
          final mainAddressController =
              TextEditingController(text: initialMainAddress);
          final detailAddressController =
              TextEditingController(text: initialDetailAddress);
          var showAddressSection =
              initialMainAddress.isNotEmpty || initialDetailAddress.isNotEmpty;
          var isSaving = false;

          return Consumer(
            builder: (context, consumerRef, _) {
              final vmState = consumerRef.watch(placeListProvider);
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  final cs = Theme.of(context).colorScheme;
                  final tt = Theme.of(context).textTheme;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(context.rs(16)),
                      ),
                      child: SingleChildScrollView(
                        padding: ResponsiveLayout.only(
                          context,
                          left: 14,
                          top: 12,
                          right: 14,
                          bottom: 12,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                isAdd ? '현장 추가' : '현장 수정',
                                style: tt.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            rsV(context, 12),
                            AddTextField(
                              tController: nameController,
                              labelText: '현장 이름 (필수)',
                              isPrice: false,
                              readOnly: false,
                              witdh: double.infinity,
                            ),
                            AddTextField(
                              tController: contractTotalController,
                              labelText: '공사금액',
                              isPrice: true,
                              keyboardType: TextInputType.number,
                              readOnly: false,
                              witdh: double.infinity,
                            ),
                            AddTextField(
                              tController: revenueController,
                              labelText: '선수금',
                              isPrice: true,
                              keyboardType: TextInputType.number,
                              readOnly: false,
                              witdh: double.infinity,
                            ),
                            rsV(context, 2),
                            InkWell(
                              borderRadius:
                                  BorderRadius.circular(context.rs(10)),
                              onTap: () => setDialogState(() =>
                                  showAddressSection = !showAddressSection),
                              child: Container(
                                width: double.infinity,
                                padding: ResponsiveLayout.symmetric(
                                  context,
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(context.rs(10)),
                                  color: cs.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        size: context.rsi(18),
                                        color: cs.primary),
                                    rsH(context, 8),
                                    Expanded(
                                      child: Text(
                                        '현장 주소 (선택입력)',
                                        style: tt.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      showAddressSection
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (showAddressSection) ...[
                              rsV(context, 8),
                              GestureDetector(
                                onTap: () => _openAddressSearch(
                                  context,
                                  mainAddressController,
                                ),
                                child: AbsorbPointer(
                                  child: AddTextField(
                                    tController: mainAddressController,
                                    labelText: '현장 주소 (선택입력)',
                                    isPrice: false,
                                    keyboardType: TextInputType.text,
                                    readOnly: true,
                                    witdh: double.infinity,
                                    minLines: 2,
                                    maxLines: 4,
                                  ),
                                ),
                              ),
                              AddTextField(
                                tController: detailAddressController,
                                labelText: '상세주소 (직접입력)',
                                isPrice: false,
                                keyboardType: TextInputType.text,
                                readOnly: false,
                                witdh: double.infinity,
                                minLines: 1,
                                maxLines: 3,
                              ),
                            ],
                            rsV(context, 6),
                            Container(
                              width: double.infinity,
                              padding: ResponsiveLayout.only(
                                context,
                                left: 10,
                                top: 8,
                                right: 10,
                                bottom: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(context.rs(12)),
                                color: cs.surfaceContainerLowest,
                                border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.6),
                                ),
                              ),
                              child: ScrollableCalendarWidget(
                                height: calendarHeight,
                                initialRangeStart: initialCalendarStart,
                                initialRangeEnd:
                                    initialCalendarEnd ?? initialCalendarStart,
                                showViewModeToggle: false,
                                showRangeSummarySection: false,
                                disableDateSelectionHighlight: true,
                                onRangeChanged: (s, e) {
                                  rangeStart = s;
                                  rangeEnd = e;
                                  onPlaceDateRangeChanged?.call(s, e);
                                  setDialogState(() {});
                                },
                              ),
                            ),
                            if (vmState.updateText.isNotEmpty)
                              Padding(
                                padding:
                                    ResponsiveLayout.only(context, top: 10),
                                child: Text(
                                  vmState.updateText,
                                  style:
                                      tt.bodySmall?.copyWith(color: cs.error),
                                ),
                              ),
                            rsV(context, 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isSaving
                                        ? null
                                        : () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: Size(
                                        double.infinity,
                                        context.rs(44),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            context.rs(10)),
                                      ),
                                    ),
                                    child: Text(
                                      '취소',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                rsH(context, 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: isSaving
                                        ? null
                                        : () async {
                                            if (isSaving) return;
                                            setDialogState(
                                                () => isSaving = true);
                                            try {
                                              addressController.text =
                                                  _joinAddress(
                                                mainAddressController.text,
                                                detailAddressController.text,
                                              );
                                              await onConfirm(
                                                  rangeStart, rangeEnd);
                                            } finally {
                                              if (context.mounted) {
                                                setDialogState(
                                                    () => isSaving = false);
                                              }
                                            }
                                          },
                                    style: FilledButton.styleFrom(
                                      minimumSize: Size(
                                        double.infinity,
                                        context.rs(44),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            context.rs(10)),
                                      ),
                                    ),
                                    child: isSaving
                                        ? SizedBox(
                                            height: context.rs(20),
                                            width: context.rs(20),
                                            child: const HammerLoadingIndicator(
                                                size: 20),
                                          )
                                        : const Text('저장'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceListTile({
    required BuildContext context,
    required WidgetRef ref,
    required PlaceInfoModel element,
    required int index,
    required PlaceListViewModel viewModel,
    required bool canManagePlaces,
  }) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w800,
        );
    final isComplete = element.pcomplete == 1;
    final accent = isComplete ? cs.tertiary : cs.primary;
    final pid = element.pid;
    final isPinned = pid != null && viewModel.isFavorite(pid);
    final periodLabels = buildPlaceListPeriodLabels(
      place: element,
      contractPendIso: viewModel.contractPendFor(element),
      contractOverWorkDayCount:
          canManagePlaces ? viewModel.contractOverWorkDaysFor(element) : null,
      includeAdditionalWork: canManagePlaces,
    );

    final cardRadius = AppSectionCardStyles.borderRadius(context);
    final listTile = InkWell(
      // nested route: /place/detail (분기 화면)
      onTap: () => context.push('/place/detail', extra: element),
      onLongPress: canManagePlaces
          ? () => showDialog<void>(
                context: context,
                builder: (sheetCtx) => pageViewDialog(
                  title: element.pname,
                  text: periodLabels.contractPeriodLine,
                  textStyle: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  children: [
                    _buildMainTable(sheetCtx, element),
                    _buildMaterialTable(sheetCtx, element),
                  ],
                ),
              )
          : null,
      child: DecoratedBox(
        decoration: isPinned
            ? AppElevation.sectionCard(
                context: context,
                backgroundColor: _PlaceListChrome.pinnedCardFill(cs),
                borderRadius: cardRadius,
                borderColor: cs.primary.withValues(alpha: 0.28),
                shadowIntensity: 0.9,
              )
            : AppSectionCardStyles.cardDecoration(context),
        child: ClipRRect(
          borderRadius: cardRadius,
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: ResponsiveLayout.only(
                context,
                left: 16,
                top: 12,
                right: 16,
                bottom: 12,
              ),
              title: Row(
                children: [
                  if (pid != null)
                    _PlaceFavoriteButton(
                      isPinned: isPinned,
                      onToggle: () => viewModel.toggleFavorite(pid),
                    ),
                  if (pid != null) rsH(context, 4),
                  Expanded(
                    child: Text(
                      element.pname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  rsH(context, 10),
                  if (periodLabels.ddayLabel != null) ...[
                    _PlaceDdayChip(label: periodLabels.ddayLabel!),
                    rsH(context, 6),
                  ],
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Padding(
                      padding: ResponsiveLayout.symmetric(
                        context,
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        isComplete ? '완료' : '진행중',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: accent,
                              height: 1.0,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: context.rs(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      periodLabels.contractPeriodLine,
                      style: subtitleStyle,
                    ),
                    if (canManagePlaces &&
                        periodLabels.additionalWorkLine != null) ...[
                      rsV(context, 4),
                      Text(
                        periodLabels.additionalWorkLine!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                    if (canManagePlaces) ...[
                      rsV(context, 10),
                      Builder(
                        builder: (context) {
                          final remainder = element.pcontractTotal -
                              element.wTotal -
                              element.mTotal;
                          final remainderColor = remainder < 0
                              ? Theme.of(context).colorScheme.error
                              : null;
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _PlaceMetric(
                                      label: '공사금액',
                                      value: getPrice(
                                        price: element.pcontractTotal,
                                      ),
                                      icon: Icons.request_quote_outlined,
                                    ),
                                  ),
                                  rsH(context, 10),
                                  Expanded(
                                    child: _PlaceMetric(
                                      label: '인건비',
                                      value: getPrice(price: element.wTotal),
                                      icon: Icons.engineering_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              rsV(context, 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _PlaceMetric(
                                      label: '자재비',
                                      value: getPrice(price: element.mTotal),
                                      icon: Icons.inventory_2_outlined,
                                    ),
                                  ),
                                  rsH(context, 10),
                                  Expanded(
                                    child: _PlaceMetric(
                                      label: '잔여',
                                      value: getPrice(price: remainder),
                                      icon: Icons.savings_outlined,
                                      valueColor: remainderColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!canManagePlaces) {
      return Padding(
        padding: EdgeInsets.only(bottom: context.rs(10)),
        child: listTile,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: context.rs(10)),
      child: Slidable(
        closeOnScroll: true,
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              borderRadius: BorderRadius.circular(10),
              backgroundColor: cs.tertiary,
              icon: element.pcomplete == 1
                  ? Icons.autorenew_outlined
                  : Icons.check_circle,
              label: element.pcomplete == 1 ? '진행중으로 변경' : '완료',
              onPressed: (slidableCtx) async {
                if (element.pcomplete == 1) {
                  await viewModel.updatePcomplete(index);
                } else {
                  final pend = await _showCompletePendChoiceDialog(
                    context,
                    element,
                  );
                  if (!context.mounted) return;
                  if (pend == null) return;
                  await viewModel.updatePcomplete(
                    index,
                    completionPend: pend,
                  );
                }
                if (!context.mounted) return;
                await FetchData.onDataChanged(DataChangeEvent.placeSaved);
                ref.read(addCostProvider.notifier).clearSelectedPlace();
              },
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              borderRadius: BorderRadius.circular(10),
              label: '수정',
              icon: Icons.edit,
              backgroundColor: cs.primary,
              onPressed: (context) {
                TextEditingController nameController =
                    TextEditingController(text: element.pname);
                TextEditingController revenueController = TextEditingController(
                    text: getPrice(
                        price: element.pfirstrevenue, isContainWon: false));
                TextEditingController contractTotalController =
                    TextEditingController(
                        text: getPrice(
                            price: element.pcontractTotal,
                            isContainWon: false));
                final (initStart, initEnd) = _parsedPlaceRange(element);
                TextEditingController addressController =
                    TextEditingController(text: element.paddress);
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogCtx) => _placeDialog(
                    isAdd: false,
                    nameController: nameController,
                    revenueController: revenueController,
                    contractTotalController: contractTotalController,
                    addressController: addressController,
                    initialCalendarStart: initStart,
                    initialCalendarEnd: initEnd,
                    onPlaceDateRangeChanged: null,
                    onConfirm: (rangeStart, rangeEnd) async {
                      final prevenue = int.tryParse(
                            revenueController.text
                                .trim()
                                .replaceAll(RegExp(r'[,원]'), ''),
                          ) ??
                          -1;
                      final pcontractTotal = int.tryParse(
                            contractTotalController.text
                                .trim()
                                .replaceAll(RegExp(r'[,원]'), ''),
                          ) ??
                          -1;
                      final ok = await viewModel.updatePlace(
                        element.pid!,
                        nameController.text,
                        addressController.text,
                        prevenue,
                        pcontractTotal,
                        rangeStart,
                        rangeEnd,
                        pcomplete: element.pcomplete,
                      );
                      if (ok && dialogCtx.mounted) {
                        Navigator.of(dialogCtx).pop();
                        await FetchData.onDataChanged(
                            DataChangeEvent.placeSaved);
                        ref.read(addCostProvider.notifier).clearSelectedPlace();
                      }
                    },
                  ),
                ).then((value) => viewModel.clearUpdateText());
              },
            ),
            SlidableAction(
              borderRadius: BorderRadius.circular(10),
              backgroundColor: cs.error,
              icon: Icons.delete,
              label: '삭제',
              onPressed: (slidableCtx) => showDialog<void>(
                context: slidableCtx,
                builder: (dialogCtx) => deleteDialog(
                  onPressed: () =>
                      viewModel.deletePlace(element.pid!).then((value) {
                    FetchData.onDataChanged(DataChangeEvent.placeSaved);
                    ref.read(addCostProvider.notifier).clearSelectedPlace();
                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                  }),
                ),
              ),
            ),
          ],
        ),
        child: listTile,
      ),
    );
  }

  Widget _buildMainTable(BuildContext context, PlaceInfoModel element) {
    final totalRevenue = element.pfirstrevenue + element.totalAdditionalRevenue;
    final totalCost = element.mTotal + element.wTotal;
    final balance = (element.pcontractTotal - totalRevenue) < 0
        ? 0
        : (element.pcontractTotal - totalRevenue);
    final profit = totalRevenue - totalCost;
    final margin = element.pcontractTotal <= 0
        ? null
        : (profit / element.pcontractTotal) * 100.0;

    final mainRows = <TableRowModel>[
      TableRowModel(label: '총 품수', value: '${element.workerCount}품'),
      TableRowModel(
          label: '공사 총액', value: getPrice(price: element.pcontractTotal)),
      TableRowModel(
          label: '총 수익',
          value: getPrice(
              price: element.pfirstrevenue + element.totalAdditionalRevenue)),
      TableRowModel(label: '잔금', value: getPrice(price: balance)),
      TableRowModel(
          label: '총 지출금액',
          value: getPrice(price: element.mTotal + element.wTotal)),
      TableRowModel(label: '순 이익', value: getPrice(price: profit)),
      TableRowModel(
        label: '이익률',
        value: margin == null ? '-' : '${margin.toStringAsFixed(1)}%',
      ),
      TableRowModel(label: '총 인건비', value: getPrice(price: element.wTotal)),
      TableRowModel(label: '총 자재비', value: getPrice(price: element.mTotal)),
      TableRowModel(
          label: '미지급 인건비', value: getPrice(price: element.wIncomplete)),
    ];

    return _buildSummarySection(
      context,
      sectionTitle: '현장 요약',
      rows: mainRows,
    );
  }

  Widget _buildMaterialTable(BuildContext context, PlaceInfoModel element) {
    final materialRows = categoryList.map((category) {
      final valueGetter = categoryMapping[category];
      if (valueGetter != null) {
        final value = valueGetter(element);
        return TableRowModel(
          label: category,
          value: getPrice(price: value),
        );
      }
      return TableRowModel(label: category, value: '');
    }).toList();

    return _buildSummarySection(
      context,
      sectionTitle: '자재비 상세',
      rows: materialRows,
    );
  }

  Widget _buildSummarySection(
    BuildContext context, {
    required String sectionTitle,
    required List<TableRowModel> rows,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final compact = ResponsiveLayout.isCompact(MediaQuery.sizeOf(context));
    final cellPadH = context.rsi(compact ? 6 : 8);
    final cellPadV = context.rsi(compact ? 4 : 6);
    final bodyStyle = tt.bodyMedium?.copyWith(
      fontSize: compact ? 13 : 14,
      height: 1.25,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(vertical: context.rsi(compact ? 6 : 10)),
          child: Text(
            sectionTitle,
            textAlign: TextAlign.center,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final tableW = constraints.maxWidth;
            final labelW =
                (tableW * 0.46).clamp(context.rs(88), context.rs(156));
            final valueW = math.max(tableW - labelW, context.rs(96));

            return Table(
              border: TableBorder.all(color: cs.outlineVariant),
              columnWidths: {
                0: FixedColumnWidth(labelW),
                1: FixedColumnWidth(valueW),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: rows.map((row) {
                final isUnpaid = row.label.contains('미지급');
                final isTotal = row.label.contains('합계');
                final rowStyle = bodyStyle?.copyWith(
                  color: isUnpaid ? cs.error : cs.onSurface,
                  fontWeight: isTotal ? FontWeight.bold : null,
                );
                if (row.label.isEmpty && row.value.isEmpty) {
                  return const TableRow(children: [
                    TableCell(child: SizedBox(height: 8)),
                    TableCell(child: SizedBox.shrink())
                  ]);
                }
                return TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: cellPadH,
                          vertical: cellPadV,
                        ),
                        child: Text(row.label, style: rowStyle),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: cellPadH,
                          vertical: cellPadV,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            row.value,
                            textAlign: TextAlign.right,
                            style: rowStyle,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class TableRowModel {
  final String label;
  final String value;
  final TextAlign align;

  TableRowModel({
    required this.label,
    required this.value,
    this.align = TextAlign.center,
  });
}

class _PlaceMetric extends StatelessWidget {
  const _PlaceMetric({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _PlaceListChrome.metricFill(cs),
        borderRadius: BorderRadius.circular(context.rs(12)),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: ResponsiveLayout.only(context,
            left: 10, top: 8, right: 10, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: context.rsi(14), color: cs.primary),
                  rsH(context, 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            rsV(context, 6),
            SizedBox(
              height: context.rs(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? cs.onSurface,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 계약 마감 D-day (진행중·마감 전만 표시).
class _PlaceDdayChip extends StatelessWidget {
  const _PlaceDdayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: ResponsiveLayout.symmetric(
          context,
          horizontal: 8,
          vertical: 5,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onErrorContainer,
                height: 1.0,
              ),
        ),
      ),
    );
  }
}

/// 현장 목록 즐겨찾기(상단 고정) 토글.
class _PlaceFavoriteButton extends StatelessWidget {
  const _PlaceFavoriteButton({
    required this.isPinned,
    required this.onToggle,
  });

  final bool isPinned;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = isPinned ? Icons.star_rounded : Icons.star_outline_rounded;
    final color = isPinned ? cs.primary : cs.onSurfaceVariant;

    return Material(
      color: isPinned
          ? cs.primary.withValues(alpha: 0.10)
          : cs.tertiaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.all(context.rs(6)),
          child: Icon(
            icon,
            size: context.rsi(20),
            color: color,
          ),
        ),
      ),
    );
  }
}

/// 현장 이름·주소 검색 + 정렬.
class _PlaceListSearchSortBar extends ConsumerStatefulWidget {
  const _PlaceListSearchSortBar({
    required this.state,
    required this.viewModel,
  });

  final PlaceListState state;
  final PlaceListViewModel viewModel;

  @override
  ConsumerState<_PlaceListSearchSortBar> createState() =>
      _PlaceListSearchSortBarState();
}

class _PlaceListSearchSortBarState
    extends ConsumerState<_PlaceListSearchSortBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final vm = widget.viewModel;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasQuery = state.searchQuery.trim().isNotEmpty;
    final displayedCount = state.totalCount ?? state.filteredPlaceList.length;
    final favInView = state.filteredPlaceList
        .where((p) => p.pid != null && state.favoritePids.contains(p.pid))
        .length;
    final countParts = <String>[
      if (favInView > 0) '즐겨찾기 $favInView',
      if (hasQuery)
        '검색 $displayedCount곳 · 이 탭 ${state.tabPlaceCount}곳'
      else
        '총 $displayedCount곳',
    ];
    final countLine = countParts.join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: context.rs(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '현장 이름·주소 검색',
                    isDense: true,
                    prefixIcon:
                        Icon(Icons.search_rounded, size: context.rsi(22)),
                    suffixIcon: hasQuery
                        ? IconButton(
                            tooltip: '지우기',
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              vm.clearSearchQuery();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: _PlaceListChrome.fieldFill(cs),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rs(12)),
                      borderSide: BorderSide(
                        color: _PlaceListChrome.fieldBorder(cs),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rs(12)),
                      borderSide: BorderSide(
                        color: _PlaceListChrome.fieldBorder(cs),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rs(12)),
                      borderSide: BorderSide(
                        color: cs.primary.withValues(alpha: 0.65),
                        width: 1.4,
                      ),
                    ),
                  ),
                  onChanged: vm.setSearchQuery,
                  onSubmitted: vm.setSearchQuery,
                ),
              ),
              rsH(context, 8),
              PopupMenuButton<PlaceListSortMode>(
                tooltip: '정렬 · ${state.sortMode.labelKo}',
                initialValue: state.sortMode,
                onSelected: vm.setSortMode,
                child: Container(
                  height: context.rs(48),
                  padding: ResponsiveLayout.symmetric(context, horizontal: 10),
                  decoration: BoxDecoration(
                    color: _PlaceListChrome.fieldFill(cs),
                    borderRadius: BorderRadius.circular(context.rs(12)),
                    border: Border.all(
                      color: _PlaceListChrome.fieldBorder(cs),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded,
                          size: context.rsi(20), color: cs.primary),
                      rsH(context, 4),
                      Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
                itemBuilder: (ctx) {
                  return PlaceListSortMode.optionsFor(state.placeState)
                      .map(
                        (mode) => PopupMenuItem<PlaceListSortMode>(
                          value: mode,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                child: mode == state.sortMode
                                    ? Icon(Icons.check_rounded,
                                        size: 18, color: cs.primary)
                                    : null,
                              ),
                              Expanded(
                                child: Text(
                                  mode.labelKo,
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: mode == state.sortMode
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            countLine,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 현장 목록 상단·검색·카드 공통 톤 — 회색 fill 대신 흰 카드 + 옅은 악센트.
abstract final class _PlaceListChrome {
  static Color pageBackground(ColorScheme cs) => cs.surface;

  static Color fieldFill(ColorScheme cs) => cs.appCardSurface;

  static Color fieldBorder(ColorScheme cs) => cs.appBorder;

  static Color pinnedCardFill(ColorScheme cs) =>
      Color.alphaBlend(cs.primary.withValues(alpha: 0.04), cs.appCardSurface);

  static Color metricFill(ColorScheme cs) => cs.appIconBadge;
}

/// [placeListProvider] 초기 로드를 build 밖(첫 프레임 이후)으로 옮깁니다.
class _PlaceListBootstrap extends ConsumerStatefulWidget {
  const _PlaceListBootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_PlaceListBootstrap> createState() =>
      _PlaceListBootstrapState();
}

class _PlaceListBootstrapState extends ConsumerState<_PlaceListBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _ensurePlaceListLoaded());
  }

  void _ensurePlaceListLoaded({bool force = false}) {
    if (!mounted) return;
    if (ref.read(authSessionProvider).asData?.value == null) return;
    final st = ref.read(placeListProvider);
    if (!force && st.hasLoadedOnce) return;
    unawaited(
      ref.read(placeListProvider.notifier).initialize(force: force),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserRead?>>(authSessionProvider, (prev, next) {
      final u = next.asData?.value;
      if (u == null) return;
      final prevUser = prev?.asData?.value;
      final accountChanged =
          prevUser == null || prevUser.uid != u.uid || prevUser.role != u.role;
      if (!accountChanged && ref.read(placeListProvider).hasLoadedOnce) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensurePlaceListLoaded(force: accountChanged);
      });
    });
    return widget.child;
  }
}

class _PlaceInfiniteListView extends ConsumerStatefulWidget {
  const _PlaceInfiniteListView({
    required this.viewModel,
    required this.canManagePlaces,
    required this.buildTile,
  });

  final PlaceListViewModel viewModel;
  final bool canManagePlaces;
  final Widget Function(BuildContext context, int index) buildTile;

  @override
  ConsumerState<_PlaceInfiniteListView> createState() =>
      _PlaceInfiniteListViewState();
}

class _PlaceInfiniteListViewState
    extends ConsumerState<_PlaceInfiniteListView> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    onPagedScrollNearEnd(
      _scroll,
      onLoadMore: widget.viewModel.loadMorePlaces,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(placeListProvider);
    final brightness = Theme.of(context).brightness;
    final listLen = state.filteredPlaceList.length;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
          _onScroll();
        }
        return false;
      },
      child: ListView.builder(
        key: ValueKey('place_list_$brightness'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: context.rs(8),
          bottom: context.rs(24),
        ),
        itemCount: listLen + 1,
        itemBuilder: (ctx, index) {
          if (index >= listLen) {
            return PagedListFooter(
              isLoading: state.isLoadingMore,
              hasMore: state.canLoadMore,
            );
          }
          return widget.buildTile(ctx, index);
        },
      ),
    );
  }
}
