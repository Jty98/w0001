import 'package:w0001/domain/process_schedule/process_schedule_models.dart';

/// 공정 행 식별 키 — 동일 이름의 별도 공정을 구분한다.
String processTaskKey(ProcessScheduleTask task, int index) {
  final id = task.serverId?.trim();
  if (id != null && id.isNotEmpty) return 'srv:$id';
  return 'local:$index';
}

/// 두 공정 행이 동일한지 판별 (이름만으로는 비교하지 않음).
bool isSameProcessTask(
  ProcessScheduleTask? a,
  int? aIndex,
  ProcessScheduleTask? b,
  int? bIndex,
) {
  if (a == null || b == null) return a == b;
  if (identical(a, b)) return true;
  final aId = a.serverId?.trim();
  final bId = b.serverId?.trim();
  if (aId != null && aId.isNotEmpty && bId != null && bId.isNotEmpty) {
    return aId == bId;
  }
  if (aIndex != null && bIndex != null) return aIndex == bIndex;
  return false;
}

/// 공정 이벤트 데이터 모델
class ProcessEventData {
  final ProcessScheduleTask task;
  final int taskIndex;
  final DateTime startDate;
  final DateTime endDate;
  final bool isSelected;

  ProcessEventData({
    required this.task,
    required this.taskIndex,
    required this.startDate,
    required this.endDate,
    required this.isSelected,
  });
}
