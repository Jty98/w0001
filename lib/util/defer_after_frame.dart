import 'package:flutter/scheduler.dart';

/// Notifier·리스너에서 provider state를 바꿀 때, 위젯 트리 빌드가 끝난 뒤 실행합니다.
void deferAfterFrame(void Function() action) {
  SchedulerBinding.instance.addPostFrameCallback((_) => action());
}
