import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';

/// 인건비(WorkCost) 도메인 저장소 추상
abstract class WorkCostRepository {
  Future<List<TotalWorkCostModel>> getWorkCostsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );
  Future<List<WorkCost2Model>> getWorkCostsByPlaceAndDate(
    int hid,
    DateTime startDate,
    DateTime endDate,
    int pid,
  );
  Future<bool> addWorkCosts(List<WorkCostModel> wCostList);
  Future<void> updateWorkCostItem(WorkCostModel workCost);
  Future<void> toggleWorkCostCompletionStatus(int wcomplete, int wid);
  Future<void> updateWorkCostsToComplete(List<int> widList);
  Future<void> deleteWorkCost(int wid);
  Future<List<Map<String, dynamic>>> getWorkCostDetailsForCsv(
    DateTime startDate,
    DateTime endDate,
  );
  Future<List<Map<String, dynamic>>> getWorkCostTotalsForCsv(
    DateTime startDate,
    DateTime endDate,
  );
  Future<List<PlaceDropDownModel>> getPlacesForWorkCost(int hid);
}
