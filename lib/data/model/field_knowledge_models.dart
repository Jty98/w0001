/// 현장 지식 사전 — 자재사전, 용어사전, 시공사례 모델
///
/// 모든 항목은 ID·제목·상태(활성/비활성)·검색·태그를 공유한다.

import 'package:w0001/data/model/worker_announcement_models.dart';

enum KnowledgeEntryType {
  material('material', '자재사전', '대표·상세 이미지, 특징, 주의사항과 현장 팁'),
  term('term', '용어사전', '현장 용어 정의와 예시, 관련 자재 연결'),
  constructionCase('construction_case', '시공사례', '베스트·워스트 사례를 비교하며 작업 노하우 공유'),
  processGuide('process_guide', '공정 가이드', '시공 공정별 작업 순서와 주의사항 가이드');

  const KnowledgeEntryType(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  String toJson() => value;

  static KnowledgeEntryType fromJson(String? value) {
    return KnowledgeEntryType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => KnowledgeEntryType.material,
    );
  }

  bool get hasImages => this != term;
}

/// 시공사례 예시 타입 (베스트/워스트)
enum ConstructionExampleType {
  best('best', '베스트', '좋은 시공 사례'),
  worst('worst', '워스트', '하자·주의 사례');

  const ConstructionExampleType(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  String toJson() => value;

  static ConstructionExampleType fromJson(String? value) {
    return ConstructionExampleType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ConstructionExampleType.best,
    );
  }
}

