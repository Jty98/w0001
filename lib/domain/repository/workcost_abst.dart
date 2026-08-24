import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/data/model/work_cost_period_totals.dart';
import 'package:w0001/data/model/work_cost_worker_summary.dart';
import 'package:w0001/data/model/workcost_model.dart';

/// 인건비(WorkCost) 도메인 저장소 추상
abstract class WorkCostRepository {
  Future<List<TotalWorkCostModel>> getWorkCostsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    int? wcomplete,
    int? hid,
    int? pid,
  });

  /// 기간 집계 — footer 전용 (`GET /work-costs/totals`). 미구현 시 null.
  Future<WorkCostPeriodTotals?> getWorkCostPeriodTotals(
    DateTime startDate,
    DateTime endDate, {
    String? q,
    int? pid,
  });

  /// 인력별 요약 1페이지 (`GET /work-costs/worker-summaries`). 미구현 시 null.
  Future<PagedResult<WorkCostWorkerSummary>?> getWorkCostWorkerSummariesPage(
    ListQuery query,
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

  /// 작업지시 투입과 짝을 맞춘 인건비 생성·갱신.
  /// 같은 인력·같은 날에 이미 인건비가 있으면(다른 현장이라도) 추가 생성하지 않는다.
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

  /// 같은 날 여러 현장 중 [pidToRemove] 투입만 뺀다. 인건비(1공수)는 남은 현장에 유지.
  /// 남은 투입이 없으면 인건비도 삭제한다.
  /// 남은 인건비가 있으면 그 `wpid`, 인건비까지 지웠으면 null.
  Future<int?> unassignSameDayPlace({
    required int hid,
    required String dateKey,
    required int pidToRemove,
    required int workCostWid,
    required int workCostWpid,
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

  /// 기간 내 인건비가 있는 현장 목록(드롭다운용).
  Future<List<PlaceDropDownModel>> getPlacesForWorkCostInPeriod(
    DateTime startDate,
    DateTime endDate,
  );

  Future<List<int>> getSavedWorkDayHidsForPlaceDate({
    required int pid,
    required String dateKey,
  });
}
