import 'package:w0001/data/model/worker_profile_model.dart';
import 'package:w0001/data/model/work_unit_preset.dart';

/// 관리자가 설정하는 현장 역할(`worker_rank`)별 기본 일당 + 공수(시간 단위) 조정.
class WorkerRankWageSettings {
  const WorkerRankWageSettings({
    required this.wagesByRank,
    this.rankOrder = const [],
    this.workUnits = WorkUnitPreset.defaults,
    this.defaultWorkUnitId = WorkUnitPreset.defaultId,
    this.updatedAtMs,
  });

  /// 역할명 → 일당(원). 미설정·0은 "기본값 없음".
  final Map<String, int> wagesByRank;

  /// 표시·적용 순서. 비어 있으면 [kWorkerRankOptions] + map에만 있는 추가 역할.
  final List<String> rankOrder;

  /// 공수(0.5·1·1.5·2) ×배율 / +가산 설정.
  final List<WorkUnitPreset> workUnits;

  /// 신규 투입·금액 생성 시 기본 공수. 보통 `1`.
  final String defaultWorkUnitId;

  final int? updatedAtMs;

  factory WorkerRankWageSettings.empty() => const WorkerRankWageSettings(
        wagesByRank: {},
      );

  factory WorkerRankWageSettings.fromJson(Map<String, dynamic> json) {
    final raw = json['wages_by_rank'] ?? json['wagesByRank'];
    final map = <String, int>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final rank = '${entry.key}'.trim();
        if (rank.isEmpty) continue;
        final v = entry.value;
        if (v is num) {
          map[rank] = v.toInt();
        } else if (v is String) {
          final n = int.tryParse(v.replaceAll(RegExp(r'\D'), ''));
          if (n != null) map[rank] = n;
        }
      }
    }
    final orderRaw = json['rank_order'] ?? json['rankOrder'];
    final order = <String>[];
    if (orderRaw is List) {
      for (final item in orderRaw) {
        final s = '$item'.trim();
        if (s.isNotEmpty && !order.contains(s)) order.add(s);
      }
    }
    final units = WorkUnitPreset.listFromJson(
      json['work_units'] ?? json['workUnits'],
    );
    final defaultIdRaw =
        '${json['default_work_unit_id'] ?? json['defaultWorkUnitId'] ?? ''}'
            .trim();
    final defaultId = defaultIdRaw.isEmpty
        ? WorkUnitPreset.defaultId
        : (units.any((u) => u.id == defaultIdRaw)
            ? defaultIdRaw
            : WorkUnitPreset.defaultId);
    final updated = json['updated_at_ms'] ?? json['updatedAtMs'];
    return WorkerRankWageSettings(
      wagesByRank: map,
      rankOrder: order,
      workUnits: units,
      defaultWorkUnitId: defaultId,
      updatedAtMs: updated is num ? updated.toInt() : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'wages_by_rank': Map<String, int>.from(wagesByRank),
        if (rankOrder.isNotEmpty) 'rank_order': List<String>.from(rankOrder),
        'work_units': workUnits.map((u) => u.toJson()).toList(),
        'default_work_unit_id': defaultWorkUnitId,
        if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      };

  WorkerRankWageSettings copyWith({
    Map<String, int>? wagesByRank,
    List<String>? rankOrder,
    List<WorkUnitPreset>? workUnits,
    String? defaultWorkUnitId,
    int? updatedAtMs,
  }) {
    return WorkerRankWageSettings(
      wagesByRank: wagesByRank ?? this.wagesByRank,
      rankOrder: rankOrder ?? this.rankOrder,
      workUnits: workUnits ?? this.workUnits,
      defaultWorkUnitId: defaultWorkUnitId ?? this.defaultWorkUnitId,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  /// 역할에 설정된 일당. 없거나 0 이하면 null.
  int? wageForRank(String rank) {
    final v = wagesByRank[rank.trim()];
    if (v == null || v <= 0) return null;
    return v;
  }

  WorkUnitPreset? workUnitById(String id) {
    final key = id.trim();
    for (final u in workUnits) {
      if (u.id == key) return u;
    }
    return null;
  }

  WorkUnitPreset get defaultWorkUnit =>
      workUnitById(defaultWorkUnitId) ??
      workUnitById(WorkUnitPreset.defaultId) ??
      WorkUnitPreset.defaults.firstWhere((u) => u.id == WorkUnitPreset.defaultId);

  /// UI·저장용 순서 목록.
  List<String> orderedRanks() {
    if (rankOrder.isNotEmpty) return List<String>.from(rankOrder);
    final extras = wagesByRank.keys
        .where((k) => !kWorkerRankOptions.contains(k))
        .toList()
      ..sort();
    return [...kWorkerRankOptions, ...extras];
  }

  /// UI·저장용 — 순서에 맞춘 일당(미입력은 0).
  Map<String, int> normalizedWages() {
    return {for (final rank in orderedRanks()) rank: wagesByRank[rank] ?? 0};
  }

  WorkerRankWageSettings withOrderedRanks(
    List<String> ranks,
    Map<String, int> wages,
  ) {
    final trimmed = <String>[];
    for (final rank in ranks) {
      final t = rank.trim();
      if (t.isEmpty || trimmed.contains(t)) continue;
      trimmed.add(t);
    }
    final wageMap = <String, int>{
      for (final rank in trimmed) rank: wages[rank] ?? 0,
    };
    return copyWith(wagesByRank: wageMap, rankOrder: trimmed);
  }

  WorkerRankWageSettings withWorkUnits(
    List<WorkUnitPreset> units, {
    String? defaultWorkUnitId,
  }) {
    final merged = WorkUnitPreset.mergeWithDefaults(units);
    final want = (defaultWorkUnitId ?? this.defaultWorkUnitId).trim();
    final resolved = merged.any((u) => u.id == want)
        ? want
        : WorkUnitPreset.defaultId;
    return copyWith(workUnits: merged, defaultWorkUnitId: resolved);
  }
}
