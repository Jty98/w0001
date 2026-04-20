import 'dart:math' as math;

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/ui/screen/2_add/material_cost_tab.dart';
import 'package:w0001/ui/screen/2_add/work_cost_tab.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/text_style.dart';
import 'package:w0001/ui/widget/delete_dialog.dart';

/// 현장 선택 첫 화면: 본문 하단(하단 탭바 바로 위)에서 띄울 간격 — 논리 픽셀(dp/pt), 해상도마다 동일 비율
const double _kPlacePickerGapAboveBottomNav = 80;

/// 현장 선택 메뉴를 필드 **위쪽**으로 열기 (한손 조작 시 목록이 손가락 쪽으로)
RelativeRect _placeMenuAbovePosition(RenderBox button, RenderBox overlay) {
  final sz = button.size;
  final tl = button.localToGlobal(Offset.zero, ancestor: overlay);
  final tr = button.localToGlobal(Offset(sz.width, 0), ancestor: overlay);
  final w = overlay.size.width;
  final h = overlay.size.height;
  const gap = 6.0;
  const maxMenuHeight = 400.0;
  final anchorTop = tl.dy - gap;
  final top = math.max(8.0, anchorTop - maxMenuHeight);
  return RelativeRect.fromLTRB(
    tl.dx.clamp(8.0, w - 8.0),
    top,
    math.max(8.0, w - tr.dx),
    h - anchorTop,
  );
}

/// 패키지 기본과 동일 — 필드 **아래**로 메뉴 펼침.
RelativeRect _placeMenuBelowPosition(RenderBox button, RenderBox overlay) {
  return RelativeRect.fromSize(
    Rect.fromPoints(
      button.localToGlobal(
        button.size.bottomLeft(Offset.zero),
        ancestor: overlay,
      ),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Size(overlay.size.width, overlay.size.height),
  );
}

bool _placeModelSame(PlaceModel a, PlaceModel b) {
  if (a.pid != null && b.pid != null) return a.pid == b.pid;
  return identical(a, b);
}

Widget _placeDropdownEmptyBuilder(BuildContext context, String searchEntry) {
  return const Center(child: Text('진행중인 현장이 없습니다.'));
}

class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key});

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

  late final AnimationController _openController;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(vsync: this, duration: _openDuration);
    if (ref.read(addCostProvider).selectedPlace != null) {
      _openController.value = 1;
    }
  }

  @override
  void dispose() {
    _openController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AddCostState>(addCostProvider, (previous, next) {
      if (previous?.selectedPlace == null && next.selectedPlace != null) {
        _openController.forward(from: 0);
      }
      if (previous?.selectedPlace != null && next.selectedPlace == null) {
        _openController.reverse();
      }
    });

    final state = ref.watch(addCostProvider);
    final vm = ref.read(addCostProvider.notifier);

    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          body: AnimatedBuilder(
            animation: _openController,
            builder: (context, _) {
              final u = Curves.easeInOutCubic
                  .transform(_openController.value.clamp(0.0, 1.0));
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
          padding: const EdgeInsets.fromLTRB(
            24,
            0,
            24,
            _kPlacePickerGapAboveBottomNav,
          ),
          child: SizedBox(
            width: math.min(w - 48, 400),
            child: state.selectedPlace == null
                ? placeDropdown(
                    ref,
                    vm,
                    state,
                    context,
                    openPopupAbove: true,
                  )
                : const SizedBox(height: 54),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollMainPanel(
    BuildContext context,
    WidgetRef ref,
    AddCostViewModel vm,
    AddCostState state,
  ) {
    final theme = Theme.of(context);
    final headerColor = theme.appBarTheme.backgroundColor ??
        theme.colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: headerColor,
          elevation: 1,
          shadowColor: Colors.black26,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: SizedBox(
                    height: 54,
                    child: placeDropdown(
                      ref,
                      vm,
                      state,
                      context,
                      openPopupAbove: false,
                    ),
                  ),
                ),
              ),
              const TabBar(
                padding: EdgeInsets.symmetric(vertical: 5),
                labelPadding: EdgeInsets.symmetric(vertical: 5),
                tabs: [
                  Text('인건비', style: normalStyle),
                  Text('자재비', style: normalStyle),
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
            padding: const EdgeInsets.fromLTRB(15, 6, 15, 10),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '인건비 ${state.workCostList.length}건',
                      style: size15Style,
                    ),
                    Text(
                      '자재비 ${state.materialCostList.length}건',
                      style: size15Style,
                    ),
                  ],
                ),
                IconButton(
                  onPressed: state.isAllEmpty
                      ? null
                      : () => vm.showClearDialog(context),
                  icon: Icon(
                    size: 18,
                    Icons.cancel,
                    color: state.isAllEmpty ? Colors.grey[400] : Colors.red,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 35,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: state.workCostList.isEmpty &&
                            state.materialCostList.isEmpty
                        ? null
                        : () => vm.insertCostLists(context),
                    child: const Text(
                      '저장하기',
                      style: size15Style,
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
  BuildContext context, {
  bool openPopupAbove = false,
}) {
  return SizedBox(
    height: 54,
    child: DropdownSearch<PlaceModel>(
      compareFn: _placeModelSame,
      asyncItems: (text) =>
          ref.read(placeUseCaseProvider).getIncompletePlaces(),
      itemAsString: (item) => item.pname,
      popupProps: PopupProps.menu(
        menuProps: MenuProps(
          positionCallback: openPopupAbove
              ? _placeMenuAbovePosition
              : _placeMenuBelowPosition,
        ),
        searchDelay: Duration.zero,
        emptyBuilder: _placeDropdownEmptyBuilder,
      ),
      dropdownButtonProps: DropdownButtonProps(
        icon: Icon(
          openPopupAbove ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          size: 24,
        ),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        textAlign: TextAlign.center,
        baseStyle: const TextStyle(
          fontSize: 18,
          color: Colors.black,
        ),
        dropdownSearchDecoration: InputDecoration(
          isDense: true,
          hintStyle: const TextStyle(color: Colors.red, fontSize: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          hintText: '현장을 선택해 주세요.',
        ),
      ),
      onChanged: (value) => vm.placeChangeAction(context, value!),
      selectedItem: state.selectedPlace,
    ),
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
          style: category2Style,
        ),
        Expanded(
          child: Text(
            item.mname,
            style: normalStyle,
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
          style: normalStyle,
        ),
        if (item.wrole.isNotEmpty)
          Text(
            item.wrole,
            style: categoryStyle,
          ),
      ],
    );
    pname = item.pname ?? '';
    price = item.wprice;
  }

  return Slidable(
    closeOnScroll: true,
    endActionPane: ActionPane(
      motion: const DrawerMotion(),
      children: [
        SlidableAction(
          borderRadius: BorderRadius.circular(10),
          backgroundColor: Colors.red,
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
      child: SizedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Text(
                formatDateTimeWeekDayToString(DateTime.parse(dateStr)),
                style: blueTitleStyle,
              ),
            ),
            const Divider(height: 0),
            ListTile(
              dense: true,
              title: title,
              subtitle: Text(
                pname,
                style: categoryStyle,
              ),
              trailing: Text(
                getPrice(price: price),
                style: normalStyle,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
