import 'package:flutter/material.dart';
import 'package:w0001/data/datasources/local/dbhelper.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';

/// 현장(Place) 관련 로컬 데이터소스 (SQLite)
abstract class PlaceLocalDataSource {
  Future<List<PlaceInfoModel>> getAllPlaces();
  Future<void> insertPlace(PlaceModel place);
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
}

class PlaceLocalDataSourceImpl implements PlaceLocalDataSource {
  PlaceLocalDataSourceImpl(this._dbHelper);

  final DbHelper _dbHelper;

  @override
  Future<List<PlaceInfoModel>> getAllPlaces() {
    return _dbHelper.getAllPlaces();
  }

  @override
  Future<void> insertPlace(PlaceModel place) {
    return _dbHelper.insertPlace(place);
  }

  @override
  Future<void> updatePlace(PlaceModel placeModel) {
    return _dbHelper.updatePlace(placeModel);
  }

  @override
  Future<void> updatePlaceCompletionStatus(
    int pid,
    int pcomplete,
    String endDate,
  ) {
    return _dbHelper.updatePlaceCompletionStatus(pid, pcomplete, endDate);
  }

  @override
  Future<List<PlaceModel>> getIncompletePlaces() {
    return _dbHelper.getIncompletePlaces();
  }

  @override
  Future<List<TotalCostModel>> getTotalCostsForPlace(int pid) {
    return _dbHelper.getTotalCostsForPlace(pid);
  }

  @override
  Future<List<Map<String, dynamic>>> getPlaceSummaryForCsv(int pid) async {
    final raw = await _dbHelper.getPlaceSummaryForCsv(pid);
    return raw.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> getPlaceTotalCostsForCsv(
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) async {
    final raw = await _dbHelper.getPlaceTotalCostsForCsv(
      DateTimeRange(start: startDate, end: endDate),
      pid,
    );
    return raw.cast<Map<String, dynamic>>();
  }
}

