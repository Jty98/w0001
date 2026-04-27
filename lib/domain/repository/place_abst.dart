import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/place_photo_group_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';

/// 현장(Place) 도메인 저장소 추상
abstract class PlaceRepository {
  Future<List<PlaceInfoModel>> getAllPlaces();
  Future<PlaceModel> insertPlace(PlaceModel place);
  Future<void> updatePlace(PlaceModel placeModel);
  Future<void> updatePlaceCompletionStatus(
    int pid,
    int pcomplete,
    String endDate,
  );
  Future<List<PlaceModel>> getIncompletePlaces();
  Future<List<TotalCostModel>> getTotalCostsForPlace(int pid);
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
  Future<void> insertPlacePhotoGroup({
    required int pid,
    required String photoDate,
    required String photoType,
    required String title,
    required List<String> photoUrls,
  });
  Future<void> deletePlacePhotoGroup(int pgid);
}
