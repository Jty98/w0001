import 'package:w0001/data/model/paged_result.dart';

Map<String, dynamic> saParseObject(dynamic data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('Invalid JSON object');
}

/// 서버가 `{ "items": [...] }` 등으로 감싼 목록 응답에서 배열만 꺼낸다.
Object? saExtractListPayload(Object? data) {
  if (data is List) return data;
  if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    for (final key in [
      'items',
      'data',
      'list',
      'results',
      'humans',
      'users',
      'places',
    ]) {
      final v = m[key];
      if (v is List) return v;
    }
  }
  return null;
}

List<T> saMapList<T>(
  Object? data,
  T Function(Map<String, dynamic>) f,
) {
  final listData = saExtractListPayload(data);
  if (listData is! List) return [];
  return listData
      .map(
        (e) => f(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)),
      )
      .toList();
}

bool? _saBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.trim().toLowerCase();
    if (t == 'true' || t == '1') return true;
    if (t == 'false' || t == '0') return false;
  }
  return null;
}

String? _saString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? _saInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

Map<String, dynamic> _unwrapPagedResponseMap(Map<String, dynamic> root) {
  if (root['items'] is List || root['places'] is List) return root;
  final data = root['data'];
  if (data is Map) {
    final inner = Map<String, dynamic>.from(data);
    if (inner['items'] is List || inner['places'] is List) return inner;
  }
  final result = root['result'];
  if (result is Map) {
    final inner = Map<String, dynamic>.from(result);
    if (inner['items'] is List || inner['places'] is List) return inner;
  }
  return root;
}

/// 서버 cursor 목록 `{ items, next_cursor, has_more, total }`.
///
/// 레거시 단독 배열 `[{...}]` 응답은 더 이상 사용하지 않습니다.
PagedResult<T> saParsePagedList<T>(
  Object? data,
  T Function(Map<String, dynamic>) f,
) {
  if (data is List) {
    final items = data
        .map(
          (e) => f(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)),
        )
        .toList();
    return PagedResult(items: items, hasMore: false, totalCount: items.length);
  }
  if (data is Map) {
    final m = _unwrapPagedResponseMap(Map<String, dynamic>.from(data));
    final rawItems = m['items'] ?? m['places'];
    final List<T> items;
    if (rawItems is List) {
      items = rawItems
          .map(
            (e) => f(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)),
          )
          .toList();
    } else {
      items = const [];
    }
    final next = _saString(
      m['next_cursor'] ?? m['nextCursor'] ?? m['cursor'],
    );
    var hasMore = _saBool(m['has_more'] ?? m['hasMore']);
    if (hasMore == null && next != null) {
      hasMore = true;
    }
    hasMore ??= false;
    final total = _saInt(m['total'] ?? m['total_count'] ?? m['totalCount']);
    return PagedResult(
      items: items,
      nextCursor: next,
      hasMore: hasMore,
      totalCount: total,
    );
  }
  return const PagedResult(items: [], hasMore: false);
}
