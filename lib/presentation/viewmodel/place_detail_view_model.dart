import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:w0001/data/datasources/remote/auth/users_api.dart';
import 'package:w0001/data/model/materialcost_model.dart';
import 'package:w0001/data/model/place_photo_entry.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/data/model/revenue_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/data/repository/materialcost_impl.dart';
import 'package:w0001/data/repository/revenue_impl.dart';
import 'package:w0001/data/repository/workcost_impl.dart';
import 'package:w0001/domain/repository/materialcost_abst.dart';
import 'package:w0001/domain/repository/revenue_abst.dart';
import 'package:w0001/domain/repository/workcost_abst.dart';
import 'package:w0001/domain/use_case/materialcost_use_case.dart';
import 'package:w0001/domain/use_case/revenue_use_case.dart';
import 'package:w0001/domain/use_case/workcost_use_case.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/enums.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show placeUseCaseProvider;
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/widget/scrollable_calendar/scrollable_calendar_widget.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/image_attachment/upload_image_remote.dart';

/// 선수금 제외 추가 수익 기본 라벨: `1차 잔금`, `2차 잔금`, …
/// 수익 입력은 [PlaceRevenueScreen] 쪽 `TextEditingController`에서 관리(Provider dispose와 분리).
String nextJangeumLabelForRevenueList(List<RevenueModel> list) {
  return '${list.length + 1}차 잔금';
}

class PlaceDetailState {
  const PlaceDetailState({
    required this.pid,
    required this.dateTimeRange,
    required this.toggleState,
    required this.selectedDayType,
    required this.selectedFilterType,
    required this.selectedDropdownCategory,
    required this.dialogDateTime,
    required this.revenuePickedDay,
    required this.dialogRevenuePickedDay,
    required this.photoPickedDay,
    required this.totalCostList,
    required this.revenueList,
    required this.photoGroupList,
    /// [photoGroupList]를 마지막으로 채운 `getPlacePhotoGroups`의 `photoType` (탭·새로고침 일치용).
    required this.loadedPlacePhotoType,
    required this.alertText,
    required this.isLoading,
  });

  final int pid;
  final DateTimeRange dateTimeRange;
  final List<bool> toggleState;
  final DayTpye selectedDayType;
  final FilterType selectedFilterType;
  final String? selectedDropdownCategory;
  final DateTime dialogDateTime;

  /// 추가 수익 등록용. `null`이면 아직 캘린더에서 날짜를 확정하지 않은 상태.
  final DateTime? revenuePickedDay;
  final DateTime dialogRevenuePickedDay;
  final DateTime photoPickedDay;
  final List<TotalCostModel> totalCostList;
  final List<RevenueModel> revenueList;
  final List<PlacePhotoGroupModel> photoGroupList;
  final String loadedPlacePhotoType;
  final String alertText;
  final bool isLoading;

  factory PlaceDetailState.initial(int pid) => PlaceDetailState(
        pid: pid,
        dateTimeRange: getMonthDateRange(DateTime.now()),
        toggleState: const [false, false, true],
        selectedDayType: DayTpye.month,
        selectedFilterType: FilterType.all,
        selectedDropdownCategory: null,
        dialogDateTime: DateTime.now(),
        revenuePickedDay: null,
        dialogRevenuePickedDay: DateTime.now(),
        photoPickedDay: DateTime.now(),
        totalCostList: const [],
        revenueList: const [],
        photoGroupList: const [],
        loadedPlacePhotoType: 'site',
        alertText: '',
        isLoading: false,
      );

