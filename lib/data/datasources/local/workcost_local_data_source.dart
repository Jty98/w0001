import 'package:flutter/material.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/place_dropdown_model.dart';
import 'package:w0001/data/model/total_workcost_model.dart';
import 'package:w0001/data/model/workcost_model.dart';

/// 인건비(WorkCost) 관련 로컬 데이터소스 (SQLite)
abstract class WorkCostLocalDataSource {
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

  Future<List<int>> getSavedWorkDayHidsForPlaceDate({
    required int pid,
    required String dateKey,
  });
}

class WorkCostLocalDataSourceImpl implements WorkCostLocalDataSource {
  WorkCostLocalDataSourceImpl(this._dbHelper);

  final DbHelper _dbHelper;

  @override
  Future<List<TotalWorkCostModel>> getWorkCostsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return _dbHelper.getWorkCostsByDateRange(
      DateTimeRange(start: startDate, end: endDate),
    );
  }

  @override
  Future<List<WorkCost2Model>> getWorkCostsByPlaceAndDate(
    int hid,
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) {
    return _dbHelper.getWorkCostsByPlaceAndDate(
      hid,
      DateTimeRange(start: startDate, end: endDate),
      pid,
    );
  }

  @override
  Future<bool> addWorkCosts(List<WorkCostModel> wCostList) {
    return _dbHelper.addWorkCosts(wCostList);
  }

  @override
  Future<void> updateWorkCostItem(WorkCostModel workCost) {
    return _dbHelper.updateWorkCostItem(workCost);
  }

  @override
  Future<void> toggleWorkCostCompletionStatus(int wcomplete, int wid) {
    return _dbHelper.toggleWorkCostCompletionStatus(wcomplete, wid);
  }

  @override
  Future<void> updateWorkCostsToComplete(List<int> widList) {
    return _dbHelper.updateWorkCostsToComplete(widList);
  }

  @override
  Future<void> deleteWorkCost(int wid) {
    return _dbHelper.deleteWorkCost(wid);
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkCostDetailsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final raw = await _dbHelper.getWorkCostDetailsForCsv(
      DateTimeRange(start: startDate, end: endDate),
    );
    return raw.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkCostTotalsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final raw = await _dbHelper.getWorkCostTotalsForCsv(
      DateTimeRange(start: startDate, end: endDate),
    );
    return raw.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<PlaceDropDownModel>> getPlacesForWorkCost(int hid) {
    return _dbHelper.getPlacesForWorkCost(hid);
  }

  @override
  Future<List<int>> getSavedWorkDayHidsForPlaceDate({
    required int pid,
    required String dateKey,
  }) {
    return _dbHelper.getSavedWorkDayHidsForPlaceDate(pid: pid, dateKey: dateKey);
  }
}

