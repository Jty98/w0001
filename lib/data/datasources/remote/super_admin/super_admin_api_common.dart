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