  PlaceDetailState copyWith({
    DateTimeRange? dateTimeRange,
    List<bool>? toggleState,
    DayTpye? selectedDayType,
    FilterType? selectedFilterType,
    String? selectedDropdownCategory,
    DateTime? dialogDateTime,
    DateTime? revenuePickedDay,
    bool setRevenuePicked = false,
    DateTime? dialogRevenuePickedDay,
    DateTime? photoPickedDay,
    List<TotalCostModel>? totalCostList,
    List<RevenueModel>? revenueList,
    List<PlacePhotoGroupModel>? photoGroupList,
    String? loadedPlacePhotoType,
    String? alertText,
    bool? isLoading,
  }) {
    return PlaceDetailState(
      pid: pid,
      dateTimeRange: dateTimeRange ?? this.dateTimeRange,
      toggleState: toggleState ?? this.toggleState,
      selectedDayType: selectedDayType ?? this.selectedDayType,
      selectedFilterType: selectedFilterType ?? this.selectedFilterType,
      selectedDropdownCategory:
          selectedDropdownCategory ?? this.selectedDropdownCategory,
      dialogDateTime: dialogDateTime ?? this.dialogDateTime,
      revenuePickedDay:
          setRevenuePicked ? revenuePickedDay : this.revenuePickedDay,
      dialogRevenuePickedDay:
          dialogRevenuePickedDay ?? this.dialogRevenuePickedDay,
      photoPickedDay: photoPickedDay ?? this.photoPickedDay,
      totalCostList: totalCostList ?? this.totalCostList,
      revenueList: revenueList ?? this.revenueList,
      photoGroupList: photoGroupList ?? this.photoGroupList,
      loadedPlacePhotoType:
          loadedPlacePhotoType ?? this.loadedPlacePhotoType,
      alertText: alertText ?? this.alertText,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final workCostRepositoryProvider = Provider<WorkCostRepository>(
  (ref) => WorkCostRepositoryImpl(ref.read(superAdminRemoteRepositoryProvider)),
);
final workCostUseCaseProvider = Provider<WorkCostUseCase>(
  (ref) => WorkCostUseCase(ref.read(workCostRepositoryProvider)),
);

final materialCostRepositoryProvider = Provider<MaterialCostRepository>(
  (ref) =>
      MaterialCostRepositoryImpl(ref.read(superAdminRemoteRepositoryProvider)),
);
final materialCostUseCaseProvider = Provider<MaterialCostUseCase>(
  (ref) => MaterialCostUseCase(ref.read(materialCostRepositoryProvider)),
);

final revenueRepositoryProvider = Provider<RevenueRepository>(
  (ref) => RevenueRepositoryImpl(ref.read(superAdminRemoteRepositoryProvider)),
);
final revenueUseCaseProvider = Provider<RevenueUseCase>(
  (ref) => RevenueUseCase(ref.read(revenueRepositoryProvider)),
);

final placeDetailProvider =
    NotifierProvider.family<PlaceDetailViewModel, PlaceDetailState, int>(
  PlaceDetailViewModel.new,
);

class PlaceDetailViewModel extends Notifier<PlaceDetailState> {
  PlaceDetailViewModel(this.pid);

  final int pid;
  late final _placeUseCase = ref.read(placeUseCaseProvider);
  late final _revenueUseCase = ref.read(revenueUseCaseProvider);
  late final _workCostUseCase = ref.read(workCostUseCaseProvider);
  late final _materialCostUseCase = ref.read(materialCostUseCaseProvider);

  bool _initialized = false;
  int _photoFetchToken = 0;

  // 수익(추가/수정) TextEditingController는 [PlaceRevenueScreen] State에서 수명 관리(Provider와 분리)
  final TextEditingController mNameController = TextEditingController();
  final TextEditingController mPriceController = TextEditingController();
  final TextEditingController photoTitleController = TextEditingController();
  final TextEditingController photoUrlsController = TextEditingController();

  @override
  PlaceDetailState build() {
    ref.onDispose(() {
      mNameController.dispose();
      mPriceController.dispose();
      photoTitleController.dispose();
      photoUrlsController.dispose();
    });

    if (!_initialized) {
      _initialized = true;
      Future.microtask(() async {
        // 작업자는 전역 work-cost / revenue 조회 API가 막혀 있을 수 있음.
        // 사진 등 일부 화면만 쓸 때 불필요한 403·예외를 막기 위해 로드하지 않는다.
        final worker =
            ref.read(authSessionProvider).asData?.value?.isWorker ?? false;
        if (!worker) {
          await fetchTotalCostFromPlace();
          await fetchAllRevenueFromPlace();
        }
        // 문서 탭 종류(site/drawing/estimate)는 [PlaceImagesScreen] 등 각 화면에서
        // 첫 진입 시점의 탭에 맞춰 fetch한다. 여기서 site를 강제로 불러오면
        // 사용자가 도면 탭으로 바꾼 직후 비동기로 site 결과가 덮어씌워진다.
      });
    }
    return PlaceDetailState.initial(pid);
  }

  void setDialogDateTime(DateTime value) {
    state = state.copyWith(dialogDateTime: value);
  }

  void setRevenuePickedDay(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    state = state.copyWith(
      revenuePickedDay: d,
      setRevenuePicked: true,
    );
  }

  void setDialogRevenuePickedDay(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    state = state.copyWith(dialogRevenuePickedDay: d);
  }

  void setPhotoPickedDay(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    state = state.copyWith(photoPickedDay: d);
  }

  void clearAlertText() {
    state = state.copyWith(alertText: '');
  }

  Future<DateTimeRange?> _pickRangeWithScrollableCalendar(
    BuildContext context,
  ) async {
    // 다이얼로그는 항상 초기화된 상태(미선택)로 시작해
    // 다른 화면에서 사용한 범위가 남아 보이지 않도록 한다.
    DateTime? rangeStart;
    DateTime? rangeEnd;
    return showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) {
        final screenH = MediaQuery.sizeOf(ctx).height;
        final maxHeight = (screenH * 0.66).clamp(420.0, 560.0).toDouble();
        final calHeight = (screenH * 0.36).clamp(250.0, 320.0).toDouble();
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '기간 선택',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ScrollableCalendarWidget(
                        height: calHeight,
                        initialRangeStart: rangeStart,
                        initialRangeEnd: rangeEnd,
                        showViewModeToggle: false,
                        showRangeSummarySection: false,
                        disableDateSelectionHighlight: true,
                        onRangeChanged: (s, e) {
                          rangeStart = s;
                          rangeEnd = e;
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () {
                              final s = rangeStart;
                              if (s == null) {
                                Navigator.of(ctx).pop();
                                return;
                              }
                              final e = rangeEnd ?? s;
                              final normalized = s.isBefore(e)
                                  ? DateTimeRange(start: s, end: e)
                                  : DateTimeRange(start: e, end: s);
                              Navigator.of(ctx).pop(normalized);
                            },
                            child: const Text('확인'),
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
  }

  // ===== computed (기존 controller getter 대체) =====

  List<TotalCostModel> get rangeFilterList => state.totalCostList
      .where((e) =>
          e.getDateTime.isAfter(state.dateTimeRange.start
              .subtract(const Duration(microseconds: 1))) &&
          e.getDateTime
              .isBefore(state.dateTimeRange.end.add(const Duration(days: 1))))
      .toList();

  int get totalPrice => rangeFilterList.fold(0, (sum, e) => sum + e.price);

  int get totalRevenue => state.revenueList.fold(0, (sum, e) => sum + e.rprice);

  List<TotalCostModel> get filteredTotalCostList {
    switch (state.selectedFilterType) {
      case FilterType.all:
        return rangeFilterList;
      case FilterType.work:
        return rangeFilterList.where((e) => e.category == 'w').toList()
          ..sort((a, b) => a.wcomplete.compareTo(b.wcomplete));
      case FilterType.material:
        return rangeFilterList.where((e) => e.category != 'w').toList();
      case FilterType.notPay:
        return rangeFilterList.where((e) => e.wcomplete == 0).toList();
      default:
        return rangeFilterList
            .where((e) => e.category == state.selectedFilterType.category)
            .toList();
    }
  }

  int get selectedPrice =>
      filteredTotalCostList.fold(0, (sum, e) => sum + e.price);

  // ===== actions =====

  /// 비용 화면에서 수익 화면으로 갔다 돌아올 때: 날짜만 초기화(입력 필드는 수익 화면 dispose로 끊김).
  void clearRevenuePickedOnLeaveRevenueScreen() {
    state = state.copyWith(
      revenuePickedDay: null,
      setRevenuePicked: true,
    );
  }

  void _resetRevenueFormAfterInsert() {
    state = state.copyWith(
      revenuePickedDay: null,
      setRevenuePicked: true,
    );
  }

  void dropDownCategoryChangeAction(String value) {
    state = state.copyWith(selectedDropdownCategory: value);
  }

  void changeFilterType(FilterType filterType) {
    state = state.copyWith(selectedFilterType: filterType);
  }

  Future<void> fetchTotalCostFromPlace() async {
    if (ref.read(authSessionProvider).asData?.value?.isWorker ?? false) {
      state = state.copyWith(totalCostList: const [], isLoading: false);
      return;
    }
    state = state.copyWith(isLoading: true);
    final list = await _placeUseCase.getTotalCostsForPlace(pid);
    state = state.copyWith(totalCostList: list, isLoading: false);
  }

  Future<void> fetchAllRevenueFromPlace() async {
    if (ref.read(authSessionProvider).asData?.value?.isWorker ?? false) {
      state = state.copyWith(revenueList: const []);
      return;
    }
    final list = await _revenueUseCase.getAllRevenues(pid);
    state = state.copyWith(revenueList: list);
  }

  /// [FetchData.fetchAllData]용: `invalidate`로 notifier를 끊지 않고 목록·비용·사진만 다시 읽는다. (TextEditingController 유지)
  Future<void> refreshForGlobalFetch() async {
    final worker =
        ref.read(authSessionProvider).asData?.value?.isWorker ?? false;
    if (!worker) {
      await fetchTotalCostFromPlace();
      await fetchAllRevenueFromPlace();
    }
    await fetchPlacePhotoGroups(photoType: state.loadedPlacePhotoType);
  }

  Future<void> deleteRevenue({required int rid}) async {
    await _revenueUseCase.deleteRevenue(rid, pid);
    await fetchAllRevenueFromPlace();
  }

  Future<void> fetchPlacePhotoGroups({required String photoType}) async {
    final fetchToken = ++_photoFetchToken;
    var groups = await _placeUseCase.getPlacePhotoGroups(
      pid,
      photoType: photoType,
    );
    groups = await _enrichPhotoAuthors(groups);
    if (fetchToken != _photoFetchToken) return;
    state = state.copyWith(
      photoGroupList: groups,
      loadedPlacePhotoType: photoType,
    );
  }

  Future<List<PlacePhotoGroupModel>> _enrichPhotoAuthors(
    List<PlacePhotoGroupModel> groups,
  ) async {
    final me = ref.read(authSessionProvider).asData?.value;
    final names = <String, String>{};
    if (me != null && me.uid.isNotEmpty && me.uname.isNotEmpty) {
      names[me.uid] = me.uname;
    }

    final toFetch = <String>{};
    for (final g in groups) {
      for (final p in g.photos) {
        final u = p.createdByUid;
        if (u == null || u.isEmpty) continue;
        final inline = p.authorDisplayName?.trim();
        if (inline != null && inline.isNotEmpty) continue;
        if (!names.containsKey(u)) toFetch.add(u);
      }
    }

    if (toFetch.isNotEmpty) {
      final api = UsersRemoteApi(AppHttpClient.I);
      for (final u in toFetch) {
        try {
          final user = await api.get(u);
          names[u] = user.uname;
        } catch (_) {}
      }
    }

    return groups
        .map(
          (g) => PlacePhotoGroupModel(
            pgid: g.pgid,
            pid: g.pid,
            photoDate: g.photoDate,
            photoType: g.photoType,
            title: g.title,
            sortOrder: g.sortOrder,
            createdAtMs: g.createdAtMs,
            photos: g.photos.map(
              (e) {
                final uid = e.createdByUid;
                var display = e.authorDisplayName?.trim();
                if (display == null || display.isEmpty) {
                  if (uid != null && uid.isNotEmpty) {
                    display = names[uid];
                  }
                }
                return PlacePhotoEntry(
                  phid: e.phid,
                  displayUrl: e.displayUrl,
                  originalName: e.originalName,
                  createdByUid: e.createdByUid,
                  authorDisplayName: display,
                  memo: e.memo,
                );
              },
            ).toList(),
          ),
        )
        .toList();
  }

  Future<void> deletePlacePhotoGroup(int pgid,
      {required String photoType}) async {
    await _placeUseCase.deletePlacePhotoGroup(pgid, pid: pid);
    await fetchPlacePhotoGroups(photoType: photoType);
  }

  Future<String?> patchPlacePhotoMemo({
    required int phid,
    required String memo,
    required String photoType,
  }) =>
      patchPlacePhoto(
        phid: phid,
        memo: memo,
        photoType: photoType,
      );

  /// 메모 수정·선택적으로 로컬에서 새 파일 업로드 후 이미지 URL 교체.
  /// 성공 시 `null`, 실패 시 스낵바용 문구.
  Future<String?> patchPlacePhoto({
    required int phid,
    required String photoType,
    required String memo,
    String? replacementLocalPath,
  }) async {
    try {
      String? displayUrl;
      String? originalUrl;
      String? originalname;
      final rp = replacementLocalPath?.trim();
      if (rp != null && rp.isNotEmpty) {
        final up = await uploadLocalImageFile(
          rp,
          category: ImageUploadCategory.fromPlacePhotoType(photoType),
        );
        displayUrl = up.displayUrl;
        originalUrl = up.originalUrl;
        originalname = up.originalname;
      }
      await _placeUseCase.patchPlacePhoto(
        phid,
        memo: memo,
        displayUrl: displayUrl,
        originalUrl: originalUrl,
        originalname: originalname,
      );
      await fetchPlacePhotoGroups(photoType: photoType);
      return null;
    } catch (e) {
      final h = unwrapHttpClientException(e);
      return h?.message ?? e.toString();
    }
  }

  /// 묶음 작업명·작업일(yyyy-MM-dd) 수정.
  Future<String?> patchPlacePhotoGroupMeta({
    required int pgid,
    required String photoType,
    String? title,
    String? photoDate,
  }) async {
    try {
      await _placeUseCase.patchPlacePhotoGroupMeta(
        pgid,
        title: title,
        photoDate: photoDate,
      );
      await fetchPlacePhotoGroups(photoType: photoType);
      return null;
    } catch (e) {
      final h = unwrapHttpClientException(e);
      return h?.message ?? e.toString();
    }
  }

  Future<void> addPlacePhotoGroup({required String photoType}) async {
    final title = photoTitleController.text.trim();
    final urls = photoUrlsController.text
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (urls.isEmpty) {
      state = state.copyWith(alertText: '이미지 URL을 한 개 이상 입력해주세요.');
      return;
    }
    state = state.copyWith(alertText: '');
    await _placeUseCase.insertPlacePhotoGroup(
      pid: pid,
      photoDate: formatDateTimeToIsoDate(state.photoPickedDay),
      photoType: photoType,
      title: title.isEmpty ? '사진 묶음' : title,
      photoUrls: urls,
    );
    photoTitleController.clear();
    photoUrlsController.clear();
    await fetchPlacePhotoGroups(photoType: photoType);
  }

  /// 기기에서 고른 이미지 경로를 업로드 후 `PlacePhoto` 행으로 저장. 실패 시 안내 문구.
  Future<String?> addPlacePhotoGroupFromDeviceFiles({
    required String photoType,
    required DateTime photoDate,
    required List<String> localPaths,
    List<String>? memosPerFile,
  }) async {
    if (localPaths.isEmpty) {
      return '첨부된 이미지가 없습니다.';
    }
    final title = photoTitleController.text.trim();
    state = state.copyWith(alertText: '');
    try {
      await _placeUseCase.insertPlacePhotoGroupFromDeviceFiles(
        pid: pid,
        photoDate: formatDateTimeToIsoDate(photoDate),
        photoType: photoType,
        title: title.isEmpty ? '사진 묶음' : title,
        localFilePaths: localPaths,
        memosPerFile: memosPerFile,
      );
      photoTitleController.clear();
      photoUrlsController.clear();
      await fetchPlacePhotoGroups(photoType: photoType);
      return null;
    } on HttpClientException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> updateRevenue({
    required int rid,
    required String rname,
    required int rprice,
    required DateTime revenueDate,
  }) async {
    final model = RevenueModel(
      rid: rid,
      rpid: -1,
      rname: rname.trim().isEmpty ? '수익금' : rname.trim(),
      rprice: rprice,
      rorder: -1,
      rdate: formatDateTimeToIsoDate(revenueDate),
    );
    await _revenueUseCase.updateRevenue(revenue: model, placeId: state.pid);
    await fetchAllRevenueFromPlace();
  }

  /// 성공 시 `null`, 실패 시 안내 문구(스낵바 등에 사용).
  /// [rnameOrEmpty]·[rpriceRaw]는 수익 화면 `TextEditingController`에서 전달.
  Future<String?> insertRevenue({
    required String rnameOrEmpty,
    required String rpriceRaw,
  }) async {
    if (state.revenuePickedDay == null) {
      return '날짜를 선택해주세요';
    }
    final priceTokens = rpriceRaw.trim().replaceAll(RegExp(r'[,원]'), '');
    if (priceTokens.isEmpty) {
      return '수익금을 입력해주세요';
    }
    final rprice = int.tryParse(priceTokens) ?? 0;
    final trimmedName = rnameOrEmpty.trim();
    final rname = trimmedName.isEmpty
        ? nextJangeumLabelForRevenueList(state.revenueList)
        : trimmedName;

    await _revenueUseCase.insertRevenue(
      pid: pid,
      rprice: rprice,
      rname: rname,
      rdate: formatDateTimeToIsoDate(state.revenuePickedDay!),
    );
    await fetchAllRevenueFromPlace();
    _resetRevenueFormAfterInsert();
    return null;
  }

  Future<void> deleteCost(String category, int id) async {
    if (category == 'w') {
      await _workCostUseCase.deleteWorkCost(id);
    } else {
      await _materialCostUseCase.deleteMaterialCost(id);
    }
    await fetchTotalCostFromPlace();
  }

  /// 인건비와 같은 날·현장·인력의 작업 투입(place-work-days) 연결 여부.
  Future<int?> placeWorkDayPwdidForWorkCost(TotalCostModel item) {
    final hid = item.whid;
    final pid = item.wpid ?? state.pid;
    if (hid == null || pid <= 0) return Future.value(null);
    final dateKey =
        item.date.length >= 10 ? item.date.substring(0, 10) : item.date;
    return _workCostUseCase.findPlaceWorkDayPwdid(
      pid: pid,
      hid: hid,
      dateKey: dateKey,
    );
  }

  /// 인건비 삭제. [pwdid]가 있으면 작업 투입도 함께 삭제.
  Future<void> deleteWorkCostLinked({
    required int wid,
    int? pwdid,
  }) async {
    await _workCostUseCase.deleteWorkCostLinked(wid: wid, pwdid: pwdid);
    await fetchTotalCostFromPlace();
  }

  Future<void> updateCost(String category, int id, String date) async {
    String priceString = mPriceController.text.trim();
    priceString = priceString.replaceAll(RegExp(r'[,원]'), '');
    final price = int.tryParse(priceString);

    if (category != 'w') {
      if (mNameController.text.isEmpty || price == null) {
        state = state.copyWith(alertText: '모든 항목을 입력해 주세요.');
        return;
      }
      state = state.copyWith(alertText: '');
      final m = MaterialCostModel(
        mid: id,
        mname: mNameController.text.trim(),
        mdate: date,
        mcategory: state.selectedDropdownCategory!,
        mprice: price,
      );
      await _materialCostUseCase.updateMaterialCostItem(m);
      await fetchTotalCostFromPlace();
    } else {
      if (price == null) {
        state = state.copyWith(alertText: '모든 항목을 입력해 주세요.');
        return;
      }
      state = state.copyWith(alertText: '');
      final w = WorkCostModel(
        wid: id,
        wdate: date,
        wprice: price,
        wcomplete: -1,
        wpid: 1,
      );
      await _workCostUseCase.updateWorkCostItem(w);
      await fetchTotalCostFromPlace();
    }
  }

  Future<void> updateWComplete(int wcomplete, int id) async {
    await _workCostUseCase.toggleWorkCostCompletionStatus(wcomplete, id);
    await fetchTotalCostFromPlace();
  }

  Future<void> changeDateTimeRange(int index, BuildContext context) async {
    final toggle = List<bool>.from(state.toggleState);
    for (int i = 0; i < toggle.length; i++) {
      toggle[i] = i == index;
    }

    DateTimeRange nextRange = state.dateTimeRange;
    DayTpye nextType = state.selectedDayType;

    if (index == 0) {
      nextType = DayTpye.range;
      nextRange = await _pickRangeWithScrollableCalendar(context) ?? nextRange;
    } else if (index == 1) {
      nextType = DayTpye.whole;
      nextRange =
          DateTimeRange(start: DateTime(2000), end: DateTime(2099, 12, 31));
    } else {
      nextType = DayTpye.month;
      nextRange = getMonthDateRange(DateTime.now());
    }

    state = state.copyWith(
      toggleState: toggle,
      selectedDayType: nextType,
      dateTimeRange: nextRange,
    );
  }

  Future<void> exportAndSharePlaceInfoToExcel(String pname) async {
    final pid = state.pid;
    final dateTimeRange = state.dateTimeRange;

    final detailQueryResult = await _placeUseCase.getPlaceTotalCostsForCsv(
        dateTimeRange.start, dateTimeRange.end, pid);
    final summaryQueryResult = await _placeUseCase.getPlaceSummaryForCsv(pid);

    if (detailQueryResult.isEmpty) return;

    final detailCsvData = <List<dynamic>>[];
    final summaryCsvData = <List<dynamic>>[];

    detailCsvData.add(['', '현장 이름', pname]);
    detailCsvData.add([]);
    detailCsvData.add([''] + detailQueryResult.first.keys.toList());
    for (final row in detailQueryResult) {
      detailCsvData.add(['' as dynamic] + row.values.toList());
    }

    if (summaryQueryResult.isNotEmpty) {
      summaryCsvData.add(['', '현장 이름', pname]);
      summaryCsvData.add([]);
      summaryCsvData.add(['', '항목', '금액']);
      for (final row in summaryQueryResult) {
        row.forEach((key, value) {
          summaryCsvData.add(['' as dynamic] + [key, value]);
        });
        summaryCsvData.add([]);
      }
    } else {
      summaryCsvData.add(['요약 정보가 없습니다.']);
    }

    final excel = Excel.createExcel();
    final detailSheet = excel['세부 정보'];
    final summarySheet = excel['요약 정보'];
    try {
      excel.delete('Sheet1');
    } catch (_) {}

    for (int i = 0; i < detailCsvData.length; i++) {
      final row = detailCsvData[i];
      for (int j = 0; j < row.length; j++) {
        detailSheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i),
          (row[j] is String)
              ? TextCellValue(row[j].toString())
              : IntCellValue(int.tryParse(row[j].toString()) ?? 0),
        );
      }
    }

    for (int i = 0; i < summaryCsvData.length; i++) {
      final row = summaryCsvData[i];
      for (int j = 0; j < row.length; j++) {
        summarySheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i),
          (row[j] is String)
              ? TextCellValue(row[j].toString())
              : IntCellValue(int.tryParse(row[j].toString()) ?? 0),
        );
      }
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final excelFilePath =
        '${appDocDir.path}/$pname (${formatDateTimeRangeToString(dateTimeRange, periodType: state.selectedDayType)}).xlsx';
    final bytes = excel.encode();
    final excelFile = File(excelFilePath);
    await excelFile.writeAsBytes(bytes!);

    await Share.shareXFiles(
      [XFile(excelFile.path)],
      subject: '$pname (${formatDateTimeRangeToString(dateTimeRange, periodType: state.selectedDayType)})',
    );
  }
}
