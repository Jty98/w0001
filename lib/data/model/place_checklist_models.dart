/// 현장 일일 체크리스트 — 항목·미루기 기록 (서버 API 동기화).

/// `active` | `checked` | `deferred` (다음날로 넘김 — 당일에는 완료 처리 불가)
enum PlaceChecklistItemStatus {
  active,
  checked,
  deferred;

  static PlaceChecklistItemStatus fromJson(String? raw) {
    switch (raw) {
      case 'checked':
        return PlaceChecklistItemStatus.checked;
      case 'deferred':
        return PlaceChecklistItemStatus.deferred;
      default:
        return PlaceChecklistItemStatus.active;
    }
  }

  String toJson() => name;
}

class PlaceChecklistItem {
  const PlaceChecklistItem({
    required this.id,
    required this.workDate,
    required this.title,
    required this.processGroup,
    required this.sortOrder,
    this.status = PlaceChecklistItemStatus.active,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  final String workDate;

  /// `YYYY-MM-DD`
  final String title;

  /// 공정표 행 이름(예: 주방설비). 직접 입력 시 사용자가 입력한 문자열.
  final String processGroup;
  final int sortOrder;
  final PlaceChecklistItemStatus status;
  final int createdAtMs;
  final int updatedAtMs;

  bool get isChecked => status == PlaceChecklistItemStatus.checked;
  bool get isDeferred => status == PlaceChecklistItemStatus.deferred;

  PlaceChecklistItem copyWith({
    String? id,
    String? workDate,
    String? title,
    String? processGroup,
    int? sortOrder,
    PlaceChecklistItemStatus? status,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return PlaceChecklistItem(
      id: id ?? this.id,
      workDate: workDate ?? this.workDate,
      title: title ?? this.title,
      processGroup: processGroup ?? this.processGroup,
      sortOrder: sortOrder ?? this.sortOrder,
      status: status ?? this.status,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'work_date': workDate,
        'title': title,
        'process_group': processGroup,
        'sort_order': sortOrder,
        'status': status.toJson(),
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  factory PlaceChecklistItem.fromJson(Map<String, dynamic> m) {
    return PlaceChecklistItem(
      id: m['id']?.toString() ?? '',
      workDate: m['work_date']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      processGroup: m['process_group']?.toString() ?? '',
      sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      status: PlaceChecklistItemStatus.fromJson(m['status']?.toString()),
      createdAtMs: (m['created_at_ms'] as num?)?.toInt() ?? 0,
      updatedAtMs: (m['updated_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlaceChecklistDeferral {
  const PlaceChecklistDeferral({
    required this.id,
    required this.itemId,
    required this.fromDate,
    required this.toDate,
    required this.title,
    required this.processGroup,
    this.reason = '',
    this.createdAtMs = 0,
  });

  final String id;
  final String itemId;
  final String fromDate;
  final String toDate;
  final String title;
  final String processGroup;
  final String reason;
  final int createdAtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'item_id': itemId,
        'from_date': fromDate,
        'to_date': toDate,
        'title': title,
        'process_group': processGroup,
        'reason': reason,
        'created_at_ms': createdAtMs,
      };

  factory PlaceChecklistDeferral.fromJson(Map<String, dynamic> m) {
    final itemId =
        m['item_id']?.toString() ?? m['source_item_id']?.toString() ?? '';
    return PlaceChecklistDeferral(
      id: m['id']?.toString() ?? '',
      itemId: itemId,
      fromDate: m['from_date']?.toString() ?? '',
      toDate: m['to_date']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      processGroup: m['process_group']?.toString() ?? '',
      reason: m['reason']?.toString() ?? '',
      createdAtMs: (m['created_at_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 미루기 대상일 — 원본 날짜 + 1일 (`YYYY-MM-DD`).
String placeChecklistDefaultDeferToDate(String fromDateKey) {
  final p = fromDateKey.split('-');
  if (p.length != 3) return fromDateKey;
  final y = int.tryParse(p[0]);
  final mo = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || mo == null || d == null) return fromDateKey;
  final next = DateTime(y, mo, d).add(const Duration(days: 1));
  return '${next.year.toString().padLeft(4, '0')}-'
      '${next.month.toString().padLeft(2, '0')}-'
      '${next.day.toString().padLeft(2, '0')}';
}

/// 현장 1곳의 체크리스트 스냅샷(날짜 범위 조회 결과).
class PlaceChecklistSnapshot {
  const PlaceChecklistSnapshot({
    required this.placeId,
    required this.items,
    required this.deferrals,
  });

  final int placeId;
  final List<PlaceChecklistItem> items;
  final List<PlaceChecklistDeferral> deferrals;

  List<PlaceChecklistItem> itemsForDate(String workDate) {
    final out = items.where((e) => e.workDate == workDate).toList()
      ..sort((a, b) {
        final g = a.processGroup.compareTo(b.processGroup);
        if (g != 0) return g;
        final s = a.sortOrder.compareTo(b.sortOrder);
        if (s != 0) return s;
        return a.createdAtMs.compareTo(b.createdAtMs);
      });
    return out;
  }

  List<PlaceChecklistDeferral> deferralsForDate(String workDate) {
    return deferrals
        .where((d) => d.fromDate == workDate || d.toDate == workDate)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  PlaceChecklistSnapshot copyWith({
    int? placeId,
    List<PlaceChecklistItem>? items,
    List<PlaceChecklistDeferral>? deferrals,
  }) {
    return PlaceChecklistSnapshot(
      placeId: placeId ?? this.placeId,
      items: items ?? this.items,
      deferrals: deferrals ?? this.deferrals,
    );
  }
}
