import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/total_cost_model.dart';
import 'package:w0001/domain/repository/dashboard_remote_abst.dart';

/// [DashboardRemoteRepository] thin wrapper.
class DashboardRemoteUseCase {
  DashboardRemoteUseCase(this._repository);

  final DashboardRemoteRepository _repository;

  DashboardRemoteRepository get repository => _repository;

  Future<DashboardDataBundle> loadBundle({
    required int selectedYear,
    int? kpiYear,
    int? kpiMonth,
  }) {
    return _repository.loadBundle(
      selectedYear: selectedYear,
      kpiYear: kpiYear,
      kpiMonth: kpiMonth,
    );
  }

  Future<Map<DateTime, List<String>>> calendarEvents({
    String? from,
    String? to,
  }) {
    return _repository.calendarEvents(from: from, to: to);
  }

  Future<List<TotalCostModel>> calendarDayCosts({
    required String from,
    required String to,
  }) {
    return _repository.calendarDayCosts(from: from, to: to);
  }

  Future<List<PlaceInfoModel>> placesInfo() {
    return _repository.placesInfo();
  }
}
