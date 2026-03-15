import 'package:w0001/domain/repository/place_abst.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
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
}