/// 지식 항목 기본 모델
class KnowledgeEntry {
  const KnowledgeEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.isActive = true,
    this.imageUrls = const [],
    this.thumbnailUrl,
    this.categories = const [],
    this.tags = const [],
    this.relatedEntryIds = const [],
    this.relatedEntries = const [],
    this.viewCount = 0,
    this.createdAt,
    this.updatedAt,
    this.constructionExamples,
    this.termExtras,
    this.contentType = 'text',
    this.contentBlocks = const [],
  });

  final int id;
  final KnowledgeEntryType type;
  final String title;
  final String content;
  final bool isActive;

  /// 이미지 URL 리스트 (자재사전, 시공사례 용어사전만)
  final List<String> imageUrls;

  /// 썸네일 URL (리스트 표시용, 서버에서 자동 생성)
  final String? thumbnailUrl;

  /// 구조화된 분류 카테고리 (예: ["바닥재", "마루"])
  /// 자재와 용어에 사용, 여러 카테고리 할당 가능
  final List<String> categories;

  /// 검색·필터용 태그
  final List<String> tags;

  /// 연결된 다른 항목 ID (예: 용어 → 자재 연결)
  final List<int> relatedEntryIds;

  /// 연관 항목 리스트 (상세 조회 시 서버에서 포함)
  final List<KnowledgeEntry> relatedEntries;

  /// 조회수
  final int viewCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 시공사례 전용: 베스트/워스트 예시들
  final ConstructionExamples? constructionExamples;

  /// 용어사전 전용: 확장 정보
  final TermExtras? termExtras;

  /// 콘텐츠 타입 ('text' | 'quill')
  final String contentType;

  /// Quill 콘텐츠 블록 (공정 가이드용)
  final List<WorkerAnnouncementBlock> contentBlocks;

  factory KnowledgeEntry.fromJson(Map<String, dynamic> json) {
    final examplesJson =
        json['construction_examples'] ?? json['constructionExamples'];
    final relatedJson = json['related_entries'] ?? json['relatedEntries'] ?? [];

    return KnowledgeEntry(
      id: _jsonInt(json['id']),
      type: KnowledgeEntryType.fromJson(json['type']),
      title: _jsonString(json['title']),
      content: _jsonString(json['content']),
      isActive:
          _jsonBool(json['is_active'] ?? json['isActive'], fallback: true),
      imageUrls: _jsonStringList(json['image_urls'] ?? json['imageUrls']),
      thumbnailUrl: json['thumbnail_url'] ?? json['thumbnailUrl'],
      categories: _jsonStringList(json['categories']),
      tags: _jsonStringList(json['tags']),
      relatedEntryIds:
          _jsonIntList(json['related_entry_ids'] ?? json['relatedEntryIds']),
      relatedEntries: (relatedJson as List)
          .map((e) => KnowledgeEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      viewCount: _jsonInt(json['view_count'] ?? json['viewCount'], fallback: 0),
      createdAt: _jsonDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _jsonDate(json['updated_at'] ?? json['updatedAt']),
      constructionExamples: examplesJson != null
          ? ConstructionExamples.fromJson(examplesJson as Map<String, dynamic>)
          : null,
      termExtras: json['term_extras'] != null || json['termExtras'] != null
          ? TermExtras.fromJson((json['term_extras'] ?? json['termExtras'])
              as Map<String, dynamic>)
          : null,
      contentType: json['content_type'] ?? json['contentType'] ?? 'text',
      contentBlocks: parseWorkerAnnouncementBlockList(
        json['content_blocks'] ?? json['contentBlocks'],
      ),
    );
  }

  Map<String, dynamic> toWriteJson() => <String, dynamic>{
        'type': type.toJson(),
        'title': title.trim(),
        'content': content.trim(),
        'is_active': isActive,
        'image_urls': imageUrls,
        'categories': categories.where((c) => c.trim().isNotEmpty).toList(),
        'tags': tags.where((t) => t.trim().isNotEmpty).toList(),
        'related_entry_ids': relatedEntryIds,
        if (constructionExamples != null)
          'construction_examples': constructionExamples!.toJson(),
        if (termExtras != null) 'term_extras': termExtras!.toJson(),
        'content_type': contentType,
        if (contentBlocks.isNotEmpty)
          'content_blocks': contentBlocks.map((b) => b.toJson()).toList(),
      };

  KnowledgeEntry copyWith({
    int? id,
    KnowledgeEntryType? type,
    String? title,
    String? content,
    bool? isActive,
    List<String>? imageUrls,
    String? thumbnailUrl,
    List<String>? categories,
    List<String>? tags,
    List<int>? relatedEntryIds,
    List<KnowledgeEntry>? relatedEntries,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    ConstructionExamples? constructionExamples,
    TermExtras? termExtras,
    String? contentType,
    List<WorkerAnnouncementBlock>? contentBlocks,
  }) {
    return KnowledgeEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      imageUrls: imageUrls ?? this.imageUrls,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      relatedEntryIds: relatedEntryIds ?? this.relatedEntryIds,
      relatedEntries: relatedEntries ?? this.relatedEntries,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      constructionExamples: constructionExamples ?? this.constructionExamples,
      termExtras: termExtras ?? this.termExtras,
      contentType: contentType ?? this.contentType,
      contentBlocks: contentBlocks ?? this.contentBlocks,
    );
  }

  /// 주 이미지 (썸네일 > 첫 이미지)
  String? get primaryImageUrl => thumbnailUrl ?? imageUrls.firstOrNull;

  /// 검색용 텍스트 (제목 + 내용 + 카테고리 + 태그)
  String get searchableText =>
      '${title.toLowerCase()} ${content.toLowerCase()} ${categories.join(' ').toLowerCase()} ${tags.join(' ').toLowerCase()}';

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return searchableText.contains(lowerQuery);
  }

  /// 시공사례인지 여부
  bool get isConstructionCase => type == KnowledgeEntryType.constructionCase;

  /// 연관 항목이 있는지 (상세 조회 시 서버에서 포함)
  bool get hasRelatedEntries => relatedEntries.isNotEmpty;

  /// Quill 콘텐츠 여부
  bool get isQuillContent => contentType == 'quill' && contentBlocks.isNotEmpty;
}

/// 시공사례 전용 - 베스트/워스트 예시 컨테이너
class ConstructionExamples {
  const ConstructionExamples({
    this.bestExamples = const [],
    this.worstExamples = const [],
  });

  final List<ConstructionExample> bestExamples;
  final List<ConstructionExample> worstExamples;

