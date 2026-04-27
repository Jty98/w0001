import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/data/datasources/local/place_local_data_source.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';

class PlaceRepositoryImpl implements PlaceRepository {
  PlaceRepositoryImpl(this._localDataSource);

  final PlaceLocalDataSource _localDataSource;

  @override
  Future<List<PlaceInfoModel>> getAllPlaces() {
    return _localDataSource.getAllPlaces();
  }

  @override
  Future<PlaceModel> insertPlace(PlaceModel place) async {
    await _localDataSource.insertPlace(place);
    return place;
  }

  @override
  Future<void> updatePlace(PlaceModel placeModel) {
    return _localDataSource.updatePlace(placeModel);
  }

  @override
  Future<void> updatePlaceCompletionStatus(
    int pid,
    int pcomplete,
    String endDate,
  ) {
    return _localDataSource.updatePlaceCompletionStatus(
      pid,
      pcomplete,
      endDate,
    );
  }

  @override
  Future<List<PlaceModel>> getIncompletePlaces() {
    return _localDataSource.getIncompletePlaces();
  }

  @override
  Future<List<TotalCostModel>> getTotalCostsForPlace(int pid) {
    return _localDataSource.getTotalCostsForPlace(pid);
  }

  @override
  Future<List<Map<String, dynamic>>> getPlaceSummaryForCsv(int pid) async {
    return _localDataSource.getPlaceSummaryForCsv(pid);
  }

  @override
  Future<List<Map<String, dynamic>>> getPlaceTotalCostsForCsv(
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) {
    return _localDataSource.getPlaceTotalCostsForCsv(
      startDate,
      endDate,
      pid,
    );
  }

  @override
  Future<List<PlacePhotoGroupModel>> getPlacePhotoGroups(
    int pid, {
    required String photoType,
  }) {
    return _localDataSource.getPlacePhotoGroups(pid, photoType: photoType);
  }

  @override
  Future<void> insertPlacePhotoGroup({
    required int pid,
    required String photoDate,
    required String photoType,
    required String title,
    required List<String> photoUrls,
  }) {
    return _localDataSource.insertPlacePhotoGroup(
      pid: pid,
      photoDate: photoDate,
      photoType: photoType,
      title: title,
      photoUrls: photoUrls,
    );
  }

  @override
  Future<void> deletePlacePhotoGroup(int pgid) {
    return _localDataSource.deletePlacePhotoGroup(pgid);
  }
}

