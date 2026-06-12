import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:w0001/navigation/place_navigation.dart';

/// 대시보드 등 [parentNavigatorKey] 루트 오버레이용 [MaterialPage].
MaterialPage<void> materialOverlayPage({
  required GoRouterState state,
  required Widget child,
}) {
  return MaterialPage<void>(
    key: state.pageKey,
    child: child,
  );
}

/// 현장 상세 **하위** 화면 — 브랜치 스택 + [PlaceRouteBackScope].
MaterialPage<void> placeBranchSubPage({
  required GoRouterState state,
  required Widget child,
}) {
  return MaterialPage<void>(
    key: state.pageKey,
    child: PlaceRouteBackScope(child: child),
  );
}
