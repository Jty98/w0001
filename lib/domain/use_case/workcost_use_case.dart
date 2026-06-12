import 'package:w0001/domain/repository/workcost_abst.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';

class WorkCostUseCase {
  WorkCostUseCase(this._repository);

  final WorkCostRepository _repository;

  Future<List<TotalWorkCostModel>> getWorkCostsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _repository.getWorkCostsByDateRange(startDate, endDate);
  }

  Future<List<WorkCost2Model>> getWorkCostsByPlaceAndDate(
    int hid,
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) {
    return _repository.getWorkCostsByPlaceAndDate(
      hid,
      startDate,
      endDate,
      pid,
    );
  }

  Future<bool> addWorkCosts(
    List<WorkCostModel> wCostList, {
    bool acknowledgeTroublePair = false,
  }) {
    return _repository.addWorkCosts(
      wCostList,
      acknowledgeTroublePair: acknowledgeTroublePair,
    );
  }

  Future<void> updateWorkCostItem(WorkCostModel workCost) {
    return _repository.updateWorkCostItem(workCost);
  }

  Future<void> toggleWorkCostCompletionStatus(int wcomplete, int wid) {
    return _repository.toggleWorkCostCompletionStatus(wcomplete, wid);
  }

  Future<void> updateWorkCostsToComplete(List<int> widList) {
    return _repository.updateWorkCostsToComplete(widList);
  }

  Future<void> updateWorkCostPrice(int wid, int newPrice) {
    return _repository.updateWorkCostPrice(wid, newPrice);
  }

  Future<void> deleteWorkCost(int wid) {
    return _repository.deleteWorkCost(wid);
  }

  Future<int?> findPlaceWorkDayPwdid({
    required int pid,
    required int hid,
    required String dateKey,
  }) {
    return _repository.findPlaceWorkDayPwdid(
      pid: pid,
      hid: hid,
      dateKey: dateKey,
    );
  }

  Future<void> ensureWorkCostForPlaceWorkDay({
    required int pid,
    required int hid,
    required String dateKey,
    required int wprice,
    required String wrole,
  }) {
    return _repository.ensureWorkCostForPlaceWorkDay(
      pid: pid,
      hid: hid,
      dateKey: dateKey,
      wprice: wprice,
      wrole: wrole,
    );
  }

  Future<void> deleteWorkCostLinked({
    required int wid,
    int? pwdid,
  }) {
    return _repository.deleteWorkCostLinked(wid: wid, pwdid: pwdid);
  }

  Future<List<Map<String, dynamic>>> getWorkCostDetailsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _repository.getWorkCostDetailsForCsv(startDate, endDate);
  }

  Future<List<Map<String, dynamic>>> getWorkCostTotalsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _repository.getWorkCostTotalsForCsv(startDate, endDate);
  }

  Future<List<PlaceDropDownModel>> getPlacesForWorkCost(int hid) {
    return _repository.getPlacesForWorkCost(hid);
  }

  Future<List<int>> getSavedWorkDayHidsForPlaceDate({
    required int pid,
    required String dateKey,
  }) {
    return _repository.getSavedWorkDayHidsForPlaceDate(pid: pid, dateKey: dateKey);
  }
}

