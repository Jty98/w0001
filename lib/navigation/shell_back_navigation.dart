import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/navigation/place_navigation.dart';
import 'package:w0001/navigation/work_instruction_navigation.dart';
import 'package:w0001/presentation/viewmodel/add_cost_view_model.dart';

const _kExitConfirmDuration = Duration(seconds: 2);
const _kBackEventDedupWindow = Duration(milliseconds: 400);

int _lastBackEventHandledMs = 0;
DateTime? _lastShellExitRequestAt;
bool _shellBackHandling = false;

/// 탭 전환·하위 화면 진입 시 종료 대기 상태 초기화.
void resetShellExitBackRequest() {
  _lastShellExitRequestAt = null;
}

/// 하단 탭 **루트** 경로 — 여기서는 [GoRouter.pop] 대신 종료 확인을 한다.
bool isShellTabRootPath(String path) {
  return switch (path) {
    '/dashboard' ||
    '/place' ||
    '/add' ||
    '/calendar' ||
    '/work' ||
    '/profile' ||
    '/settings' =>
      true,
    _ => false,
  };
}

/// [BackButtonListener]와 [PopScope.onPopInvokedWithResult]가 같은 물리 키에
/// 연속 호출될 때 중복 처리를 막는다.
bool consumeDedupedBackEvent() {
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - _lastBackEventHandledMs < _kBackEventDedupWindow.inMilliseconds) {
    return false;
  }
  _lastBackEventHandledMs = now;
  return true;
}

/// 가장 가까운 [Navigator]에 쌓인 바텀시트·다이얼로그를 한 단계 닫는다.
///
/// [GoRouter] 페이지 스택과 달리 **모달만** 올라와 있을 때만 `canPop`이 true인
/// 경우(탭 루트 + 바텀시트)에 안전하게 동작한다. 루트 [Navigator]는 건드리지 않는다.
bool tryPopLocalNavigatorOverlay(BuildContext context) {
  final nav = Navigator.maybeOf(context);
  if (nav == null || !nav.canPop()) return false;
  nav.pop();
  return true;
}

/// 작업지시 작성처럼 [rootNavigator]에 올린 전체 화면을 한 단계 닫는다.
///
/// 브랜치 Navigator와 루트가 같으면 쉘 자체를 pop할 수 있어 건너뛴다.
bool tryPopRootNavigatorOverlay(BuildContext context) {
  final root = Navigator.maybeOf(context, rootNavigator: true);
  final local = Navigator.maybeOf(context);
  if (root == null || !root.canPop()) return false;
  if (identical(root, local)) return false;
  root.pop();
  return true;
}

/// 메인 쉘·탭 루트에서 Android 시스템 뒤로가기 / 예측 백 제스처 처리.
///
/// `true`를 반환하면 이벤트를 소비했다(앱 즉시 종료 방지).
bool handleAppShellSystemBack({
  required BuildContext context,
  required GoRouter router,
  required int shellBranchIndex,
}) {
  if (!consumeDedupedBackEvent()) return true;

  final path = router.state.uri.path;

  // 탭 루트가 아닌 스택(하위 화면·오버레이)만 pop.
  if (router.canPop() && !isShellTabRootPath(path)) {
    router.pop();
    resetShellExitBackRequest();
    return true;
  }

  if (shellBranchIndex == 1 && handlePlaceTabSystemBack(router)) {
    resetShellExitBackRequest();
    return true;
  }

  if (shellBranchIndex == 2 && consumeWorkInstructionHubBackNavigation()) {
    resetShellExitBackRequest();
    return true;
  }

  if (shellBranchIndex == 2 && consumeAddCostBackNavigation()) {
    resetShellExitBackRequest();
    return true;
  }

  final now = DateTime.now();
  if (_lastShellExitRequestAt != null &&
      now.difference(_lastShellExitRequestAt!) < _kExitConfirmDuration) {
    resetShellExitBackRequest();
    unawaited(SystemNavigator.pop());
    return true;
  }

  _lastShellExitRequestAt = now;
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('한 번 더 누르시면 앱이 종료됩니다.'),
        duration: _kExitConfirmDuration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  return true;
}

/// 각 하단 탭 **루트 화면**에 감싸서, 앱 실행 직후부터 브랜치 [Navigator]가
/// 시스템 뒤로가기로 바로 종료되지 않게 한다.
class ShellTabRootBackScope extends StatelessWidget {
  const ShellTabRootBackScope({
    super.key,
    required this.shellBranchIndex,
    required this.child,
  });

  final int shellBranchIndex;
  final Widget child;

  void _handleBack(BuildContext context) {
    if (_shellBackHandling) return;
    _shellBackHandling = true;
    try {
      final router = GoRouter.of(context);
      // 작업지시 작성 등 루트 Navigator 전체 화면이 위에 있으면 먼저 닫는다.
      if (tryPopRootNavigatorOverlay(context)) {
        consumeDedupedBackEvent();
        resetShellExitBackRequest();
        return;
      }
      // 탭 루트 + 열린 바텀시트/다이얼로그 — 브랜치 Navigator만 pop (체크리스트 FAB 등).
      if (isShellTabRootPath(router.state.uri.path) &&
          tryPopLocalNavigatorOverlay(context)) {
        resetShellExitBackRequest();
        return;
      }

      handleAppShellSystemBack(
        context: context,
        router: router,
        shellBranchIndex: shellBranchIndex,
      );
    } finally {
      _shellBackHandling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        _handleBack(context);
        return true;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleBack(context);
        },
        child: child,
      ),
    );
  }
}

/// [parentNavigatorKey] 루트 오버레이 화면용 — 예측 백 제스처에서 pop 누락 방지.
class OverlayRouteBackScope extends StatelessWidget {
  const OverlayRouteBackScope({super.key, required this.child});

  final Widget child;

  void _handleBack(BuildContext context) {
    if (_shellBackHandling) return;
    _shellBackHandling = true;
    try {
      if (!consumeDedupedBackEvent()) return;

      // 오버레이 화면 위 바텀시트 — 로컬 Navigator pop 우선.
      if (tryPopLocalNavigatorOverlay(context)) {
        resetShellExitBackRequest();
        return;
      }

      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
        resetShellExitBackRequest();
      }
    } finally {
      _shellBackHandling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        _handleBack(context);
        return true;
      },
      child: PopScope(
        canPop: GoRouter.of(context).canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBack(context);
        },
        child: child,
      ),
    );
  }
}
