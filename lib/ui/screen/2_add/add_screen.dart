import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/ui/screen/2_add/material_cost_tab.dart';
import 'package:w0001/ui/screen/2_add/work_cost_tab.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/ui/widget/place_picker/place_cost_picker_sheet.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 선택 첫 화면: 본문 하단(하단 탭바 바로 위)에서 띄울 간격 — 논리 픽셀(dp/pt), 해상도마다 동일 비율
const double _kPlacePickerGapAboveBottomNav = 30;

String _placePickerDisplayLabel(PlaceModel item, AddCostState state) {
  return placeCostPickerDisplayLabel(
    item,
    filter: state.costPlacePickerFilter,
  );
}

class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({
    super.key,
    this.embeddedPlace,
  });

  /// 현장 금액관리에 임베드할 때 잠글 현장. 있으면 현장 선택 화면을 생략한다.
  final PlaceModel? embeddedPlace;

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen>
    with SingleTickerProviderStateMixin {
  /// 스크롤처럼 한 화면 높이만큼 위로 밀어 올리는 시간
  static const _openDuration = Duration(milliseconds: 480);

  /// 이 값 이상이면 전환 레이아웃 대신 메인 패널만 씀(Transform·이중 IgnorePointer 제거 → 터치 정상).
  static const _kOpenLayoutThreshold = 0.999;

  /// 이 값 이하면 현장 선택 패널만 씀.
  static const _kClosedLayoutThreshold = 0.001;

  AnimationController? _openController;

  bool get _embedded => widget.embeddedPlace != null;

  @override
  void initState() {
    super.initState();
    if (_embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncEmbeddedPlace();
      });
      return;
    }
    _openController = AnimationController(vsync: this, duration: _openDuration);
    if (ref.read(addCostProvider).selectedPlace != null) {
      _openController!.value = 1;
    }
  }

  void _syncEmbeddedPlace() {
    final place = widget.embeddedPlace;
    if (!mounted || place == null) return;
    final current = ref.read(addCostProvider).selectedPlace;
    if (current?.pid != place.pid) {
      ref.read(addCostProvider.notifier).placeChangeAction(context, place);
    }
  }

  @override
  void dispose() {
    _openController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);

    if (_embedded) {
      return DefaultTabController(
        length: 2,
        initialIndex: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () => FocusScope.of(context).unfocus(),
          child: _buildScrollMainPanel(
            context,
            ref,
            vm,
            state,
            showPlaceSwitcher: false,
          ),
        ),
      );
    }

    final openController = _openController!;
    ref.listen<AddCostState>(addCostProvider, (previous, next) {
      if (previous?.selectedPlace == null && next.selectedPlace != null) {
        openController.forward(from: 0);
      }
      if (previous?.selectedPlace != null && next.selectedPlace == null) {
        openController.reverse();
      }
    });

    final hasPlace = state.selectedPlace != null;

    return BackButtonListener(
      onBackButtonPressed: () async {
        if (ref.read(addCostProvider).selectedPlace == null) return false;
        FocusScope.of(context).unfocus();
        return consumeAddCostBackNavigation();
      },
      child: _AddCostPlaceDetailBackGesture(
        enabled: hasPlace,
        onBack: () {
          FocusScope.of(context).unfocus();
          vm.clearSelectedPlace();
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (ref.read(addCostProvider).selectedPlace == null) return;
            FocusScope.of(context).unfocus();
            vm.clearSelectedPlace();
          },
          child: DefaultTabController(
            length: 2,
            initialIndex: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                body: AnimatedBuilder(
                  animation: openController,
                  builder: (context, _) {
                    final u = Curves.easeInOutCubic
                        .transform(openController.value.clamp(0.0, 1.0));
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final media = MediaQuery.of(context);
                        final w = constraints.maxWidth;
                        // body는 보통 bounded이나, 무한/0이면 화면 기준으로 보정
                        var h = constraints.maxHeight;
                        if (!h.isFinite || h <= 0) {
                          h = media.size.height -
                              media.padding.top -
                              media.padding.bottom;
                        }

                        if (u >= _kOpenLayoutThreshold) {
                          return SizedBox(
                            height: h,
                            width: w,
                            child: _buildScrollMainPanel(
                              context,
                              ref,
                              vm,
                              state,
                            ),
                          );
                        }
                        if (u <= _kClosedLayoutThreshold) {
                          return SizedBox(
                            height: h,
                            width: w,
                            child: _buildPlacePickerPanel(
                              context,
                              ref,
                              vm,
                              state,
                              w,
                            ),
                          );
                        }

                        final offsetY = u * h;
                        // ScrollView는 TabBarView+Expanded 조합에 세로 무한 제약을 줘 레이아웃이 깨짐.
                        // OverflowBox로 2h를 그린 뒤 ClipRect+Transform으로 뷰포트만 보이게 함.
                        // 전환 중 터치: u∈(0.08,0.35)에서 첫·둘째 IgnorePointer가 동시에 true가 되어
                        // 화면만 보이고 전부 클릭 불가가 되던 구간을 0.5 기준으로 분리한다.
                        return SizedBox(
                          height: h,
                          width: w,
                          child: ClipRect(
                            clipBehavior: Clip.hardEdge,
                            child: Transform.translate(
                              offset: Offset(0, -offsetY),
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minWidth: w,
                                maxWidth: w,
                                minHeight: 2 * h,
                                maxHeight: 2 * h,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      height: h,
                                      width: w,
                                      child: IgnorePointer(
                                        ignoring: u >= 0.5,
                                        child: _buildPlacePickerPanel(
                                          context,
                                          ref,
                                          vm,
                                          state,
                                          w,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: h,
                                      width: w,
                                      child: IgnorePointer(
                                        ignoring: u < 0.5,
                                        child: _buildScrollMainPanel(
                                          context,
                                          ref,
                                          vm,
                                          state,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlacePickerPanel(
    BuildContext context,
    WidgetRef ref,
    AddCostViewModel vm,
    AddCostState state,
    double w,
  ) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rs(24),
            0,
            context.rs(24),
            context.rs(_kPlacePickerGapAboveBottomNav),
          ),
          child: SizedBox(
            width: math.min(w - context.rs(48), context.rs(400)),
            child: state.selectedPlace == null
                ? placeDropdown(ref, vm, state, context)
                : SizedBox(height: context.rs(54)),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollMainPanel(
    BuildContext context,
    WidgetRef ref,
    AddCostViewModel vm,
    AddCostState state, {
    bool showPlaceSwitcher = true,
  }) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final headerColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: headerColor,
          elevation: 1,
          shadowColor: cs.shadow.withValues(alpha: 0.18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showPlaceSwitcher)
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: ResponsiveLayout.only(
                      context,
                      left: 12,
                      top: 6,
                      right: 12,
                    ),
                    child: placeDropdown(ref, vm, state, context),
                  ),
                ),
              TabBar(
                padding: ResponsiveLayout.symmetric(context, vertical: 5),
                labelPadding: ResponsiveLayout.symmetric(context, vertical: 5),
                tabs: [
                  Text('인건비', style: tt.titleSmall),
                  Text('자재비', style: tt.titleSmall),
                ],
              ),
            ],
          ),
        ),
        const Expanded(
          child: TabBarView(
            children: [
              WorkCostTab(),
              MaterialCostTab(),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: ResponsiveLayout.only(
              context,
              left: 15,
              top: 6,
              right: 15,
              bottom: 10,
            ),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '인건비 ${state.workCostList.length}건',
                      style: tt.bodyMedium,
                    ),
                    Text(
                      '자재비 ${state.materialCostList.length}건',
                      style: tt.bodyMedium,
                    ),
                  ],
                ),
                IconButton(
                  onPressed: state.isAllEmpty
                      ? null
                      : () => vm.showClearDialog(context),
                  icon: Icon(
                    size: context.rsi(18),
                    Icons.cancel,
                    color: state.isAllEmpty
                        ? cs.onSurfaceVariant.withValues(alpha: 0.45)
                        : cs.error,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: context.rs(35),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rs(10)),
                      ),
                    ),
                    onPressed: (state.workCostList.isEmpty &&
                                state.materialCostList.isEmpty) ||
                            state.isSaving
                        ? null
                        : () => vm.insertCostLists(context),
                    child: Text(
                      state.isSaving ? '저장 중...' : '저장하기',
                      style: tt.labelLarge?.copyWith(color: cs.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget placeDropdown(
  WidgetRef ref,
  AddCostViewModel vm,
  AddCostState state,
  BuildContext context,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final tt = theme.textTheme;
  final borderRadius = BorderRadius.circular(context.rsi(10));
  final selected = state.selectedPlace;
  final label =
      selected != null ? _placePickerDisplayLabel(selected, state) : null;

  Future<void> openPicker() async {
    final picked = await showPlaceCostPickerSheet(
      context: context,
      ref: ref,
      filter: state.costPlacePickerFilter,
      selectedPid: selected?.pid,
    );
    if (picked != null && context.mounted) {
      vm.placeChangeAction(context, picked);
    }
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<CostPlacePickerFilter>(
            segments: const [
              ButtonSegment<CostPlacePickerFilter>(
                value: CostPlacePickerFilter.all,
                label: Text('전체'),
                tooltip: '진행중·완료',
              ),
              ButtonSegment<CostPlacePickerFilter>(
                value: CostPlacePickerFilter.inProgress,
                label: Text('진행중'),
              ),
              ButtonSegment<CostPlacePickerFilter>(
                value: CostPlacePickerFilter.completed,
                label: Text('완료'),
              ),
            ],
            selected: {state.costPlacePickerFilter},
            showSelectedIcon: false,
            onSelectionChanged: (next) {
              if (next.isEmpty) return;
              vm.setCostPlacePickerFilter(next.first);
            },
            style: AppSegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 54,
        child: Material(
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: cs.outlineVariant,
              width: 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: openPicker,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rsi(12),
                vertical: context.rsi(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.home_work_outlined,
                    size: context.rs(20),
                    color: cs.onSurfaceVariant,
                  ),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: Text(
                      label ?? '현장을 선택해 주세요',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (label != null ? tt.titleMedium : tt.bodyMedium)
                          ?.copyWith(
                        fontWeight:
                            label != null ? FontWeight.w500 : FontWeight.w500,
                        color: label != null ? cs.onSurface : cs.outline,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 24,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget tempCostBuilder(
  WidgetRef ref,
  BuildContext context,
  int index,
  String costType,
) {
  final state = ref.watch(addCostProvider);
  final vm = ref.read(addCostProvider.notifier);
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final tt = theme.textTheme;

  late final String dateStr;
  late final Widget title;
  late final String pname;
  late final int price;

  if (costType == 'material') {
    final item = state.materialCostList.reversed.toList()[index];
    dateStr = item.mdate;
    title = Row(
      children: [
        Text(
          '[${item.mcategory}] ',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        Expanded(
          child: Text(
            item.mname,
            style: tt.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    pname = item.pname ?? '';
    price = item.mprice;
  } else {
    final item = state.workCostList.reversed.toList()[index];
    dateStr = item.wdate;
    title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.hname!,
          style: tt.bodyMedium,
        ),
        if (item.wrole.isNotEmpty)
          Text(
            item.wrole,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
    pname = item.pname ?? '';
    price = item.wprice;
  }

  final itemIndex = costType == 'material'
      ? state.materialCostList.length - 1 - index
      : state.workCostList.length - 1 - index;
  return Slidable(
    closeOnScroll: true,
    endActionPane: ActionPane(
      motion: const DrawerMotion(),
      children: [
        SlidableAction(
          borderRadius: BorderRadius.circular(10),
          backgroundColor: cs.error,
          icon: Icons.delete,
          label: '삭제',
          onPressed: (slidableCtx) => showDialog<void>(
            context: slidableCtx,
            builder: (dialogCtx) => deleteDialog(
              onPressed: () {
                if (costType == 'material') {
                  vm.deleteMaterialList(index);
                } else {
                  vm.deleteWorkList(index);
                }
                Navigator.of(dialogCtx).pop();
              },
            ),
          ),
        ),
      ],
    ),
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(context.rs(12)),
        onTap: () async {
          if (costType == 'material') {
            final item = state.materialCostList[itemIndex];
            await _showEditPendingMaterialCostDialog(
              context,
              ref,
              itemIndex,
              item,
            );
            return;
          }
          final item = state.workCostList[itemIndex];
          await _showQuickEditPendingWorkCostDialog(
              context, ref, itemIndex, item);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rsi(15),
                vertical: context.rsi(5),
              ),
              child: Text(
                formatDateTimeWeekDayToString(DateTime.parse(dateStr)),
                style: tt.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 0),
            ListTile(
              dense: true,
              title: title,
              subtitle: Text(
                pname,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              trailing: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.rs(108)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    getPrice(price: price),
                    style: tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showQuickEditPendingWorkCostDialog(
  BuildContext context,
  WidgetRef ref,
  int originalIndex,
  WorkCostModel item,
) async {
  final vm = ref.read(addCostProvider.notifier);
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final nameController = TextEditingController(text: item.hname ?? '');
  final roleController = TextEditingController(text: item.wrole);
  final priceController = TextEditingController(
    text: item.wprice > 0
        ? getPrice(price: item.wprice, isContainWon: false)
        : '',
  );
  final pickedDay =
      DateTime.tryParse(item.wdate) ?? ref.read(addCostProvider).selectDay;
  final selectedDay = DateTime(pickedDay.year, pickedDay.month, pickedDay.day);
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.rsi(14)),
          color: cs.surface,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(14),
            context.rsi(16),
            context.rsi(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '인건비 항목 수정',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: context.rsi(4)),
              Text(
                '날짜는 연동 안정성을 위해 변경할 수 없습니다.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              SizedBox(height: context.rsi(10)),
              _readOnlyDateCalendarBlock(context, selectedDay),
              SizedBox(height: context.rsi(8)),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              SizedBox(height: context.rsi(8)),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: '공정/역할'),
              ),
              SizedBox(height: context.rsi(8)),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '금액'),
              ),
              SizedBox(height: context.rsi(10)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('취소'),
                    ),
                  ),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        final role = roleController.text.trim();
                        final price = int.tryParse(
                          priceController.text
                              .trim()
                              .replaceAll(RegExp(r'[,원\s]'), ''),
                        );
                        if (name.isEmpty || price == null || price < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이름/금액을 확인해 주세요.')),
                          );
                          return;
                        }
                        vm.updateWorkCostAt(
                          originalIndex,
                          item.copyWith(
                            hname: name,
                            wrole: role,
                            wprice: price,
                          ),
                        );
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('수정 저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  nameController.dispose();
  roleController.dispose();
  priceController.dispose();
}

Future<void> _showEditPendingMaterialCostDialog(
  BuildContext context,
  WidgetRef ref,
  int originalIndex,
  MaterialCostModel item,
) async {
  final vm = ref.read(addCostProvider.notifier);
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final nameController = TextEditingController(text: item.mname);
  final priceController = TextEditingController(
    text: item.mprice > 0
        ? getPrice(price: item.mprice, isContainWon: false)
        : '',
  );
  final pickedDay =
      DateTime.tryParse(item.mdate) ?? ref.read(addCostProvider).selectDay;
  final selectedDay = DateTime(pickedDay.year, pickedDay.month, pickedDay.day);

  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.rsi(14)),
          color: cs.surface,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rsi(16),
            context.rsi(14),
            context.rsi(16),
            context.rsi(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '자재비 항목 수정',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: context.rsi(4)),
              Text(
                '날짜는 연동 안정성을 위해 변경할 수 없습니다.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              SizedBox(height: context.rsi(10)),
              _readOnlyDateCalendarBlock(context, selectedDay),
              SizedBox(height: context.rsi(8)),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '자재 이름'),
              ),
              SizedBox(height: context.rsi(8)),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '금액'),
              ),
              SizedBox(height: context.rsi(10)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('취소'),
                    ),
                  ),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        final price = int.tryParse(
                          priceController.text
                              .trim()
                              .replaceAll(RegExp(r'[,원\s]'), ''),
                        );
                        if (name.isEmpty || price == null || price < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('항목과 금액을 확인해 주세요.')),
                          );
                          return;
                        }
                        vm.updateMaterialCostAt(
                          originalIndex,
                          MaterialCostModel(
                            pname: item.pname,
                            mid: item.mid,
                            mpid: item.mpid,
                            mname: name,
                            mdate: item.mdate,
                            mcategory: item.mcategory,
                            mprice: price,
                          ),
                        );
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('수정 저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  nameController.dispose();
  priceController.dispose();
}

Widget _readOnlyDateCalendarBlock(BuildContext context, DateTime day) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return Container(
    decoration: BoxDecoration(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(context.rsi(12)),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
    ),
    padding: EdgeInsets.all(context.rsi(8)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          formatDateTimeWeekDayToString(day),
          style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// iOS: 쉘 탭 안에는 네비게이터 스택이 없어 시스템 스와이프 뒤로가기가 없음 → 왼쪽 가장자리 스와이프로 현장 선택 해제.
class _AddCostPlaceDetailBackGesture extends StatefulWidget {
  const _AddCostPlaceDetailBackGesture({
    required this.enabled,
    required this.onBack,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onBack;
  final Widget child;

  @override
  State<_AddCostPlaceDetailBackGesture> createState() =>
      _AddCostPlaceDetailBackGestureState();
}

class _AddCostPlaceDetailBackGestureState
    extends State<_AddCostPlaceDetailBackGesture> {
  double _dragDx = 0;

  bool get _useIosEdgeSwipe =>
      widget.enabled && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!_useIosEdgeSwipe) return widget.child;

    final edgeW = (MediaQuery.sizeOf(context).width * 0.08).clamp(20.0, 36.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: edgeW,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _dragDx = 0,
            onHorizontalDragUpdate: (d) {
              if (d.delta.dx > 0) _dragDx += d.delta.dx;
            },
            onHorizontalDragEnd: (_) {
              if (_dragDx >= 56) widget.onBack();
              _dragDx = 0;
            },
            onHorizontalDragCancel: () => _dragDx = 0,
          ),
        ),
      ],
    );
  }
}
