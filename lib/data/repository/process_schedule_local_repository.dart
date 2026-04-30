import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/domain/repository/process_schedule_repository.dart';

/// 오프라인/테스트용. 공정·일정 **더미 없음** — 빈 그리드만 반환.
class ProcessScheduleLocalRepository implements ProcessScheduleRepository {
  @override
  Future<ProcessScheduleData> fetchForPlace({
    required int placeId,
    required DateTime gridStartFallback,
    int dayCount = 28,
  }) async {
    final start = DateTime(
      gridStartFallback.year,
      gridStartFallback.month,
      gridStartFallback.day,
    );
    return ProcessScheduleData(
      remoteScheduleId: null,
      scheduleVersion: null,
      gridStart: start,
      dayCount: dayCount,
      tasks: const [],
    );
  }

  @override
  Future<ProcessScheduleData> saveSchedule({
    required int placeId,
    required ProcessScheduleData data,
  }) async {
    return data;
  }
}
