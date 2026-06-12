/// 서버 `terms.type`
enum TermType {
  service,
  privacy,
  workerTax,
  unknown;

  static TermType parse(String? raw) {
    switch (raw?.trim()) {
      case 'service':
        return TermType.service;
      case 'privacy':
        return TermType.privacy;
      case 'worker_tax':
        return TermType.workerTax;
      default:
        return TermType.unknown;
    }
  }

  String get labelKo {
    return switch (this) {
      TermType.service => '서비스 이용약관',
      TermType.privacy => '개인정보 처리방침',
      TermType.workerTax => '세무정보 수집·이용 동의',
      TermType.unknown => '약관',
    };
  }

  /// 회원가입 단계에서 노출·동의 대상.
  bool get isSignupTerm => this == TermType.service || this == TermType.privacy;
}

/// `GET /terms` 항목 (본문 제외).
class TermSummary {
  const TermSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.version,
    required this.required,
    this.effectiveAt,
  });

  final int id;
  final TermType type;
  final String title;
  final String version;
  final bool required;
  final String? effectiveAt;

  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : type.labelKo;

  factory TermSummary.fromJson(Map<String, dynamic> json) {
    final type = TermType.parse(_str(json['type']));
    return TermSummary(
      id: _int(json['id']) ?? 0,
      type: type,
      title: _str(json['title']),
      version: _str(json['version']),
      required: json['required'] == true ||
          json['is_required'] == true ||
          type.isSignupTerm,
      effectiveAt: _optStr(json['effective_at'] ?? json['effectiveAt']),
    );
  }
}

/// `GET /terms/{id}` 전문.
class TermDetail {
  const TermDetail({
    required this.summary,
    required this.content,
  });

  final TermSummary summary;
  final String content;

  factory TermDetail.fromJson(Map<String, dynamic> json) {
    return TermDetail(
      summary: TermSummary.fromJson(json),
      content: _str(json['content'] ?? json['body'] ?? json['text']),
    );
  }
}

/// `GET /users/me/terms` — 본인 약관 동의 이력 항목.
class TermAgreementRead {
  const TermAgreementRead({
    required this.termId,
    required this.type,
    required this.version,
    this.agreedAt,
    this.title,
  });

  final int termId;
  final TermType type;
  final String version;
  final String? agreedAt;
  final String? title;

  factory TermAgreementRead.fromJson(Map<String, dynamic> json) {
    return TermAgreementRead(
      termId: _int(json['term_id'] ?? json['termId']) ?? 0,
      type: TermType.parse(_str(json['type'])),
      version: _str(json['version']),
      agreedAt: _optStr(json['agreed_at'] ?? json['agreedAt']),
      title: _optStr(json['title']),
    );
  }
}

List<TermAgreementRead> parseTermAgreementList(Object? data) {
  Iterable<dynamic> items;
  if (data is List) {
    items = data;
  } else if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    final inner = m['terms'] ?? m['items'] ?? m['data'] ?? m['agreements'];
    if (inner is List) {
      items = inner;
    } else {
      return const [];
    }
  } else {
    return const [];
  }

  return items
      .whereType<Map>()
      .map((e) => TermAgreementRead.fromJson(Map<String, dynamic>.from(e)))
      .where((t) => t.termId > 0)
      .toList(growable: false);
}

/// `POST /auth/signup` — `terms_agreements` 항목.
class TermAgreementInput {
  const TermAgreementInput({
    required this.termId,
    required this.version,
  });

  final int termId;
  final String version;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'term_id': termId,
        'version': version,
      };
}

String _str(Object? v) => v?.toString().trim() ?? '';

String? _optStr(Object? v) {
  final s = _str(v);
  return s.isEmpty ? null : s;
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

List<TermSummary> parseTermSummaryList(Object? data) {
  Iterable<dynamic> items;
  if (data is List) {
    items = data;
  } else if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    final inner = m['terms'] ?? m['items'] ?? m['data'] ?? m['list'];
    if (inner is List) {
      items = inner;
    } else {
      return const [];
    }
  } else {
    return const [];
  }

  return items
      .whereType<Map>()
      .map((e) => TermSummary.fromJson(Map<String, dynamic>.from(e)))
      .where((t) => t.id > 0)
      .toList(growable: false);
}
