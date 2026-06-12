import 'dart:convert';
import 'package:home_widget/home_widget.dart';
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

  static Future<void> updateScheduleWidget(
      List<ScheduleMemoModel> weeklyMemos) async {
    try {
      await _ensureInitialized();
      // 1주일치 데이터를 JSON으로 변환
      final data = weeklyMemos
          .map((m) => {
                'sid': m.sid,
                'title': m.title,
                'memo': m.memo,
                'taskDate': m.taskDate,
                'taskTime': m.taskTime,
                'done': m.done,
              })
          .toList();

      final jsonString = jsonEncode(data);

      // 데이터 저장
      await HomeWidget.saveWidgetData<String>('weekly_schedule', jsonString);
      // 위젯 최초 진입 기준은 항상 이번 주로 맞춘다.
      await HomeWidget.saveWidgetData<int>(_widgetWeekOffsetKey, 0);

      // 위젯 업데이트 요청
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.example.w0001.ScheduleWidgetProvider',
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
      final data = memos
          .map(
            (m) => {
              'sid': m.sid,
              'title': m.title,
              'memo': m.memo,
              'taskDate': m.taskDate,
              'taskTime': m.taskTime,
              'done': m.done,
            },
          )
          .toList();
      await HomeWidget.saveWidgetData<String>(
        _widgetSchedulePoolKey,
        jsonEncode(data),
      );
    } catch (e) {
      print('Widget schedule pool save error: $e');
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
          .where((e) => e.sid != null)
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
