import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/data/datasources/local/place_local_data_source.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
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
}

