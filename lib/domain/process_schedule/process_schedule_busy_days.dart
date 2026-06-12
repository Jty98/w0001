import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';

/// 공정표에서 **임의 공정이라도 막대가 있는 날** (날짜 키 `yyyy-MM-dd`).
Set<String> processScheduleBusyDateKeysIso(ProcessScheduleData data) {
  final cols = ProcessScheduleEditor.columnDates(data);
  final busyIdx = <int>{};
  for (final t in data.tasks) {
    busyIdx.addAll(t.scheduledDayIndices);
  }
  final out = <String>{};
  for (final idx in busyIdx) {
    if (idx >= 0 && idx < cols.length) {
      out.add(_isoDateKey(cols[idx]));
    }
  }
  return out;
}

String _isoDateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
