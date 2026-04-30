import 'package:w0001/data/model/remote/super_admin_json.dart';

String _dashCamelToSnake(String camel) {
  if (camel.isEmpty) return camel;
  final b = StringBuffer();
  for (var i = 0; i < camel.length; i++) {
    final c = camel[i];
    final isUpper = c == c.toUpperCase() && c != c.toLowerCase();
    if (isUpper) {
      if (i > 0) b.write('_');
      b.write(c.toLowerCase());
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

/// 서버가 camelCase 또는 snake_case 둘 다 줄 수 있을 때 int.
int dashReadInt(Map<String, dynamic> m, String camelKey) {
  final v1 = m[camelKey];
  if (v1 != null) {
    final n = saInt(v1);
    if (n != null) return n;
  }
  final s = _dashCamelToSnake(camelKey);
  if (m.containsKey(s)) {
    return saInt(m[s]) ?? 0;
  }
  return 0;
}

/// 서버가 camelCase 또는 snake_case 둘 다 줄 수 있을 때 double.
double dashReadDouble(Map<String, dynamic> m, String camelKey) {
  final v1 = m[camelKey];
  if (v1 != null) {
    final d = saDouble(v1);
    if (d != null) return d;
  }
  final s = _dashCamelToSnake(camelKey);
  if (m.containsKey(s)) {
    return saDouble(m[s]) ?? 0;
  }
  return 0;
}

String dashReadString(Map<String, dynamic> m, String camelKey) {
  final v1 = m[camelKey];
  if (v1 != null) return v1.toString();
  final s = _dashCamelToSnake(camelKey);
  final v2 = m[s];
  if (v2 != null) return v2.toString();
  return '';
}
