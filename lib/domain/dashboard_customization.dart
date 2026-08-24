import 'package:flutter/material.dart';

enum DashboardLayoutRoleScope {
  management('management'),
  worker('worker');

  const DashboardLayoutRoleScope(this.wireValue);

  final String wireValue;

  static DashboardLayoutRoleScope? tryParse(String raw) {
    for (final value in DashboardLayoutRoleScope.values) {
      if (value.wireValue == raw) return value;
    }
    return null;
  }
}

class DashboardSectionIds {
  static const managementDailyQuote = 'management_daily_quote';
  static const managementSchedule = 'management_schedule';
  static const managementAnnouncement = 'management_announcement';
  static const managementKpi = 'management_kpi';
  static const managementChecklist = 'management_checklist';

  static const workerWelcomeBanner = 'worker_welcome_banner';
  static const workerAnnouncement = 'worker_announcement';
  static const workerEarnings = 'worker_earnings';
  static const workerTodaySchedule = 'worker_today_schedule';
  static const workerChecklist = 'worker_checklist';
}

class DashboardSectionDefinition {
  const DashboardSectionDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.allowedRoles,
    this.isRequiredByDefault = false,
    this.maxInstances = 1,
  });

  final String id;
  final String title;
  final IconData icon;
  final Set<DashboardLayoutRoleScope> allowedRoles;
  final bool isRequiredByDefault;
  final int maxInstances;
}

class DashboardLayoutEntry {
  const DashboardLayoutEntry({
    required this.sectionId,
    required this.order,
    required this.visible,
    required this.pinned,
  });

  final String sectionId;
  final int order;
  final bool visible;
  final bool pinned;

  DashboardLayoutEntry copyWith({
    String? sectionId,
    int? order,
    bool? visible,
    bool? pinned,
  }) {
    return DashboardLayoutEntry(
      sectionId: sectionId ?? this.sectionId,
      order: order ?? this.order,
      visible: visible ?? this.visible,
      pinned: pinned ?? this.pinned,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'section_id': sectionId,
        'order': order,
        'visible': visible,
        'pinned': pinned,
      };

  static DashboardLayoutEntry? tryFromJson(Map<String, dynamic> json) {
    final sectionId = json['section_id']?.toString().trim() ?? '';
    if (sectionId.isEmpty) return null;
    final orderRaw = json['order'];
    final order = orderRaw is int ? orderRaw : int.tryParse('$orderRaw');
    if (order == null || order < 0) return null;
    final visible = json['visible'] == true;
    final pinned = json['pinned'] == true;
    return DashboardLayoutEntry(
      sectionId: sectionId,
      order: order,
      visible: visible,
      pinned: pinned,
    );
  }
}

class DashboardCustomizationRegistry {
  static const List<DashboardSectionDefinition> sections = [
    DashboardSectionDefinition(
      id: DashboardSectionIds.managementDailyQuote,
      title: '오늘의 문구',
      icon: Icons.format_quote_rounded,
      allowedRoles: {DashboardLayoutRoleScope.management},
    ),
    DashboardSectionDefinition(
      id: DashboardSectionIds.managementSchedule,
      title: '일정 · 메모',
      icon: Icons.event_note_outlined,
      allowedRoles: {DashboardLayoutRoleScope.management},
      isRequiredByDefault: true,
    ),
    DashboardSectionDefinition(
      id: DashboardSectionIds.managementAnnouncement,
      title: '작업자 전체 공지',
      icon: Icons.campaign_outlined,
      allowedRoles: {DashboardLayoutRoleScope.management},
    ),
    DashboardSectionDefinition(
      id: DashboardSectionIds.managementKpi,
      title: '경영 지표',
      icon: Icons.insights_outlined,
      allowedRoles: {DashboardLayoutRoleScope.management},
    ),
    DashboardSectionDefinition(
      id: DashboardSectionIds.managementChecklist,
      title: '체크리스트',
      icon: Icons.checklist_rounded,
      allowedRoles: {DashboardLayoutRoleScope.management},
    ),
    DashboardSectionDefinition(
      id: DashboardSectionIds.workerWelcomeBanner,
      title: '인사 배너',
      icon: Icons.waving_hand_rounded,
      allowedRoles: {DashboardLayoutRoleScope.worker},
    ),
    DashboardSectionDefinition(
      id: DashboardSectionIds.workerAnnouncement,
      title: '전체 공지',
      icon: Icons.notifications_active_outlined,
      allowedRoles: {DashboardLayoutRoleScope.worker},
      isRequiredByDefault: true,
    ),
    DashboardSectionDefinition(
      id: DashboardSectionIds.workerEarnings,
      title: '근로 · 정산',
      icon: Icons.payments_outlined,
      allowedRoles: {DashboardLayoutRoleScope.worker},
    ),
    DashboardSectionDefinition(
      id: DashboardSectionIds.workerTodaySchedule,
      title: '오늘 일정',
      icon: Icons.wb_sunny_outlined,
      allowedRoles: {DashboardLayoutRoleScope.worker},
      isRequiredByDefault: true,
    ),
    DashboardSectionDefinition(
      id: DashboardSectionIds.workerChecklist,
      title: '체크리스트',
      icon: Icons.checklist_rounded,
      allowedRoles: {DashboardLayoutRoleScope.worker},
    ),
  ];

  static List<DashboardSectionDefinition> sectionsForRole(
    DashboardLayoutRoleScope role,
  ) {
    return sections
        .where((section) => section.allowedRoles.contains(role))
        .toList(growable: false);
  }

  static DashboardSectionDefinition? byId(String id) {
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  static List<DashboardLayoutEntry> defaultLayoutForRole(
    DashboardLayoutRoleScope role,
  ) {
    final defs = sectionsForRole(role);
    return List<DashboardLayoutEntry>.generate(
      defs.length,
      (index) {
        final def = defs[index];
        return DashboardLayoutEntry(
          sectionId: def.id,
          order: index,
          visible: true,
          pinned: def.isRequiredByDefault,
        );
      },
      growable: false,
    );
  }
}
