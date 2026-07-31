import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:w0001/util/career_input.dart';
import 'package:w0001/util/responsive_layout.dart';

enum CareerInputMode { directYears, startYear }

/// 경력 입력 — 년수 직접 선택 또는 시작 연도 선택.
class CareerInputSection extends StatefulWidget {
  const CareerInputSection({
    super.key,
    required this.initialCareer,
    required this.onChanged,
    this.compact = false,
    this.allowStartYearMode = true,
    this.showTitle = true,
  });

  final String initialCareer;
  final ValueChanged<String> onChanged;
  final bool compact;
  final bool allowStartYearMode;
  final bool showTitle;

  @override
  State<CareerInputSection> createState() => CareerInputSectionState();
}

class CareerInputSectionState extends State<CareerInputSection> {
  late CareerInputMode _mode;
  late int _years;
  late int _startYear;
  late FixedExtentScrollController _yearsController;
  late FixedExtentScrollController _startYearController;
  String? _lastEmittedCareer;
  var _pickerScrolling = false;

  int get _startYearItemCount => CareerInputUtils.startYearItemCount();

  /// iOS [CupertinoPicker] 기본값과 동일 — 관성·스냅이 자연스럽다.
  static const _pickerDiameterRatio = 1.07;
  static const _pickerSqueeze = 1.45;

  @override
  void initState() {
    super.initState();
    final wasEmpty = widget.initialCareer.trim().isEmpty;
    _applyCareer(widget.initialCareer, notify: false);
    _mode = CareerInputMode.directYears;
    _yearsController = FixedExtentScrollController(initialItem: _years);
    _startYearController = FixedExtentScrollController(
      initialItem: CareerInputUtils.startYearToIndex(_startYear),
    );
    if (wasEmpty && _years > 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _emit());
    }
  }

  void _applyCareer(String career, {required bool notify}) {
    final initial = CareerInputUtils.initialPickerState(career);
    _years = initial.years;
    _startYear = initial.startYear;
    if (notify) _emit();
  }

  @override
  void didUpdateWidget(CareerInputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCareer == widget.initialCareer) return;

    // 자식이 방금 올린 값이 부모에 반영된 경우 — 피커를 초기값으로 되돌리지 않음.
    if (widget.initialCareer == _lastEmittedCareer) {
      _lastEmittedCareer = null;
      return;
    }

    _applyCareer(widget.initialCareer, notify: false);
    _syncControllerToState(_yearsController, _years);
    _syncControllerToState(
      _startYearController,
      CareerInputUtils.startYearToIndex(_startYear),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _yearsController.dispose();
    _startYearController.dispose();
    super.dispose();
  }

  String get career => CareerInputUtils.formatYears(_years);

  void _emit() {
    final value = career;
    _lastEmittedCareer = value;
    widget.onChanged(value);
  }

  void _syncControllerToState(
      FixedExtentScrollController controller, int index) {
    if (!controller.hasClients) {
      controller.jumpToItem(index);
      return;
    }
    if (controller.selectedItem == index) return;
    controller.jumpToItem(index);
  }

  void _onModeChanged(CareerInputMode next) {
    if (_mode == next) return;
    setState(() => _mode = next);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (next == CareerInputMode.directYears) {
        _syncControllerToState(_yearsController, _years);
      } else {
        _syncControllerToState(
          _startYearController,
          CareerInputUtils.startYearToIndex(_startYear),
        );
      }
    });
  }

  void _setYears(int years) {
    final clamped = years.clamp(0, CareerInputUtils.maxYears);
    if (_years == clamped) return;
    _years = clamped;
    _startYear = CareerInputUtils.startYearFromYears(_years);
    if (!_pickerScrolling) {
      if (mounted) setState(() {});
      _emit();
    }
  }

  void _setStartYear(int startYear) {
    final clamped = startYear.clamp(
      CareerInputUtils.minStartYear,
      DateTime.now().year,
    );
    final years = CareerInputUtils.yearsFromStartYear(clamped);
    if (_startYear == clamped && _years == years) return;
    _startYear = clamped;
    _years = years;
    if (!_pickerScrolling) {
      if (mounted) setState(() {});
      _emit();
    }
  }

  void _onPickerScrollEnd() {
    _pickerScrolling = false;
    if (mounted) {
      setState(() {});
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Text(
            '경력',
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: context.rsi(6)),
        ],
        if (widget.allowStartYearMode) ...[
          SegmentedButton<CareerInputMode>(
            segments: const [
              ButtonSegment(
                value: CareerInputMode.directYears,
                label: Text('경력 년수'),
              ),
              ButtonSegment(
                value: CareerInputMode.startYear,
                label: Text('시작 연도'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => _onModeChanged(selection.first),
          ),
          SizedBox(height: context.rsi(10)),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _mode == CareerInputMode.directYears
              ? _iosStylePicker(
                  key: const ValueKey('career-years'),
                  context: context,
                  controller: _yearsController,
                  itemCount: CareerInputUtils.maxYears + 1,
                  labelBuilder: CareerInputUtils.pickerLabelForYears,
                  onSelected: _setYears,
                )
              : _iosStylePicker(
                  key: const ValueKey('career-start-year'),
                  context: context,
                  controller: _startYearController,
                  itemCount: _startYearItemCount,
                  labelBuilder: (index) =>
                      '${CareerInputUtils.indexToStartYear(index)}년',
                  onSelected: (index) =>
                      _setStartYear(CareerInputUtils.indexToStartYear(index)),
                ),
        ),
        SizedBox(height: context.rsi(8)),
        Text(
          _mode == CareerInputMode.directYears
              ? '경력 ${CareerInputUtils.formatYears(_years)}'
              : '$_startYear년부터 · 경력 ${CareerInputUtils.formatYears(_years)}',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _iosStylePicker({
    required Key key,
    required BuildContext context,
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) labelBuilder,
    required ValueChanged<int> onSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    final itemExtent = context.rsi(36);

    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: SizedBox(
        height: context.rsi(widget.compact ? 216 : 236),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: itemExtent,
              margin: EdgeInsets.symmetric(horizontal: context.rsi(12)),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            CupertinoTheme(
              data: CupertinoTheme.of(context).copyWith(
                primaryColor: cs.primary,
                textTheme: CupertinoTextThemeData(
                  pickerTextStyle: TextStyle(
                    fontSize: context.rs(20),
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _pickerScrolling = true;
                  } else if (notification is ScrollEndNotification) {
                    _onPickerScrollEnd();
                  }
                  return false;
                },
                child: CupertinoPicker.builder(
                  scrollController: controller,
                  itemExtent: itemExtent,
                  diameterRatio: _pickerDiameterRatio,
                  squeeze: _pickerSqueeze,
                  useMagnifier: true,
                  magnification: 1.08,
                  offAxisFraction: 0,
                  onSelectedItemChanged: onSelected,
                  itemBuilder: (context, index) {
                    if (index < 0 || index >= itemCount) return null;
                    return Center(
                      child: Text(
                        labelBuilder(index),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                    );
                  },
                  childCount: itemCount,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
