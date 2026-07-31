import 'package:flutter/material.dart';

/// 문서 뷰어 전용 라우트 — iOS 뒤로 스와이프·바깥 드래그로 닫히지 않는다.
///
/// [MaterialPageRoute]는 표 가로 스크롤·핀치 제스처와 겹치며 pop 되는 경우가 있어
/// 제스처 없는 [PageRoute]를 쓴다.
final class PlaceDocumentViewerRoute<T> extends PageRoute<T> {
  PlaceDocumentViewerRoute({required this.childBuilder});

  final WidgetBuilder childBuilder;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return childBuilder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}
