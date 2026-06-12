import 'package:w0001/domain/process_schedule/process_schedule_models.dart';

/// GET/PUT `/places/{pid}/process-schedule` JSON ↔ [ProcessScheduleData].
abstract final class ProcessScheduleDto {
  static String formatGridDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime? parseGridDate(Object? raw) {
    if (raw is String) {
      final t = DateTime.tryParse(raw);
      if (t != null) {
        return DateTime(t.year, t.month, t.day);
      }
    }
    return null;
  }

  static List<int> parseDays(dynamic v) {
    if (v is! List) return [];
    final out = <int>[];
    for (final e in v) {
      if (e is num) out.add(e.toInt());
    }
    out.sort();
    return out;
  }

  static ProcessScheduleData parseGet(Map<String, dynamic> m) {
    final n = DateTime.now();
    final grid =
        parseGridDate(m['grid_start_date']) ?? DateTime(n.year, n.month, n.day);
    final dayCount = (m['day_count'] as num?)?.toInt() ?? 28;
    final version = (m['version'] as num?)?.toInt();
    final sid = m['id'] ?? m['schedule_id'];
    final rawList = m['tasks'];
    final rows = <Map<String, dynamic>>[];
    if (rawList is List) {
      for (final e in rawList) {
        if (e is Map) {
          rows.add(Map<String, dynamic>.from(e));
        }
      }
    }
    rows.sort((a, b) {
      final oa = (a['sort_order'] as num?)?.toInt() ?? 0;
      final ob = (b['sort_order'] as num?)?.toInt() ?? 0;
      return oa.compareTo(ob);
    });
    final tasks = <ProcessScheduleTask>[
      for (final o in rows)
        ProcessScheduleTask(
          serverId: o['id']?.toString(),
          name: o['name'] as String? ?? '',
          scheduledDayIndices: parseDays(o['days']),
          paletteIndex: (o['palette_index'] as num?)?.toInt() ?? 0,
        ),
    ];
    return ProcessScheduleData(
      remoteScheduleId: sid?.toString(),
      scheduleVersion: version,
      gridStart: grid,
      dayCount: dayCount,
      tasks: tasks,
    );
  }

  static Map<String, dynamic> buildPutBody(ProcessScheduleData d) {
    return <String, dynamic>{
      'grid_start_date': formatGridDate(d.gridStart),
      'day_count': d.dayCount,
      if (d.scheduleVersion != null) 'expected_version': d.scheduleVersion,
      'tasks': [
        for (var i = 0; i < d.tasks.length; i++) _taskToJson(d.tasks[i], i),
      ],
    };
  }

  static Map<String, dynamic> _taskToJson(
      ProcessScheduleTask t, int sortOrder) {
    final idNum = int.tryParse(t.serverId ?? '');
    return <String, dynamic>{
      if (idNum != null) 'id': idNum,
      'name': t.name,
      'sort_order': sortOrder,
      'palette_index': t.paletteIndex,
      'days': t.scheduledDayIndices,
    };
  }

  /// PUT 응답에 `version` 등이 있으면 반영.
  static ProcessScheduleData mergePutResponse(
    ProcessScheduleData previous,
    Map<String, dynamic> res,
  ) {
    final v = (res['version'] as num?)?.toInt();
    final sid = res['id'] ?? res['schedule_id'];
    return previous.copyWith(
      scheduleVersion: v ?? previous.scheduleVersion,
      remoteScheduleId: sid?.toString() ?? previous.remoteScheduleId,
    );
  }
}
