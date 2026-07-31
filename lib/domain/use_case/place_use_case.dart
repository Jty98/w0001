import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';

class PlaceUseCase {
  PlaceUseCase(this._repository);

  final PlaceRepository _repository;

  Future<List<PlaceInfoModel>> getAllPlaces({
    bool managementPlacesInfoFirst = true,
    UserRole? role,
  }) {
    return _repository.getAllPlaces(
      managementPlacesInfoFirst: managementPlacesInfoFirst,
      role: role,
    );
  }

  Future<PagedResult<PlaceInfoModel>> fetchPlacesPage({
    required ListQuery query,
    bool managementPlacesInfoFirst = true,
    UserRole? role,
  }) {
    return _repository.fetchPlacesPage(
      query: query,
      managementPlacesInfoFirst: managementPlacesInfoFirst,
      role: role,
    );
  }

  Future<PlaceModel> insertPlace(PlaceModel place) {
    return _repository.insertPlace(place);
  }

  Future<void> updatePlace(PlaceModel placeModel) {
    return _repository.updatePlace(placeModel);
  }

  Future<void> updatePlaceCompletionStatus(
    int pid,
    int pcomplete,
    String endDate,
  ) {
    return _repository.updatePlaceCompletionStatus(pid, pcomplete, endDate);
  }

  Future<void> deletePlace(int pid) {
    return _repository.deletePlace(pid);
  }

  Future<List<PlaceModel>> getIncompletePlaces() {
    return _repository.getIncompletePlaces();
  }

  Future<List<PlaceModel>> getPlacesForCostPicker({
    required CostPlacePickerFilter filter,
  }) {
    return _repository.getPlacesForCostPicker(filter: filter);
  }

  Future<PagedResult<PlaceModel>> fetchPlacesForCostPickerPage({
    required ListQuery query,
    required CostPlacePickerFilter filter,
    UserRole? role,
  }) {
    return _repository.fetchPlacesForCostPickerPage(
      query: query,
      filter: filter,
      role: role,
    );
  }

  Future<List<TotalCostModel>> getTotalCostsForPlace(
    int pid, {
    DateTime? from,
    DateTime? to,
  }) {
    return _repository.getTotalCostsForPlace(pid, from: from, to: to);
  }

  Future<List<Map<String, dynamic>>> getPlaceSummaryForCsv(int pid) {
    return _repository.getPlaceSummaryForCsv(pid);
  }

  Future<List<Map<String, dynamic>>> getPlaceTotalCostsForCsv(
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) {
    return _repository.getPlaceTotalCostsForCsv(startDate, endDate, pid);
  }

  Future<List<PlacePhotoGroupModel>> getPlacePhotoGroups(
    int pid, {
    required String photoType,
  }) {
    return _repository.getPlacePhotoGroups(pid, photoType: photoType);
  }

  Future<PagedResult<PlacePhotoGroupModel>> fetchPlacePhotoGroupsPage(
    int pid, {
    required String photoType,
    required ListQuery query,
  }) {
    return _repository.fetchPlacePhotoGroupsPage(
      pid,
      photoType: photoType,
      query: query,
    );
  }

  Future<void> insertPlacePhotoGroup({
    required int pid,
    required String photoDate,
    required String photoType,
    required String title,
    required List<String> photoUrls,
  }) {
    return _repository.insertPlacePhotoGroup(
      pid: pid,
      photoDate: photoDate,
      photoType: photoType,
      title: title,
      photoUrls: photoUrls,
    );
  }

  Future<void> insertPlacePhotoGroupFromDeviceFiles({
    required int pid,
    required String photoDate,
    required String photoType,
    required String title,
    required List<String> localFilePaths,
    List<String>? memosPerFile,
  }) {
    return _repository.insertPlacePhotoGroupFromDeviceFiles(
      pid: pid,
      photoDate: photoDate,
      photoType: photoType,
      title: title,
      localFilePaths: localFilePaths,
      memosPerFile: memosPerFile,
    );
  }

  Future<void> deletePlacePhotoGroup(int pgid, {int? pid}) {
    return _repository.deletePlacePhotoGroup(pgid, pid: pid);
  }

  Future<void> patchPlacePhoto(
    int phid, {
    String? memo,
    String? displayUrl,
    String? originalUrl,
    String? originalname,
  }) {
    return _repository.patchPlacePhoto(
      phid,
      memo: memo,
      displayUrl: displayUrl,
      originalUrl: originalUrl,
      originalname: originalname,
    );
  }

  Future<void> patchPlacePhotoGroupMeta(
    int pgid, {
    String? title,
    String? photoDate,
  }) {
    return _repository.patchPlacePhotoGroupMeta(pgid,
        title: title, photoDate: photoDate);
  }

  /// 기간별 일괄 인력투입
  Future<Map<String, dynamic>> bulkAssignWorkforce({
    required int pid,
    required Map<String, dynamic> requestBody,
  }) async {
    print('📚 [USE CASE] bulkAssignWorkforce 호출');
    final startTime = DateTime.now();

    final result = await _repository.bulkAssignWorkforce(
      pid: pid,
      requestBody: requestBody,
    );

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    print('📚 [USE CASE] bulkAssignWorkforce 완료: ${duration}ms');

    return result;
  }
}
