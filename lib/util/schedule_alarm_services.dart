import 'dart:async';

/// [main]에서 Alarm.init·권한 처리 후 완료 표시. 일정 알람 동기화 전에 대기한다.
final scheduleAlarmServicesReady = Completer<void>();

Future<void> whenScheduleAlarmServicesReady() async {
  if (scheduleAlarmServicesReady.isCompleted) return;
  try {
    await scheduleAlarmServicesReady.future
        .timeout(const Duration(seconds: 30));
  } catch (_) {
    // init 타임아웃이어도 동기화는 시도한다.
  }
}

void completeScheduleAlarmServicesReady() {
  if (!scheduleAlarmServicesReady.isCompleted) {
    scheduleAlarmServicesReady.complete();
  }
}
