import 'package:w0001/data/datasources/local/workcost_local_data_source.dart';
import 'package:w0001/domain/repository/workcost_abst.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';

class WorkCostRepositoryImpl implements WorkCostRepository {
  WorkCostRepositoryImpl(this._localDataSource);

  final WorkCostLocalDataSource _localDataSource;

  @override
  Future<List<TotalWorkCostModel>> getWorkCostsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _localDataSource.getWorkCostsByDateRange(startDate, endDate);
  }

  @override
  Future<List<WorkCost2Model>> getWorkCostsByPlaceAndDate(
    int hid,
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) {
    return _localDataSource.getWorkCostsByPlaceAndDate(
      hid,
      startDate,
      endDate,
      pid,
    );
  }

  @override
  Future<bool> addWorkCosts(List<WorkCostModel> wCostList) {
    return _localDataSource.addWorkCosts(wCostList);
  }

  @override
  Future<void> updateWorkCostItem(WorkCostModel workCost) {
    return _localDataSource.updateWorkCostItem(workCost);
  }

  @override
  Future<void> toggleWorkCostCompletionStatus(int wcomplete, int wid) {
    return _localDataSource.toggleWorkCostCompletionStatus(wcomplete, wid);
  }

  @override
  Future<void> updateWorkCostsToComplete(List<int> widList) {
    return _localDataSource.updateWorkCostsToComplete(widList);
  }

  @override
  Future<void> deleteWorkCost(int wid) {
    return _localDataSource.deleteWorkCost(wid);
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkCostDetailsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _localDataSource.getWorkCostDetailsForCsv(startDate, endDate);
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkCostTotalsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _localDataSource.getWorkCostTotalsForCsv(startDate, endDate);
  }

  @override
  Future<List<PlaceDropDownModel>> getPlacesForWorkCost(int hid) {
    return _localDataSource.getPlacesForWorkCost(hid);
  }

  @override
  Future<List<int>> getSavedWorkDayHidsForPlaceDate({
    required int pid,
    required String dateKey,
  }) {
    return _localDataSource.getSavedWorkDayHidsForPlaceDate(
      pid: pid,
      dateKey: dateKey,
    );
  }
}

