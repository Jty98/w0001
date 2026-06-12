/// 출입 방식: 비밀번호만 · 열쇠만 · 둘 다.
enum PlaceSiteAccessMode {
  door,
  key,
  both;

  String get labelKo => switch (this) {
        PlaceSiteAccessMode.door => '출입 비밀번호',
        PlaceSiteAccessMode.key => '열쇠',
        PlaceSiteAccessMode.both => '비밀번호 + 열쇠',
      };

  String get wireValue => name;

  static PlaceSiteAccessMode fromWire(String? raw) {
    switch (raw) {
      case 'key':
        return PlaceSiteAccessMode.key;
      case 'both':
        return PlaceSiteAccessMode.both;
      case 'door':
      default:
        return PlaceSiteAccessMode.door;
    }
  }

  /// 저장된 문자열로 모드를 추정(구 데이터 호환).
  static PlaceSiteAccessMode infer({
    required String doorAccess,
    required String keyLocation,
    PlaceSiteAccessMode? storedMode,
  }) {
    if (storedMode != null) return storedMode;
    final hasDoor = doorAccess.trim().isNotEmpty;
    final hasKey = keyLocation.trim().isNotEmpty;
    if (hasDoor && hasKey) return PlaceSiteAccessMode.both;
    if (hasKey) return PlaceSiteAccessMode.key;
    return PlaceSiteAccessMode.door;
  }
}

/// 현장 인수인계·출입 안내 (`GET/PUT /places/{pid}/site-guide`).
class PlaceSiteGuideModel {
  const PlaceSiteGuideModel({
    required this.pid,
    this.accessMode = PlaceSiteAccessMode.door,
    this.doorAccess = '',
    this.keyLocation = '',
    this.restroomAccess = '',
    this.parkingInfo = '',
    this.updatedAt,
    this.updatedByUid,
  });

  final int pid;
  final PlaceSiteAccessMode accessMode;
  final String doorAccess;
  final String keyLocation;
  final String restroomAccess;
  final String parkingInfo;
  final DateTime? updatedAt;
  final String? updatedByUid;

  factory PlaceSiteGuideModel.empty(int pid) => PlaceSiteGuideModel(pid: pid);

  factory PlaceSiteGuideModel.fromJson(Map<String, dynamic> json) {
    return PlaceSiteGuideModel(
      pid: (json['pid'] as num).toInt(),
      accessMode: PlaceSiteAccessMode.fromWire(json['accessMode'] as String?),
      doorAccess: json['doorAccess'] as String? ?? '',
      keyLocation: json['keyLocation'] as String? ?? '',
      restroomAccess: json['restroomAccess'] as String? ?? '',
      parkingInfo: json['parkingInfo'] as String? ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      updatedByUid: json['updatedByUid'] as String?,
    );
  }

  /// PUT 요청 body (camelCase, `pid` 제외).
  Map<String, dynamic> toJsonForPut() => <String, dynamic>{
        'accessMode': accessMode.wireValue,
        'doorAccess': doorAccess,
        'keyLocation': keyLocation,
        'restroomAccess': restroomAccess,
        'parkingInfo': parkingInfo,
      };

  bool get hasAnyContent =>
      doorAccess.trim().isNotEmpty ||
      keyLocation.trim().isNotEmpty ||
      restroomAccess.trim().isNotEmpty ||
      parkingInfo.trim().isNotEmpty;

  int get filledItemCount => [
        doorAccess,
        keyLocation,
        restroomAccess,
        parkingInfo,
      ].where((s) => s.trim().isNotEmpty).length;

  String get completionHint {
    if (!hasAnyContent) return '미입력';
    return '$filledItemCount개 항목 등록';
  }

  PlaceSiteGuideModel copyWith({
    PlaceSiteAccessMode? accessMode,
    String? doorAccess,
    String? keyLocation,
    String? restroomAccess,
    String? parkingInfo,
    DateTime? updatedAt,
    String? updatedByUid,
  }) =>
      PlaceSiteGuideModel(
        pid: pid,
        accessMode: accessMode ?? this.accessMode,
        doorAccess: doorAccess ?? this.doorAccess,
        keyLocation: keyLocation ?? this.keyLocation,
        restroomAccess: restroomAccess ?? this.restroomAccess,
        parkingInfo: parkingInfo ?? this.parkingInfo,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedByUid: updatedByUid ?? this.updatedByUid,
      );
}

/// `GET /places` · `GET /places/me` 목록의 `siteGuideSummary` (선택).
class PlaceSiteGuideSummary {
  const PlaceSiteGuideSummary({
    required this.itemCount,
    this.updatedAt,
  });

  final int itemCount;
  final DateTime? updatedAt;

  factory PlaceSiteGuideSummary.fromJson(Map<String, dynamic> json) {
    return PlaceSiteGuideSummary(
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }
}
