import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/util/schedule_alarm_services.dart';

const _alarmNotification = NotificationSettings(
  title: '일정 알람',
  body: '등록한 일정 시간입니다.',
  stopButton: '중지',
);

DateTime? scheduleMemoAlarmFireAt(ScheduleMemoModel memo) {
  final time = memo.taskTime.trim();
  if (time.isEmpty) return null;

  final d = memo.taskDate.split('-');
  final t = time.split(':');
  if (d.length != 3 || t.length != 2) return null;

  final year = int.tryParse(d[0]);
  final month = int.tryParse(d[1]);
  final day = int.tryParse(d[2]);
  final hour = int.tryParse(t[0]);
  final minute = int.tryParse(t[1]);
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null) {
    return null;
  }

  final taskAt = DateTime(year, month, day, hour, minute);
  return taskAt.subtract(Duration(minutes: memo.alarmOffsetMinutes));
}

Future<void> syncScheduleMemoLocalAlarm(ScheduleMemoModel memo) async {
  final sid = memo.sid;
  if (sid == null || sid <= 0) return;

  await whenScheduleAlarmServicesReady();

  if (memo.done || !memo.alarmEnabled) {
    await Alarm.stop(sid);
    return;
  }

  final fireAt = scheduleMemoAlarmFireAt(memo);
  if (fireAt == null || !fireAt.isAfter(DateTime.now())) {
    await Alarm.stop(sid);
    return;
  }

  await Alarm.set(
    alarmSettings: AlarmSettings(
      id: sid,
      dateTime: fireAt,
      assetAudioPath: null,
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: Platform.isIOS,
      androidFullScreenIntent: Platform.isAndroid,
      androidStopAlarmOnTermination: !Platform.isAndroid,
      volumeSettings: VolumeSettings.fade(
        fadeDuration: const Duration(seconds: 5),
        volume: 0.9,
        volumeEnforced: false,
      ),
      notificationSettings: _alarmNotification.copyWith(
        title: memo.title.trim().isEmpty ? '일정 알람' : memo.title.trim(),
        body: memo.memo.trim().isEmpty ? '등록한 일정 시간입니다.' : memo.memo.trim(),
      ),
      payload: jsonEncode({
        'title': memo.title.trim(),
        'memo': memo.memo.trim(),
        'taskDate': memo.taskDate,
        'taskTime': memo.taskTime.trim(),
        'alarmOffsetMinutes': memo.alarmOffsetMinutes,
      }),
    ),
  );
}

Future<void> syncScheduleMemoLocalAlarmSafe(ScheduleMemoModel memo) async {
  try {
    await syncScheduleMemoLocalAlarm(memo);
  } catch (e, st) {
    debugPrint('Alarm sync failed for sid=${memo.sid}: $e\n$st');
  }
}

/// 수신함·앱 기동 후 서버 일정과 로컬 알람을 맞춘다 (직접 등록 메모만).
Future<void> syncScheduleMemoLocalAlarmsFromReads(
  Iterable<ScheduleMemoRead> memos,
) async {
  for (final r in memos) {
    if (r.isAssignment || r.sid <= 0) continue;
    await syncScheduleMemoLocalAlarmSafe(scheduleMemoReadToModel(r));
  }
}
