Map<String, dynamic> saParseObject(dynamic data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('Invalid JSON object');
}

List<T> saMapList<T>(
  Object? data,
  T Function(Map<String, dynamic>) f,
) {
  if (data is! List) return [];
  return data
      .map(
        (e) => f(Map<String, dynamic>.from(e as Map<dynamic, dynamic>)),
      )
      .toList();
}
