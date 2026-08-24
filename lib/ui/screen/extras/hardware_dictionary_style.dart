import 'package:flutter/material.dart';
import 'package:w0001/data/model/field_knowledge_models.dart';

abstract final class HardwareDictionaryStyle {
  static Color accentFor(HardwareDictionaryKind kind) {
    switch (kind) {
      case HardwareDictionaryKind.material:
        return const Color(0xFF2F6FED);
      case HardwareDictionaryKind.tool:
        return const Color(0xFF3D5A6C);
    }
  }

  static IconData iconForKind(HardwareDictionaryKind kind) {
    switch (kind) {
      case HardwareDictionaryKind.material:
        return Icons.inventory_2_rounded;
      case HardwareDictionaryKind.tool:
        return Icons.handyman_rounded;
    }
  }

  static IconData iconForCategory(String category) {
    switch (category) {
      case '장판/데코타일':
      case '마루/강마루':
      case '바닥 타일':
        return Icons.grid_on_rounded;
      case '벽 타일':
      case '벽지/도배지':
      case '시트지/인테리어필름':
        return Icons.wallpaper_rounded;
      case '페인트/젯소':
        return Icons.format_paint_rounded;
      case '몰딩/걸레받이':
      case '합판/MDF/PB':
      case '각목/루바':
      case '석고보드/천장재':
        return Icons.view_in_ar_rounded;
      case '문/중문':
      case '창호/샷시':
        return Icons.door_front_door_rounded;
      case '손잡이/경첩/잠금':
      case '피스/앵커/브래킷':
        return Icons.hardware_rounded;
      case '실리콘/코킹':
      case '접착제/본드':
        return Icons.opacity_rounded;
      case '단열재':
      case '방수재':
        return Icons.layers_rounded;
      case '전선/스위치/콘센트':
      case '조명기구':
        return Icons.lightbulb_outline_rounded;
      case '수전/배관부속':
      case '위생도기':
        return Icons.water_drop_outlined;
      case '드릴/임팩드라이버':
      case '함마드릴/해머드릴':
        return Icons.construction_rounded;
      case '원형톱/직쏘/컷쏘':
      case '그라인더/절단기':
      case '샌더/대패':
        return Icons.carpenter_rounded;
      case '타카/네일건':
      case '타카핀/못/피스':
        return Icons.push_pin_rounded;
      case '열풍기/글루건':
        return Icons.local_fire_department_outlined;
      case '망치/타격공구':
        return Icons.gavel_rounded;
      case '드라이버/렌치/소켓':
      case '펜치/니퍼/커터':
        return Icons.build_rounded;
      case '줄자/수평/직각자':
      case '레이저레벨/거리측정':
        return Icons.straighten_rounded;
      case '흙손/헤라/미장':
      case '타일커터/줄눈공구':
        return Icons.foundation_rounded;
      case '컴프레서/에어공구':
        return Icons.air_rounded;
      case '검전기/테스터':
        return Icons.electrical_services_rounded;
      case '사다리/작업대':
        return Icons.stairs_rounded;
      case '안전보호구':
        return Icons.health_and_safety_outlined;
      case '비트/날/디스크':
      case '배터리/충전기':
        return Icons.battery_charging_full_rounded;
      default:
        return Icons.category_outlined;
    }
  }
}
