/// 공수 금액 조정 방식.
enum WorkUnitAdjustMode {
  /// 기준 일당 × value
  multiply,

  /// 기준 일당 + value(원)
  add,
}

extension WorkUnitAdjustModeX on WorkUnitAdjustMode {
  String get apiValue => switch (this) {
        WorkUnitAdjustMode.multiply => 'multiply',
        WorkUnitAdjustMode.add => 'add',
      };

  String get symbol => switch (this) {
        WorkUnitAdjustMode.multiply => '×',
        WorkUnitAdjustMode.add => '+',
      };

  static WorkUnitAdjustMode fromJson(dynamic raw) {
    final s = '$raw'.trim().toLowerCase();
    if (s == 'add' || s == 'plus' || s == '+') {
      return WorkUnitAdjustMode.add;
    }
    return WorkUnitAdjustMode.multiply;
  }
}

/// 일한 시간 단위(공수) — 기준 일당(1공수)에 ×배율 또는 +가산액 적용.
class WorkUnitPreset {
  const WorkUnitPreset({
    required this.id,
    required this.label,
    required this.adjustMode,
    required this.value,
  });

  /// 안정적인 식별자 (`0.5`, `1`, `1.5`, `2` …).
  final String id;

  /// UI 표시명 (`0.5공수`, `1공수` …).
  final String label;

  /// × 배율 / + 원 가산.
  final WorkUnitAdjustMode adjustMode;

  /// [adjustMode]가 multiply면 배율, add면 가산 금액(원).
  final double value;

  /// 하위 호환 — multiply일 때 배율.
  double get multiplier =>
      adjustMode == WorkUnitAdjustMode.multiply ? value : 1;

  /// 하위 호환 — add일 때 가산액(원).
  int get addAmount =>
      adjustMode == WorkUnitAdjustMode.add ? value.round() : 0;

  static const String defaultId = '1';

  /// 이전에 쓰던 야간 등 — 병합 시 제거.
  static const Set<String> _removedIds = {'night'};

  static const List<WorkUnitPreset> defaults = [
    WorkUnitPreset(
      id: '0.5',
      label: '0.5공수',
      adjustMode: WorkUnitAdjustMode.multiply,
      value: 0.5,
    ),
    WorkUnitPreset(
      id: '1',
      label: '1공수',
      adjustMode: WorkUnitAdjustMode.multiply,
      value: 1,
    ),
    WorkUnitPreset(
      id: '1.5',
      label: '1.5공수',
      adjustMode: WorkUnitAdjustMode.multiply,
      value: 1.5,
    ),
    WorkUnitPreset(
      id: '2',
      label: '2공수',
      adjustMode: WorkUnitAdjustMode.multiply,
      value: 2,
    ),
  ];

