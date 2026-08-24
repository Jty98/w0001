import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/navigation/shell_back_navigation.dart';

/// `/place/detail/...` 하위(공지·공정표 등) 경로인지.
bool isPlaceDetailSubPath(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  return segments.length >= 3 &&
      segments[0] == 'place' &&
      segments[1] == 'detail';
}

/// 현장 상세·하위 화면 뒤로 — [GoRouter] 스택 기준(쉘 [Navigator.maybePop]과 분리).
Future<void> popPlaceRoute(BuildContext context) async {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }
  final path = router.state.uri.path;
  if (path == '/place/detail' || isPlaceDetailSubPath(path)) {
    router.go('/place');
  }
}

/// 하위 화면 AppBar용 — 기본 [BackButton]이 루트 [Navigator]를 pop해 앱이 종료될 수 있음.
Widget placeSubrouteBackLeading(BuildContext context) {
  return IconButton(
    icon: const BackButtonIcon(),
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => unawaited(popPlaceRoute(context)),
  );
}

/// 현장 탭에서 시스템 뒤로가기 — 브랜치 스택 기준.
///
/// `true`면 이벤트를 소비했다(앱 종료 방지).
bool handlePlaceTabSystemBack(GoRouter router) {
  final path = router.state.uri.path;

  if (isPlaceDetailSubPath(path)) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/place');
    }
    return true;
  }
  if (path == '/place/detail') {
    router.go('/place');
    return true;
  }
  return false;
}

/// 현장 상세·하위 화면용 — Android 뒤로가기 / 예측 백 제스처.
class PlaceRouteBackScope extends StatelessWidget {
  const PlaceRouteBackScope({
    super.key,
    required this.child,
    this.onBeforePop,
  });

  final Widget child;

  /// `true`를 반환하면 pop 자체를 막는다(공정표 저장 실패 등).
  final Future<bool> Function()? onBeforePop;

  Future<void> _pop(BuildContext context) async {
    if (onBeforePop != null) {
      final block = await onBeforePop!();
      if (block) return;
      if (!context.mounted) return;
    }
    await popPlaceRoute(context);
  }

  Future<void> _handleSystemBack(BuildContext context) async {
    if (!consumeDedupedBackEvent()) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    await _pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        await _handleSystemBack(context);
        return true;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          unawaited(_handleSystemBack(context));
        },
        child: child,
      ),
    );
  }
}

/// 쉘 하단 탭을 숨길 현장·상세·하위 경로.
bool shouldHideShellBottomNavForPath(String path) {
  return false;
}
