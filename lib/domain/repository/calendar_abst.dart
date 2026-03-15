import 'package:w0001/data/model/total_cost_model.dart';

/// 캘린더 도메인 저장소 추상
abstract class CalendarRepository {
  Future<Map<String, List<String>>> getAllEvents();
  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime);
}