  factory WorkUnitPreset.fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? ''}'.trim();
    var label = '${json['label'] ?? json['name'] ?? ''}'.trim();
    // 이전 "품" 라벨 → 공수
    if (label.contains('품')) {
      label = label.replaceAll('품', '공수');
    }
    final mode = WorkUnitAdjustModeX.fromJson(
      json['adjust_mode'] ?? json['adjustMode'] ?? json['mode'],
    );
    final rawValue = json['value'] ??
        json['multiplier'] ??
        json['rate'] ??
        json['factor'] ??
        json['add_amount'] ??
        json['addAmount'];
    double parsed = mode == WorkUnitAdjustMode.multiply ? 1 : 0;
    if (rawValue is num) {
      parsed = rawValue.toDouble();
    } else if (rawValue is String) {
      parsed = double.tryParse(rawValue.trim().replaceAll(',', '')) ?? parsed;
    }
    if (mode == WorkUnitAdjustMode.multiply && parsed <= 0) parsed = 1;
    if (mode == WorkUnitAdjustMode.add && parsed < 0) parsed = 0;
    return WorkUnitPreset(
      id: id.isEmpty ? defaultId : id,
      label: label.isEmpty ? id : label,
      adjustMode: mode,
      value: parsed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'adjust_mode': adjustMode.apiValue,
        'value': value,
        // 하위 호환(구 클라이언트)
        if (adjustMode == WorkUnitAdjustMode.multiply) 'multiplier': value,
        if (adjustMode == WorkUnitAdjustMode.add) 'add_amount': value.round(),
      };

  WorkUnitPreset copyWith({
    String? id,
    String? label,
    WorkUnitAdjustMode? adjustMode,
    double? value,
  }) {
    return WorkUnitPreset(
      id: id ?? this.id,
      label: label ?? this.label,
      adjustMode: adjustMode ?? this.adjustMode,
      value: value ?? this.value,
    );
  }

  /// 기준 일당에 이 공수 설정을 적용한 금액(원).
  int amountFromBase(int baseWage) {
    if (baseWage <= 0) return 0;
    switch (adjustMode) {
      case WorkUnitAdjustMode.multiply:
        if (value <= 0) return 0;
        return (baseWage * value).round();
      case WorkUnitAdjustMode.add:
        final sum = baseWage + value.round();
        return sum < 0 ? 0 : sum;
    }
  }

  /// 칩·설정 행에 보여줄 짧은 설명 (`×1.5` / `+50,000`).
  String get adjustSummary {
    switch (adjustMode) {
      case WorkUnitAdjustMode.multiply:
        return '×${formatAdjustValue(value, mode: WorkUnitAdjustMode.multiply)}';
      case WorkUnitAdjustMode.add:
        return '+${formatAdjustValue(value, mode: WorkUnitAdjustMode.add)}';
    }
  }

  static String formatAdjustValue(
    double v, {
    required WorkUnitAdjustMode mode,
  }) {
    if (mode == WorkUnitAdjustMode.add) {
      final n = v.round();
      final s = n.abs().toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    if (v == v.roundToDouble()) return v.toInt().toString();
    final one = (v * 10).roundToDouble() / 10;
    if (one == v) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  /// 현재 금액이 어떤 공수와 일치하는지. 없으면 null.
  static String? matchId({
    required int baseWage,
    required int amount,
    required List<WorkUnitPreset> units,
  }) {
    if (baseWage <= 0 || amount < 0 || units.isEmpty) return null;
    for (final u in units) {
      if (u.amountFromBase(baseWage) == amount) return u.id;
    }
    return null;
  }

  /// 해당일에 지정된 금액을 1공수 기준으로 쓴다.
  /// (역할·기본 일당과 다르게 맞춰 둔 경우가 있으므로 [currentAmount] 우선)
  /// 현재 금액이 없을 때만 [hdailyWage]로 폴백.
  static int resolveBaseWage({
    required int hdailyWage,
    required int currentAmount,
  }) {
    if (currentAmount > 0) return currentAmount;
    if (hdailyWage > 0) return hdailyWage;
    return 0;
  }

  /// 서버/로컬 JSON 목록 → 기본 4종과 병합(순서·설정 유지, 누락 시 기본값 보충).
  static List<WorkUnitPreset> mergeWithDefaults(List<WorkUnitPreset>? raw) {
    if (raw == null || raw.isEmpty) {
      return List<WorkUnitPreset>.from(defaults);
    }
    final byId = <String, WorkUnitPreset>{
      for (final u in raw)
        if (u.id.trim().isNotEmpty && !_removedIds.contains(u.id.trim()))
          u.id.trim(): u,
    };
    final merged = <WorkUnitPreset>[];
    for (final d in defaults) {
      final existing = byId.remove(d.id);
      if (existing == null) {
        merged.add(d);
      } else {
        // 구버전 "0.5품" 등이 남아 있으면 기본 라벨(공수)로 맞춤
        final label = existing.label.contains('품')
            ? d.label
            : (existing.label.trim().isEmpty ? d.label : existing.label);
        merged.add(existing.copyWith(label: label));
      }
    }
    for (final extra in byId.values) {
      if (_removedIds.contains(extra.id)) continue;
      merged.add(extra);
    }
    return merged;
  }

  static List<WorkUnitPreset> listFromJson(dynamic raw) {
    if (raw is! List) return List<WorkUnitPreset>.from(defaults);
    final parsed = <WorkUnitPreset>[];
    for (final item in raw) {
      if (item is Map) {
        parsed.add(WorkUnitPreset.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return mergeWithDefaults(parsed);
  }
}
