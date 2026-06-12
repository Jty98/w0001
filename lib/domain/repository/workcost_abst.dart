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
  Future<bool> addWorkCosts(
    List<WorkCostModel> wCostList, {
    bool acknowledgeTroublePair = false,
  });
  Future<void> updateWorkCostItem(WorkCostModel workCost);
  Future<void> toggleWorkCostCompletionStatus(int wcomplete, int wid);
  Future<void> updateWorkCostsToComplete(List<int> widList);
  Future<void> updateWorkCostPrice(int wid, int newPrice);
  Future<void> deleteWorkCost(int wid);

  /// 같은 인력·현장·날짜의 작업 투입(`place-work-days`) pwdid. 없으면 null.
  Future<int?> findPlaceWorkDayPwdid({
    required int pid,
    required int hid,
    required String dateKey,
  });

  /// 작업지시 투입과 짝을 맞춘 인건비 생성·갱신(이미 있으면 금액·역할만 PATCH).
  Future<void> ensureWorkCostForPlaceWorkDay({
    required int pid,
    required int hid,
    required String dateKey,
    required int wprice,
    required String wrole,
  });

  /// 인건비 삭제. [pwdid]가 있으면 작업 투입도 함께 삭제.
  Future<void> deleteWorkCostLinked({
    required int wid,
    int? pwdid,
  });
  Future<List<Map<String, dynamic>>> getWorkCostDetailsForCsv(
    DateTime startDate,
    DateTime endDate,
  );
  Future<List<Map<String, dynamic>>> getWorkCostTotalsForCsv(
    DateTime startDate,
    DateTime endDate,
  );
  Future<List<PlaceDropDownModel>> getPlacesForWorkCost(int hid);

  Future<List<int>> getSavedWorkDayHidsForPlaceDate({
    required int pid,
    required String dateKey,
  });
}