  factory ConstructionExamples.fromJson(Map<String, dynamic> json) {
    final bestJson = json['best_examples'] ?? json['bestExamples'] ?? [];
    final worstJson = json['worst_examples'] ?? json['worstExamples'] ?? [];

    return ConstructionExamples(
      bestExamples: (bestJson as List)
          .map((e) => ConstructionExample.fromJson(e as Map<String, dynamic>))
          .toList(),
      worstExamples: (worstJson as List)
          .map((e) => ConstructionExample.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'best_examples': bestExamples.map((e) => e.toJson()).toList(),
        'worst_examples': worstExamples.map((e) => e.toJson()).toList(),
      };

  ConstructionExamples copyWith({
    List<ConstructionExample>? bestExamples,
    List<ConstructionExample>? worstExamples,
  }) {
    return ConstructionExamples(
      bestExamples: bestExamples ?? this.bestExamples,
      worstExamples: worstExamples ?? this.worstExamples,
    );
  }

  bool get isEmpty => bestExamples.isEmpty && worstExamples.isEmpty;
  bool get hasAny => !isEmpty;
}

/// 개별 시공 예시 (베스트 또는 워스트)
class ConstructionExample {
  const ConstructionExample({
    required this.imageUrls,
    required this.description,
    this.tips = const [],
  });

  /// 예시 이미지들
  final List<String> imageUrls;

  /// 설명 (왜 좋은지 / 왜 나쁜지)
  final String description;

  /// 작업 팁 또는 주의사항 (선택)
  final List<String> tips;

  factory ConstructionExample.fromJson(Map<String, dynamic> json) {
    return ConstructionExample(
      imageUrls: _jsonStringList(json['image_urls'] ?? json['imageUrls']),
      description: _jsonString(json['description']),
      tips: _jsonStringList(json['tips']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'image_urls': imageUrls,
        'description': description.trim(),
        'tips': tips.where((t) => t.trim().isNotEmpty).toList(),
      };

  ConstructionExample copyWith({
    List<String>? imageUrls,
    String? description,
    List<String>? tips,
  }) {
    return ConstructionExample(
      imageUrls: imageUrls ?? this.imageUrls,
      description: description ?? this.description,
      tips: tips ?? this.tips,
    );
  }

  String? get primaryImageUrl => imageUrls.firstOrNull;
}

/// 용어사전 전용 - 확장 정보
class TermExtras {
  const TermExtras({
    this.standardName,
    this.aliases = const [],
    this.field,
    this.englishName,
    this.relatedTerms = const [],
  });

  /// 표준 명칭 (예: "나사")
  final String? standardName;

  /// 별칭들 (예: ["스크류", "나사못"])
  final List<String> aliases;

  /// 작업 분야 (예: "목공", "타일", "미장")
  final String? field;

  /// 영문 명칭 (예: "Screw")
  final String? englishName;

  /// 연관 용어 (예: ["드릴", "앙카", "타카"])
  final List<String> relatedTerms;

  factory TermExtras.fromJson(Map<String, dynamic> json) {
    return TermExtras(
      standardName: json['standard_name'] ?? json['standardName'],
      aliases: _jsonStringList(json['aliases']),
      field: json['field'],
      englishName:
          json['english_name'] ?? json['englishName'] ?? json['english'],
      relatedTerms: _jsonStringList(
          json['related_terms'] ?? json['relatedTerms'] ?? json['related']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (standardName != null && standardName!.isNotEmpty)
          'standard_name': standardName,
        'aliases': aliases.where((a) => a.trim().isNotEmpty).toList(),
        if (field != null && field!.isNotEmpty) 'field': field,
        if (englishName != null && englishName!.isNotEmpty)
          'english_name': englishName,
        'related_terms':
            relatedTerms.where((r) => r.trim().isNotEmpty).toList(),
      };

  TermExtras copyWith({
    String? standardName,
    List<String>? aliases,
    String? field,
    String? englishName,
    List<String>? relatedTerms,
  }) {
    return TermExtras(
      standardName: standardName ?? this.standardName,
      aliases: aliases ?? this.aliases,
      field: field ?? this.field,
      englishName: englishName ?? this.englishName,
      relatedTerms: relatedTerms ?? this.relatedTerms,
    );
  }

  bool get isEmpty =>
      (standardName == null || standardName!.isEmpty) &&
      aliases.isEmpty &&
      (field == null || field!.isEmpty) &&
      (englishName == null || englishName!.isEmpty) &&
      relatedTerms.isEmpty;

  bool get hasAny => !isEmpty;
}

/// 페이지네이션 결과
class KnowledgePage {
  const KnowledgePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<KnowledgeEntry> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasNext => page * pageSize < total;

  factory KnowledgePage.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] ?? json['data'] ?? [];
    return KnowledgePage(
      items: (itemsJson as List)
          .map((e) => KnowledgeEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: _jsonInt(json['page'], fallback: 1),
      pageSize: _jsonInt(json['page_size'] ?? json['pageSize'], fallback: 20),
      total: _jsonInt(json['total'], fallback: 0),
    );
  }
}

/// 검색/필터 옵션
class KnowledgeFilter {
  const KnowledgeFilter({
    this.type,
    this.categories = const [],
    this.tags = const [],
    this.isActive,
    this.query = '',
    this.initial,
    this.sortBy = KnowledgeSortBy.recent,
  });

  final KnowledgeEntryType? type;
  final List<String> categories;
  final List<String> tags;
  final bool? isActive;
  final String query;

  /// 용어사전 초성 필터 (예: `ㄱ`). 서버 `initial` 쿼리.
  final String? initial;
  final KnowledgeSortBy sortBy;

  KnowledgeFilter copyWith({
    KnowledgeEntryType? type,
    List<String>? categories,
    List<String>? tags,
    bool? isActive,
    String? query,
    Object? initial = _knowledgeFilterUnset,
    KnowledgeSortBy? sortBy,
  }) {
    return KnowledgeFilter(
      type: type ?? this.type,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      query: query ?? this.query,
      initial: identical(initial, _knowledgeFilterUnset)
          ? this.initial
          : initial as String?,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  Map<String, dynamic> toQueryParams({int page = 1, int pageSize = 20}) {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'sort': sortBy.value,
    };
    if (type != null) params['type'] = type!.value;
    if (categories.isNotEmpty) params['categories'] = categories.join(',');
    if (tags.isNotEmpty) params['tags'] = tags.join(',');
    if (isActive != null) params['is_active'] = isActive;
    if (query.trim().isNotEmpty) params['query'] = query.trim();
    final init = initial?.trim();
    if (init != null && init.isNotEmpty) params['initial'] = init;
    return params;
  }
}

const Object _knowledgeFilterUnset = Object();

enum KnowledgeSortBy {
  recent('recent', '최신순'),
  popular('popular', '인기순'),
  title('title', '이름순');

  const KnowledgeSortBy(this.value, this.displayName);

  final String value;
  final String displayName;

  String toJson() => value;

  static KnowledgeSortBy fromJson(String? value) {
    return KnowledgeSortBy.values.firstWhere(
      (e) => e.value == value,
      orElse: () => KnowledgeSortBy.recent,
    );
  }
}

/// 태그 통계 (자동완성·필터 UI용)
class KnowledgeTagStats {
  const KnowledgeTagStats({
    required this.tag,
    required this.count,
  });

  final String tag;
  final int count;

  factory KnowledgeTagStats.fromJson(Map<String, dynamic> json) {
    return KnowledgeTagStats(
      tag: _jsonString(json['tag']),
      count: _jsonInt(json['count'], fallback: 0),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// JSON 헬퍼
// ────────────────────────────────────────────────────────────────────────────

int _jsonInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _jsonString(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  return text == null || text.isEmpty ? fallback : text;
}

bool _jsonBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return fallback;
}

DateTime? _jsonDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

List<String> _jsonStringList(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
  if (value is String && value.isNotEmpty) {
    return value
        .split(',')
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return const [];
}

List<int> _jsonIntList(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map((e) => e is int ? e : int.tryParse(e.toString()))
        .whereType<int>()
        .toList();
  }
  return const [];
}

// ────────────────────────────────────────────────────────────────────────────
// 카테고리 상수
// ────────────────────────────────────────────────────────────────────────────

/// 현장 지식 사전 카테고리 정의
class KnowledgeCategories {
  const KnowledgeCategories._();

  /// 자재사전 카테고리
  static const List<String> materials = [
    '바닥재',
    '벽재',
    '목재/합판',
    '철물/부속',
    '전기/조명',
    '위생/배관',
    '창호/문',
    '단열/방수',
    '도료/접착',
    '기타',
  ];

  /// 용어사전 카테고리
  static const List<String> terms = [
    '시공 용어',
    '자재 명칭',
    '측정/규격',
    '하자/결함',
    '공정/절차',
  ];

  /// 공정 가이드 카테고리
  static const List<String> processGuides = [
    '기초/골조',
    '미장/방수',
    '타일',
    '목공',
    '도장',
    '전기/설비',
    '마감/양생',
  ];

  /// 타입별 카테고리 반환
  static List<String> forType(KnowledgeEntryType type) {
    switch (type) {
      case KnowledgeEntryType.material:
        return materials;
      case KnowledgeEntryType.term:
        return terms;
      case KnowledgeEntryType.processGuide:
        return processGuides;
      case KnowledgeEntryType.constructionCase:
        return []; // 시공사례는 카테고리 사용 안함 (베스트/워스트로 구분)
    }
  }

  /// 모든 카테고리 (중복 제거)
  static List<String> get all {
    final set = <String>{...materials, ...terms};
    return set.toList()..sort();
  }
}
