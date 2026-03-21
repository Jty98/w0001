import 'package:date_picker_plus/date_picker_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show materialCostUseCaseProvider, workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show humanUseCaseProvider;
import 'package:w0001/ui/widget/delete_dialog.dart';
import 'package:w0001/ui/widget/save_dialog.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/util/fetch_data.dart';

class AddCostState {
  const AddCostState({
    required this.materialCostList,
    required this.workCostList,
    required this.selectDay,
    required this.alertText,
    required this.selectedPlace,
    required this.selectedWorker,
    required this.selectedCategory,
  });

  final List<MaterialCostModel> materialCostList;
  final List<WorkCostModel> workCostList;
  final DateTime selectDay;
  final String alertText;
  final PlaceModel? selectedPlace;
  final HumanModel? selectedWorker;
  final String? selectedCategory;

  bool get isAllEmpty => workCostList.isEmpty && materialCostList.isEmpty;

  factory AddCostState.initial() => AddCostState(
        materialCostList: const [],
        workCostList: const [],
        selectDay: DateTime.now(),
        alertText: '',
        selectedPlace: null,
        selectedWorker: null,
        selectedCategory: null,
      );

  AddCostState copyWith({
    List<MaterialCostModel>? materialCostList,
    List<WorkCostModel>? workCostList,
    DateTime? selectDay,
    String? alertText,
    PlaceModel? selectedPlace,
    bool clearSelectedPlace = false,
    HumanModel? selectedWorker,
    bool clearSelectedWorker = false,
    String? selectedCategory,
    bool clearSelectedCategory = false,
  }) {
    return AddCostState(
      materialCostList: materialCostList ?? this.materialCostList,
      workCostList: workCostList ?? this.workCostList,
      selectDay: selectDay ?? this.selectDay,
      alertText: alertText ?? this.alertText,
      selectedPlace:
          clearSelectedPlace ? null : (selectedPlace ?? this.selectedPlace),
      selectedWorker:
          clearSelectedWorker ? null : (selectedWorker ?? this.selectedWorker),
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
    );
  }
}

final addCostProvider =
    NotifierProvider<AddCostViewModel, AddCostState>(AddCostViewModel.new);

class AddCostViewModel extends Notifier<AddCostState> {
  late final _humanUseCase = ref.read(humanUseCaseProvider);
  late final _materialCostUseCase = ref.read(materialCostUseCaseProvider);
  late final _workCostUseCase = ref.read(workCostUseCaseProvider);

  final TextEditingController hNameController = TextEditingController();
  final TextEditingController hNumController = TextEditingController();
  final TextEditingController hMemoController = TextEditingController();
  final TextEditingController mNameController = TextEditingController();
  final FocusNode mNameFocus = FocusNode();
  final TextEditingController mPriceController = TextEditingController();
  final FocusNode mPriceFocus = FocusNode();
  final TextEditingController wPriceController = TextEditingController();
  final FocusNode wPriceFocus = FocusNode();

  @override
  AddCostState build() {
    ref.onDispose(() {
      hNameController.dispose();
      hNumController.dispose();
      hMemoController.dispose();
      mNameController.dispose();
      mNameFocus.dispose();
      mPriceController.dispose();
      mPriceFocus.dispose();
      wPriceController.dispose();
      wPriceFocus.dispose();
    });
    return AddCostState.initial();
  }

  void clearSelectedPlace() {
    state = state.copyWith(clearSelectedPlace: true);
  }

  void clearSelectedWorker() {
    state = state.copyWith(clearSelectedWorker: true);
  }

  void placeChangeAction(BuildContext context, PlaceModel value) {
    state = state.copyWith(selectedPlace: value);
    try {
      FocusScope.of(context).unfocus();
    } catch (_) {}
  }

  void workerChangeAction(HumanModel value) {
    state = state.copyWith(selectedWorker: value);
    wPriceFocus.requestFocus();
  }

  void categoryChangeAction(String value) {
    state = state.copyWith(selectedCategory: value);
    mNameFocus.requestFocus();
  }

  void clearDialogText() {
    state = state.copyWith(alertText: '');
    hMemoController.clear();
    hNameController.clear();
    hNumController.clear();
  }

  void clearWorkerDialogAlert() {
    state = state.copyWith(alertText: '');
  }

