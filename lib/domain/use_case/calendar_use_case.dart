import 'package:w0001/domain/repository/calendar_abst.dart';
import 'package:w0001/data/model/total_cost_model.dart';

class CalendarUseCase {
  CalendarUseCase(this._repository);

  final CalendarRepository _repository;

  Future<Map<DateTime, List<String>>> getAllEvents() {
    return _repository.getAllEvents();
  }

  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime) {
    return _repository.getTotalCostsByDate(dateTime);
  }
}

