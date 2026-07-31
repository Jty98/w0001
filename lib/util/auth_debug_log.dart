import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 디버그 빌드에서만 Auth·토큰 관련 로그를 남긴다.
void authDebugLog(String message) {
  if (kDebugMode) {
    debugPrint('[Auth] $message');
  }
}

void authDebugLogTokensSaved({
  required String event,
  required String access,
  required String refresh,
}) {
  authDebugLog(
    '$event, access_len=${access.length}, refresh_len=${refresh.length}'
    '${_jwtExpSuffix(access)}',
  );
}

void authDebugLogRefreshStart() {
  authDebugLog('refresh start');
}

void authDebugLogRefreshOk({
  required String access,
  required String refresh,
}) {
  authDebugLog(
    'refresh ok, new access_len=${access.length}, new refresh_len=${refresh.length}'
    '${_jwtExpSuffix(access)}',
  );
}

void authDebugLogRefreshFail({
  required Object? responseData,
}) {
  final code = _peekResponseCode(responseData);
  authDebugLog('refresh fail, code=${code ?? 'unknown'} → logout');
}

String _jwtExpSuffix(String token) {
  final d = _decodeJwtPayload(token);
  if (d == null) return '';
  final exp = _formatJwtExp(d);
  final sv = d['sv'];
  return ', access_exp=$exp${sv == null ? '' : ', sv=$sv'}';
}

String? _formatJwtExp(Map<String, dynamic> payload) {
  final exp = payload['exp'];
  if (exp is int) {
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000).toIso8601String();
  }
  return null;
}

Map<String, dynamic>? _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final map = jsonDecode(decoded);
    if (map is Map<String, dynamic>) return map;
    if (map is Map) return Map<String, dynamic>.from(map);
  } catch (_) {}
  return null;
}

String? _peekResponseCode(Object? responseData) {
  if (responseData is! Map) return null;
  final root = Map<String, dynamic>.from(responseData);
  for (final key in ['detail', 'error']) {
    final nested = root[key];
    if (nested is Map) {
      final code = nested['code']?.toString();
      if (code != null && code.isNotEmpty) return code;
    }
  }
  final top = root['code']?.toString();
  return (top != null && top.isNotEmpty) ? top : null;
}
