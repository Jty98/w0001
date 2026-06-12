import 'package:flutter/material.dart';

/// iPhone 14·갤럭시 S23 등 일반 폰 기준 논리 shortest side (dp).
const double kDesignShortestSide = 390;

/// 작은 폰에서도 ellipsis 없이 읽히도록 하한, 큰 폰에서 과도 확대 방지.
const double kMinDeviceTextScale = 0.78;
const double kMaxDeviceTextScale = 1.18;

/// 접근성(시스템 글자 크기)과 기기 비율을 함께 반영할 때 상합.
const double kMaxCombinedTextScale = 1.4;

/// shortest side 기준 컴팩트·와이드 분기.
const double kCompactShortestSide = 360;
const double kTabletShortestSide = 600;

/// 화면 shortest side 대비 디자인 기준 글자·간격 배율.
abstract final class ResponsiveLayout {
  static double deviceTextScale(Size size) {
    final shortest = size.shortestSide;
    if (shortest <= 0) return 1;
    return (shortest / kDesignShortestSide)
        .clamp(kMinDeviceTextScale, kMaxDeviceTextScale);
  }

  static bool isCompact(Size size) => size.shortestSide < kCompactShortestSide;

  static bool isTablet(Size size) => size.shortestSide >= kTabletShortestSide;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 520;

  /// 폼·카드 최대 너비 (태블릿에서 과도한 늘어남 방지).
  static double contentMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (isTablet(MediaQuery.sizeOf(context))) return 520;
    return w;
  }

  /// [MediaQuery]에 적용할 앱 전역 [TextScaler].
  ///
  /// 시스템 접근성 배율은 유지하고, 기기 크기에 따라 추가로 비율을 맞춘다.
  static TextScaler appTextScaler(MediaQueryData mq) {
    final platform = mq.textScaler;
    final combined = platform.scale(1) * deviceTextScale(mq.size);
    return TextScaler.linear(combined).clamp(
      minScaleFactor: kMinDeviceTextScale * 0.95,
      maxScaleFactor: kMaxCombinedTextScale,
    );
  }

  /// 고정 dp 값을 기기 비율로 스케일 (패딩·아이콘·높이 등).
  static double scale(BuildContext context, double value) {
    return value * deviceTextScale(MediaQuery.sizeOf(context));
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final h = isCompact(size) ? 16.0 : 24.0;
    final v = isCompact(size) ? 16.0 : 20.0;
    return EdgeInsets.symmetric(
      horizontal: scale(context, h),
      vertical: scale(context, v),
    );
  }

  static EdgeInsets symmetric(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: scale(context, horizontal),
      vertical: scale(context, vertical),
    );
  }

  static EdgeInsets only(
    BuildContext context, {
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    return EdgeInsets.only(
      left: scale(context, left),
      top: scale(context, top),
      right: scale(context, right),
      bottom: scale(context, bottom),
    );
  }

  static EdgeInsets all(BuildContext context, double value) {
    final s = scale(context, value);
    return EdgeInsets.all(s);
  }

  static BorderRadius radius(BuildContext context, double value) {
    return BorderRadius.circular(scale(context, value));
  }
}

extension ResponsiveBuildContext on BuildContext {
  double get deviceTextScale =>
      ResponsiveLayout.deviceTextScale(MediaQuery.sizeOf(this));

  bool get isCompactDevice =>
      ResponsiveLayout.isCompact(MediaQuery.sizeOf(this));

  bool get isTabletDevice =>
      ResponsiveLayout.isTablet(MediaQuery.sizeOf(this));

  /// 디자인 dp → 기기 비율 스케일 (간격·높이·아이콘).
  double rs(double value) => ResponsiveLayout.scale(this, value);

  double rsi(double value) => rs(value);

  EdgeInsets get pagePadding => ResponsiveLayout.pagePadding(this);
}

/// [SizedBox] with scaled height only.
SizedBox rsV(BuildContext context, double height) =>
    SizedBox(height: context.rs(height));

/// [SizedBox] with scaled width only.
SizedBox rsH(BuildContext context, double width) =>
    SizedBox(width: context.rs(width));
