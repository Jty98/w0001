import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:w0001/router/app_router.dart';
import 'package:w0001/ui/screen/alarm/alarm_ringing_screen.dart';

class AlarmRingingOverlayController {
  StreamSubscription<dynamic>? _sub;
  bool _isShowing = false;
  int? _showingAlarmId;

  void start() {
    _sub ??= Alarm.ringing.listen((_) => _onRingingChanged());
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _onRingingChanged() async {
    final alarms = Alarm.ringing.value.alarms;
    if (alarms.isEmpty) {
      return;
    }

    final alarm = alarms.first;
    if (_isShowing && _showingAlarmId == alarm.id) return;

    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    _isShowing = true;
    _showingAlarmId = alarm.id;
    try {
      if (Platform.isAndroid) {
        await showGeneralDialog<void>(
          context: ctx,
          barrierDismissible: false,
          barrierLabel: 'alarm',
          pageBuilder: (_, __, ___) => _AlarmRingingDialog(alarm: alarm),
        );
      } else {
        await showDialog<void>(
          context: ctx,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => _AlarmRingingDialog(alarm: alarm),
        );
      }
    } finally {
      _isShowing = false;
      _showingAlarmId = null;
    }
  }
}

class _AlarmRingingDialog extends StatelessWidget {
  const _AlarmRingingDialog({required this.alarm});

  final AlarmSettings alarm;

  @override
  Widget build(BuildContext context) {
    final payload = _AlarmPayload.fromRaw(alarm.payload);
    final title = payload.title ?? alarm.notificationSettings.title;
    final body = payload.memo ?? alarm.notificationSettings.body;
    final time = payload.taskTime ?? formatHm(alarm.dateTime);

    return AlarmRingingScreen(
      title: title,
      body: body,
      timeText: time,
      onStop: () async {
        await Alarm.stop(alarm.id);
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
    );
  }
}

class _AlarmPayload {
  const _AlarmPayload({
    this.title,
    this.memo,
    this.taskTime,
  });

  final String? title;
  final String? memo;
  final String? taskTime;

  factory _AlarmPayload.fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const _AlarmPayload();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return _AlarmPayload(
        title: m['title'] as String?,
        memo: m['memo'] as String?,
        taskTime: m['taskTime'] as String?,
      );
    } catch (_) {
      return const _AlarmPayload();
    }
  }
}
