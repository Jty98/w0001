import 'package:flutter/material.dart';

/// 앱 브랜드 컬러 팔레트.
/// 나중에 [ThemeData]·컴포넌트 스타일과 연결할 때 이 값들을 기준으로 맞춘다.
abstract final class AppColors {
  static const Color primaryColor = Color(0xFFF28C38);

  /// 스캐폴드·메인 패널 — 거의 흰색(중립)으로 브랜드 톤이 배경에 스며들지 않게 한다.
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color accentColor = Color(0xFFD8B892);
  static const Color textPrimary = Color(0xFF5A3A24);
  static const Color textSecondary = Color(0xFF7A5230);
}
