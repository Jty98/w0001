import 'package:flutter/material.dart';

/// 앱 브랜드 컬러 팔레트 (웹사이트 브랜드 가이드 기준).
///
/// 화면에 직접 노출되는 색은 4단계로 제한한다.
/// - 배경: 화이트
/// - 본문/아이콘: 다크 그레이
/// - 보조 텍스트·구분선: 라이트 그레이
/// - CTA·주요 액션: 네이비
/// - 스카이 블루([accentColor]): 선택 하이라이트·정보 강조 등 소량만 사용
abstract final class AppColors {
  // ── 이전 테마 (오렌지·브라운 톤) ──────────────────────────────────────
  // static const Color primaryColor = Color(0xFFF28C38);
  // static const Color backgroundColor = Color(0xFFFAFAFA);
  // static const Color accentColor = Color(0xFFD8B892);
  // static const Color textPrimary = Color(0xFF5A3A24);
  // static const Color textSecondary = Color(0xFF7A5230);

  /// CTA·강조 버튼·주요 액션 — Navy Blue
  static const Color primaryColor = Color(0xFF2C5487);

  /// 스캐폴드·메인 패널 — 화이트
  static const Color backgroundColor = Color(0xFFFFFFFF);

  /// 소량 강조(선택 배경·정보 뱃지 등) — Sky Blue
  static const Color accentColor = Color(0xFF8ED9F8);

  /// 본문·제목 — 선명한 다크 (가독성 우선)
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// 보조 텍스트·캡션 — 중간 그레이 (흐릿하지 않게)
  static const Color textSecondary = Color(0xFF6B7280);

  /// 구분선·비활성 테두리
  static const Color borderColor = Color(0xFFE8EAED);

  /// 섹션 내부 구분선
  static const Color dividerSubtle = Color(0xFFF0F1F3);

  /// 아이콘 뱃지·옅은 강조 배경
  static const Color iconBadgeFill = Color(0xFFEEF4FA);

  /// 내부 fill (입력·칩 등)
  static const Color surfaceMuted = Color(0xFFF7F8FA);

  /// 카드·패널·스캐폴드 배경
  static const Color cardBackground = Color(0xFFFFFFFF);
}
