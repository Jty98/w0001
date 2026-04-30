import 'package:w0001/domain/cost_place_picker_filter.dart';
import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';

class PlaceUseCase {
  PlaceUseCase(this._repository);

  final PlaceRepository _repository;

  Future<List<PlaceInfoModel>> getAllPlaces() {
    return _repository.getAllPlaces();
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

  Future<List<PlaceModel>> getIncompletePlaces() {
    return _repository.getIncompletePlaces();
  }

  Future<List<PlaceModel>> getPlacesForCostPicker({
    required CostPlacePickerFilter filter,
  }) {
    return _repository.getPlacesForCostPicker(filter: filter);
  }

  Future<List<TotalCostModel>> getTotalCostsForPlace(int pid) {
    return _repository.getTotalCostsForPlace(pid);
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
  }) {
    return _repository.insertPlacePhotoGroupFromDeviceFiles(
      pid: pid,
      photoDate: photoDate,
      photoType: photoType,
      title: title,
      localFilePaths: localFilePaths,
    );
  }

  Future<void> deletePlacePhotoGroup(int pgid) {
    return _repository.deletePlacePhotoGroup(pgid);
  }
}

