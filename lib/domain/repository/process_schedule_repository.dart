import 'package:w0001/domain/process_schedule/process_schedule_models.dart';

/// 공정표 원격 저장소. 로컬 데모는 [ProcessScheduleLocalRepository].
abstract class ProcessScheduleRepository {
  /// `pid` 기준 조회. 없으면 빈 그리드 또는 기본 템플릿.
  Future<ProcessScheduleData> fetchForPlace({
    required int placeId,
    required DateTime gridStartFallback,
    int dayCount = 28,
  });

  /// 전체 스냅샷 저장(UPSERT). 서버 스키마에 맞게 DTO 변환은 구현체에서.
  Future<ProcessScheduleData> saveSchedule({
    required int placeId,
    required ProcessScheduleData data,
  });
}
