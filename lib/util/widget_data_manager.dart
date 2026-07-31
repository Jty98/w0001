import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';

class WidgetDataManager {
  static const String _groupId =
      'group.com.example.interior-workcost-app'; // Need to match iOS App Group
  static const String _androidWidgetName = 'ScheduleWidgetProvider';
  static const String _widgetWeekStartKey = 'widget_week_start';
  static const String _widgetSchedulePoolKey = 'widget_schedule_pool';
  static const String _widgetWeekOffsetKey = 'widget_week_offset';
  static const String _widgetPendingDoneUpdatesKey =
      'widget_pending_done_updates';
  static bool _isInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await HomeWidget.setAppGroupId(_groupId);
    _isInitialized = true;
  }

  static Map<String, dynamic> _memoModelToJson(ScheduleMemoModel m) => {
        'sid': m.sid,
        'title': m.title,
        'memo': m.memo,
        'taskDate': m.taskDate,
        'taskTime': m.taskTime,
        'done': m.done,
        'sourceType': 'manual',
        'workrole': '',
      };

  static Map<String, dynamic> _memoReadToJson(ScheduleMemoRead m) {
    final date =
        m.taskdate.length >= 10 ? m.taskdate.substring(0, 10) : m.taskdate;
    return {
      'sid': m.sid,
      'title': m.title,
      'memo': m.memo,
      'taskDate': date,
      'taskTime': m.tasktime,
      'done': m.done,
      'sourceType': m.sourceType,
      'workrole': m.workrole,
    };
  }

  static Future<void> _saveAndRefresh({
    required List<Map<String, dynamic>> weekly,
    required List<Map<String, dynamic>> pool,
  }) async {
    await _ensureInitialized();
    await HomeWidget.saveWidgetData<String>(
      _widgetSchedulePoolKey,
      jsonEncode(pool),
    );
    await HomeWidget.saveWidgetData<String>(
      'weekly_schedule',
      jsonEncode(weekly),
    );
    await HomeWidget.saveWidgetData<int>(_widgetWeekOffsetKey, 0);
    await HomeWidget.updateWidget(
      qualifiedAndroidName:
          'com.example.interior_work_cost_app.ScheduleWidgetProvider',
      name: _androidWidgetName,
      androidName: _androidWidgetName,
      iOSName: 'ScheduleWidget',
    );
  }

  static Future<void> updateScheduleWidget(
      List<ScheduleMemoModel> weeklyMemos) async {
    try {
      await _ensureInitialized();
      final data = weeklyMemos.map(_memoModelToJson).toList();
      await HomeWidget.saveWidgetData<String>(
          'weekly_schedule', jsonEncode(data));
      await HomeWidget.saveWidgetData<int>(_widgetWeekOffsetKey, 0);
      await HomeWidget.updateWidget(
        qualifiedAndroidName:
            'com.example.interior_work_cost_app.ScheduleWidgetProvider',
        name: _androidWidgetName,
        androidName: _androidWidgetName,
        iOSName: 'ScheduleWidget',
      );
    } catch (e) {
      print('Widget update error: $e');
    }
  }

  static Future<void> saveSchedulePool(List<ScheduleMemoModel> memos) async {
    try {
      await _ensureInitialized();
      final data = memos.map(_memoModelToJson).toList();
      await HomeWidget.saveWidgetData<String>(
        _widgetSchedulePoolKey,
        jsonEncode(data),
      );
    } catch (e) {
      print('Widget schedule pool save error: $e');
    }
  }

  /// 작업자 「내 일정」+ 현장투입 행을 위젯에 반영.
  static Future<void> syncWorkerScheduleReads(
    List<ScheduleMemoRead> all, {
    required DateTime weekMonday,
    int weekRadius = 4,
  }) async {
    try {
      final mon = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
      final weekEnd = mon.add(const Duration(days: 6));
      final poolFrom = mon.subtract(Duration(days: 7 * weekRadius));
      final poolTo = mon.add(Duration(days: 7 * weekRadius + 6));

      bool inRange(String raw, DateTime from, DateTime to) {
        final key = raw.length >= 10 ? raw.substring(0, 10) : raw;
        final d = DateTime.tryParse(key);
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        return !day.isBefore(from) && !day.isAfter(to);
      }

      final pool = all
          .where((m) => inRange(m.taskdate, poolFrom, poolTo))
          .map(_memoReadToJson)
          .toList();
      final weekly = all
          .where((m) => inRange(m.taskdate, mon, weekEnd))
          .map(_memoReadToJson)
          .toList();
      await _saveAndRefresh(weekly: weekly, pool: pool);
    } catch (e) {
      print('Widget worker schedule sync error: $e');
    }
  }

  static Future<void> saveWidgetWeekStart(String isoMondayDate) async {
    try {
      await _ensureInitialized();
      await HomeWidget.saveWidgetData<String>(
          _widgetWeekStartKey, isoMondayDate);
      await HomeWidget.saveWidgetData<int>(_widgetWeekOffsetKey, 0);
    } catch (e) {
      print('Widget week save error: $e');
    }
  }

  static Future<String?> getWidgetWeekStart() async {
    try {
      await _ensureInitialized();
      return await HomeWidget.getWidgetData<String>(_widgetWeekStartKey);
    } catch (e) {
      print('Widget week read error: $e');
      return null;
    }
  }

  static Future<void> clearWidgetWeekStart() async {
    try {
      await _ensureInitialized();
      await HomeWidget.saveWidgetData<String>(_widgetWeekStartKey, '');
      await HomeWidget.saveWidgetData<int>(_widgetWeekOffsetKey, 0);
    } catch (e) {
      print('Widget week clear error: $e');
    }
  }

  static Future<List<WidgetDoneUpdate>> consumePendingDoneUpdates() async {
    try {
      await _ensureInitialized();
      final raw = await HomeWidget.getWidgetData<String>(
              _widgetPendingDoneUpdatesKey) ??
          '[]';
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final updates = decoded
          .whereType<Map>()
          .map((e) => WidgetDoneUpdate.fromMap(e.cast<String, dynamic>()))
          .where((e) => e.sid != null && e.sid! > 0)
          .toList();
      await HomeWidget.saveWidgetData<String>(
          _widgetPendingDoneUpdatesKey, '[]');
      return updates;
    } catch (e) {
      print('Widget done updates read error: $e');
      return const [];
    }
  }
}

class WidgetDoneUpdate {
  const WidgetDoneUpdate({
    required this.sid,
    required this.done,
  });

  final int? sid;
  final bool done;

  factory WidgetDoneUpdate.fromMap(Map<String, dynamic> map) {
    return WidgetDoneUpdate(
      sid: _asInt(map['sid']),
      done: map['done'] == true || map['done'] == 1,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
