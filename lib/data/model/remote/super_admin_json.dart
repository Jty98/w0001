/// 서버 `Map` / 숫자 필드 정규화 (Pydantic JSON)
int? saInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? saDouble(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool? saBool(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is int) return v != 0;
  return null;
}

String? saString(Object? v) => v?.toString();

Map<String, dynamic> saMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<dynamic> saList(Object? v) {
  if (v is! List) return const [];
  return v;
}

T? saValue<T>(Map<String, dynamic> m, String a, [String? b]) {
  if (m.containsKey(a) && m[a] != null) return m[a] as T?;
  if (b != null && m.containsKey(b) && m[b] != null) return m[b] as T?;
  return null;
}
