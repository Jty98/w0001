import 'dart:async';

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/stacked_toast_overlay.dart';
import 'package:w0001/util/app_toast.dart';

/// [MaterialApp] 기본 [ScaffoldMessenger]·FCM·HTTP 알림용 키.
///
/// [MaterialApp.builder] 안의 [AppScaffoldMessenger]와 **다른** 인스턴스일 수 있다.
/// 라우트 [ScaffoldMessenger.of]는 builder 안쪽 [AppScaffoldMessenger]를 사용한다.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'appScaffoldMessenger');

/// [MaterialApp.builder] 자식으로 두어 라우트의 [ScaffoldMessenger.of]가
/// MaterialApp 내장 메신저(큐) 대신 스택 토스트를 쓰게 한다.
class AppScaffoldMessenger extends ScaffoldMessenger {
  const AppScaffoldMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => AppScaffoldMessengerState();
}

class AppScaffoldMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final message = snackBarContentText(snackBar.content);
    if (message.isEmpty) {
      return _noopSnackBarController(snackBar);
    }

    final completer = Completer<SnackBarClosedReason>();
    final toastId = StackedToastController.instance.show(
      message,
      duration: _clampDuration(snackBar.duration),
      backgroundColor: snackBar.backgroundColor,
      onRemoved: () {
        if (!completer.isCompleted) {
          completer.complete(SnackBarClosedReason.timeout);
        }
      },
    );

    return _StackedSnackBarController(
      snackBar: snackBar,
      toastId: toastId,
      completer: completer,
    );
  }

  @override
  void removeCurrentSnackBar({
    SnackBarClosedReason reason = SnackBarClosedReason.remove,
  }) {
    StackedToastController.instance.dismissNewest();
  }

  @override
  void clearSnackBars() {
    StackedToastController.instance.clearAll();
  }

  @override
  void hideCurrentSnackBar(
      {SnackBarClosedReason reason = SnackBarClosedReason.hide}) {
    removeCurrentSnackBar(reason: reason);
  }

  Duration? _clampDuration(Duration? duration) {
    if (duration == null) return null;
    if (duration > AppToast.maxDuration) return AppToast.maxDuration;
    return duration;
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
      _noopSnackBarController(
    SnackBar snackBar,
  ) {
    final completer = Completer<SnackBarClosedReason>()
      ..complete(SnackBarClosedReason.remove);
    return _StackedSnackBarController(
      snackBar: snackBar,
      toastId: '',
      completer: completer,
    );
  }
}

final class _StackedSnackBarController
    implements ScaffoldFeatureController<SnackBar, SnackBarClosedReason> {
  _StackedSnackBarController({
    required this.snackBar,
    required String toastId,
    required Completer<SnackBarClosedReason> completer,
  })  : _toastId = toastId,
        _completer = completer {
    _close = () {
      if (!completer.isCompleted) {
        completer.complete(SnackBarClosedReason.remove);
      }
      if (_toastId.isNotEmpty) {
        StackedToastController.instance.dismiss(_toastId, callRemoved: false);
      }
    };
  }

  final SnackBar snackBar;
  final String _toastId;
  final Completer<SnackBarClosedReason> _completer;
  late final VoidCallback _close;

  @override
  VoidCallback get close => _close;

  @override
  Future<SnackBarClosedReason> get closed => _completer.future;

  @override
  StateSetter? get setState => null;
}
