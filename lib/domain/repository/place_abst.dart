import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';

/// 현장(Place) 도메인 저장소 추상
abstract class PlaceRepository {
  /// [managementPlacesInfoFirst]가 true면 관리자 계열 현장 목록을 조회한다.
  ///
  /// * 슈퍼관리자: `/dashboard/places-info` → 실패 시 `GET /places`
  /// * 일반 관리자: `GET /places/me` (스코프 현장)
  /// * 워커: [managementPlacesInfoFirst] false → `GET /places/me`
  Future<List<PlaceInfoModel>> getAllPlaces({
    bool managementPlacesInfoFirst = true,
    UserRole? role,
  });

  /// cursor 페이지 — 현장 목록 infinite scroll.
  Future<PagedResult<PlaceInfoModel>> fetchPlacesPage({
    required ListQuery query,
    bool managementPlacesInfoFirst = true,
    UserRole? role,
  });
  Future<PlaceModel> insertPlace(PlaceModel place);
  Future<void> updatePlace(PlaceModel placeModel);
  Future<void> updatePlaceCompletionStatus(
    int pid,
    int pcomplete,
    String endDate,
  );

  /// 현장 영구 삭제 (DELETE /places/{pid})
  Future<void> deletePlace(int pid);

  Future<List<PlaceModel>> getIncompletePlaces();

  /// 금액 추가 화면 등 — [CostPlacePickerFilter] 기준 목록.
  Future<List<PlaceModel>> getPlacesForCostPicker({
    required CostPlacePickerFilter filter,
  });

  /// 금액 추가 현장 선택 — 서버 검색·cursor 페이지 (`GET /places` 또는 `/places/me`).
  Future<PagedResult<PlaceModel>> fetchPlacesForCostPickerPage({
    required ListQuery query,
    required CostPlacePickerFilter filter,
    UserRole? role,
  });
  Future<List<TotalCostModel>> getTotalCostsForPlace(
    int pid, {
    DateTime? from,
    DateTime? to,
  });
  Future<List<Map<String, dynamic>>> getPlaceSummaryForCsv(int pid);
  Future<List<Map<String, dynamic>>> getPlaceTotalCostsForCsv(
    DateTime startDate,
    DateTime endDate,
    int pid,
  );
  Future<List<PlacePhotoGroupModel>> getPlacePhotoGroups(
    int pid, {
    required String photoType,
  });

  Future<PagedResult<PlacePhotoGroupModel>> fetchPlacePhotoGroupsPage(
    int pid, {
    required String photoType,
    required ListQuery query,
  });
  Future<void> insertPlacePhotoGroup({
    required int pid,
    required String photoDate,
    required String photoType,
    required String title,
    required List<String> photoUrls,
  });

  /// 사진·도면은 [`POST /uploads/image`] 후 [`POST /place-photos`], PDF·엑셀은 [`POST /place-photos/upload`] 후 필요 시 [`POST /place-photos`].
  /// [memosPerFile]는 [localFilePaths]와 동일 길이·인덱스로 장당 초기 메모(비어 있으면 생략).
  Future<void> insertPlacePhotoGroupFromDeviceFiles({
    required int pid,
    required String photoDate,
    required String photoType,
    required String title,
    required List<String> localFilePaths,
    List<String>? memosPerFile,
  });

  Future<void> deletePlacePhotoGroup(int pgid, {int? pid});

  /// PATCH `/place-photos/{phid}` — 포함하는 필드만 전송 (`memo`, `display_url` 등).
  Future<void> patchPlacePhoto(
    int phid, {
    String? memo,
    String? displayUrl,
    String? originalUrl,
    String? originalname,
  });

  /// 묶음 작업명·업로드일 수정. PATCH `/place-photo-groups/{pgid}`.
  Future<void> patchPlacePhotoGroupMeta(
    int pgid, {
    String? title,
    String? photoDate,
  });

  /// 기간별 일괄 인력투입 (POST `/places/{pid}/workforce/bulk-assign`)
  Future<Map<String, dynamic>> bulkAssignWorkforce({
    required int pid,
    required Map<String, dynamic> requestBody,
  });
}
