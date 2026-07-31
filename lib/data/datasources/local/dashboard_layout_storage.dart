import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:w0001/domain/dashboard_customization.dart';

class DashboardLayoutLocalSettings {
  const DashboardLayoutLocalSettings({
    required this.role,
    required this.entries,
    this.version = 1,
  });

  final DashboardLayoutRoleScope role;
  final int version;
  final List<DashboardLayoutEntry> entries;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'role': role.wireValue,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      };

  static DashboardLayoutLocalSettings? tryFromJson(Map<String, dynamic> json) {
    final roleRaw = json['role']?.toString();
    if (roleRaw == null) return null;
    final role = DashboardLayoutRoleScope.tryParse(roleRaw);
    if (role == null) return null;
    final versionRaw = json['version'];
    final version =
        versionRaw is int ? versionRaw : int.tryParse('$versionRaw') ?? 1;
    final entriesRaw = json['entries'];
    if (entriesRaw is! List) return null;
    final entries = <DashboardLayoutEntry>[];
    for (final item in entriesRaw) {
      if (item is! Map) continue;
      final entry = DashboardLayoutEntry.tryFromJson(
        Map<String, dynamic>.from(item),
      );
      if (entry != null) entries.add(entry);
    }
    return DashboardLayoutLocalSettings(
      role: role,
      entries: entries,
      version: version,
    );
  }
}

class DashboardLayoutStorage {
  static const _keyPrefix = 'dashboard_layout_v1_';

  String _keyFor({
    required String uid,
    required DashboardLayoutRoleScope role,
  }) {
    return '$_keyPrefix${uid}_${role.wireValue}';
  }

  Future<DashboardLayoutLocalSettings?> load({
    required String uid,
    required DashboardLayoutRoleScope role,
  }) async {
    if (uid.trim().isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(uid: uid, role: role));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final settings = DashboardLayoutLocalSettings.tryFromJson(decoded);
      if (settings == null || settings.role != role) return null;
      return settings;
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String uid,
    required DashboardLayoutLocalSettings settings,
  }) async {
    if (uid.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFor(uid: uid, role: settings.role),
      jsonEncode(settings.toJson()),
    );
  }

  Future<void> clear({
    required String uid,
    required DashboardLayoutRoleScope role,
  }) async {
    if (uid.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(uid: uid, role: role));
  }
}
