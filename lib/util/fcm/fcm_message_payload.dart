import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:w0001/util/fcm/fcm_push_router.dart';

/// FCM [RemoteMessage] → 딥링크·알림함용 payload (값은 문자열로 정규화).
Map<String, dynamic> fcmNavigationPayloadFromMessage(RemoteMessage message) {
  final data = Map<String, dynamic>.from(message.data);
  if (data.isNotEmpty) {
    return _stringifyDataMap(data);
  }
  return data;
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
