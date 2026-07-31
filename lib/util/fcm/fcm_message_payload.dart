import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:w0001/util/fcm/fcm_push_router.dart';

/// FCM [RemoteMessage] → 딥링크·알림함용 payload (값은 문자열로 정규화).
Map<String, dynamic> fcmNavigationPayloadFromMessage(RemoteMessage message) {
  var data = Map<String, dynamic>.from(message.data);
  data = _unwrapNestedFcmPayload(data);
  if (data.isNotEmpty) {
    return _stringifyDataMap(data);
  }
  return data;
}

/// 서버가 `payload`·`data` 등에 JSON 문자열/중첩 맵으로 실을 때 펼친다.
Map<String, dynamic> _unwrapNestedFcmPayload(Map<String, dynamic> raw) {
  var out = Map<String, dynamic>.from(raw);
  for (final key in ['payload', 'data', 'extra', 'extras', 'custom_data']) {
    final nested = out[key];
    if (nested is String) {
      final trimmed = nested.trim();
      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            out.remove(key);
            out.addAll(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
    } else if (nested is Map) {
      out.remove(key);
      out.addAll(Map<String, dynamic>.from(nested));
    }
  }
  return out;
}

Map<String, dynamic> _stringifyDataMap(Map<String, dynamic> raw) {
  final out = <String, dynamic>{};
  for (final e in raw.entries) {
    final v = e.value;
    if (v == null) continue;
    out[e.key] = v is String ? v : v.toString();
  }
  return out;
}

bool fcmPayloadCanNavigate(Map<String, dynamic> data) {
  final type = fcmResolvedPushType(data);
  return type != null && type.isNotEmpty;
}