  Future<bool> insertWorker() async {
    final hName = hNameController.text.trim();
    final hNum = hNumController.text.trim();
    final hMemo =
        hMemoController.text.isEmpty ? null : hMemoController.text.trim();
    final workerInfoList = await _humanUseCase.getAllWorkers();

    if (hName.isEmpty) {
      state = state.copyWith(alertText: '이름을 입력해주세요.');
      return false;
    }
    if (workerInfoList.any((e) => e.hname == hName)) {
      state = state.copyWith(alertText: '중복된 이름입니다.');
      return false;
    }

    final worker = HumanModel(
      hname: hName,
      hnumber: hNum,
      hmemo: hMemo,
      hstar: 0,
      hdelete: 0,
    );
    await _humanUseCase.addWorker(worker);
    final c = rootProviderContainer;
    if (c != null) {
      await c.read(workerProvider.notifier).fetchWorkerInfo();
    }
    hNameController.clear();
    hNumController.clear();
    hMemoController.clear();
    state = state.copyWith(alertText: '');
    return true;
  }

  Future<void> changeDateTime(BuildContext context) async {
    final picked = await showDatePickerDialog(
      context: context,
      minDate: DateTime(2000),
      maxDate: DateTime(2099),
      centerLeadingDate: true,
    );
    if (picked != null) {
      state = state.copyWith(selectDay: picked);
    }
  }

  void addMaterialCostList(BuildContext context) {
    var mpriceString = mPriceController.text.trim();
    mpriceString = mpriceString.replaceAll(RegExp(r'[,원]'), '');
    final mprice = int.tryParse(mpriceString);
    final mname = mNameController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (state.selectedPlace == null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('현장을 선택해주세요.')),
      );
      return;
    }
    if (state.selectedCategory == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요.')),
      );
      return;
    }
    if (mname.isEmpty || mprice == null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요.')),
      );
      return;
    }

    final model = MaterialCostModel(
      mcategory: state.selectedCategory!,
      pname: state.selectedPlace!.pname,
      mpid: state.selectedPlace!.pid,
      mname: mname,
      mdate: state.selectDay.toString(),
      mprice: mprice,
    );
    state = state.copyWith(
      materialCostList: [...state.materialCostList, model],
    );
    mNameController.clear();
    mPriceController.clear();
    FocusScope.of(context).unfocus();
  }

  void addWorkCostList(BuildContext context) {
    var wpriceString = wPriceController.text.trim();
    wpriceString = wpriceString.replaceAll(RegExp(r'[,원]'), '');
    final wprice = int.tryParse(wpriceString);
    final messenger = ScaffoldMessenger.of(context);

    if (state.selectedPlace == null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('현장을 선택해주세요.')),
      );
      return;
    }
    if (state.selectedWorker == null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('사람을 선택해주세요.')),
      );
      return;
    }
    if (wprice == null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('금액을 입력해주세요.')),
      );
      return;
    }

    final workCost = WorkCostModel(
      wcomplete: 0,
      wdate: state.selectDay.toString(),
      hname: state.selectedWorker!.hname,
      wprice: wprice,
      wpid: state.selectedPlace!.pid!,
      whid: state.selectedWorker!.hid,
      pname: state.selectedPlace!.pname,
    );
    state = state.copyWith(
      workCostList: [...state.workCostList, workCost],
    );
    wPriceController.clear();
    FocusScope.of(context).unfocus();
  }

  void deleteMaterialList(int index) {
    final next = List<MaterialCostModel>.from(state.materialCostList)
      ..removeAt(index);
    state = state.copyWith(materialCostList: next);
  }

  void deleteWorkList(int index) {
    final next = List<WorkCostModel>.from(state.workCostList)..removeAt(index);
    state = state.copyWith(workCostList: next);
  }

  Future<void> insertCostLists(BuildContext context) async {
    var isMaterialCostSuccess = false;
    var isWorkCostSuccess = false;

    if (state.materialCostList.isNotEmpty) {
      isMaterialCostSuccess =
          await _materialCostUseCase.addMaterialCosts(state.materialCostList);
    }

    if (state.workCostList.isNotEmpty) {
      isWorkCostSuccess =
          await _workCostUseCase.addWorkCosts(state.workCostList);
    }

    if (!isMaterialCostSuccess && !isWorkCostSuccess) {
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    await FetchData.fetchAllData();
    if (!context.mounted) return;
    FocusScope.of(context).unfocus();

    String message;
    if (isMaterialCostSuccess && isWorkCostSuccess) {
      message = '인건비 및 자재비가 저장되었습니다.';
    } else if (isMaterialCostSuccess) {
      message = '자재비가 저장되었습니다.';
    } else {
      message = '인건비가 저장되었습니다.';
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => saveDialog(text: message),
    );
    clearAllLists();
  }

  void clearAllLists() {
    state = state.copyWith(
      materialCostList: const [],
      workCostList: const [],
    );
  }

  void showClearDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => deleteDialog(
        content: '모두 비우시겠습니까?',
        onPressed: () {
          clearAllLists();
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}
