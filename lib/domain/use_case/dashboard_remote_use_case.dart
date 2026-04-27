import 'package:w0001/data/model/dashboard_models.dart';
import 'package:w0001/data/model/place_info_model.dart';
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

  Future<Map<DateTime, List<String>>> calendarEvents() {
    return _repository.calendarEvents();
  }

  Future<List<PlaceInfoModel>> placesInfo() {
    return _repository.placesInfo();
  }
}
