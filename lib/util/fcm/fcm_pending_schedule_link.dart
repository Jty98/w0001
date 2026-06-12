/// FCM `placeworkday_*` 딥링크용 1회성 페이로드.
/// [WorkerScheduleScreen]이 소비할 때까지 유지된다.
class FcmPendingScheduleLink {
  const FcmPendingScheduleLink({
    required this.workdate,
    required this.pwdid,
  });

  final String workdate;
  final int pwdid;
}

FcmPendingScheduleLink? _fcmPendingScheduleLink;

void fcmSetPendingScheduleLink(FcmPendingScheduleLink? v) {
  _fcmPendingScheduleLink = v;
}

FcmPendingScheduleLink? fcmPeekPendingScheduleLink() =>
    _fcmPendingScheduleLink;

void fcmClearPendingScheduleLink() {
  _fcmPendingScheduleLink = null;
}
