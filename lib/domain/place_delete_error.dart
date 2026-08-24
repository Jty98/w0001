import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/util/auth_dio_user_message.dart';

/// 서버 영구삭제(`permanent=true`) 409 응답 파싱.
class PlacePermanentDeleteBlocked {
  const PlacePermanentDeleteBlocked({
    required this.message,
    this.blockedBy = const [],
  });

  final String message;
  final List<String> blockedBy;

  String get displayMessage {
    if (blockedBy.isEmpty) return message;
    final labels = blockedBy.map(labelForBlockedBy).toList();
    return '$message\n\n남아 있는 데이터: ${labels.join(', ')}';
  }
}

String labelForBlockedBy(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'workcost':
    case 'work_cost':
    case 'work-costs':
      return '인건비';
    case 'materialcost':
    case 'material_cost':
    case 'material-costs':
      return '자재비';
    case 'placeworkday':
    case 'place_work_day':
    case 'place-work-days':
      return '작업자 작업일';
    case 'placecollection':
    case 'place_collection':
      return '수금 내역';
    case 'placerevenue':
    case 'place_revenue':
      return '추가 수익';
    case 'place_checklist_items':
    case 'placechecklistitems':
      return '체크리스트';
    case 'place_checklist_deferrals':
    case 'placechecklistdeferrals':
      return '체크리스트 미루기';
    case 'place_process_schedule':
    case 'placeprocessschedule':
      return '공정표';
    case 'placephotogroup':
    case 'place_photo_group':
    case 'place-photo-groups':
      return '사진';
    default:
      return raw;
  }
}

PlacePermanentDeleteBlocked? tryParsePlacePermanentDeleteBlocked(Object? body) {
  if (body == null) return null;
  Map<String, dynamic>? root;
  if (body is Map<String, dynamic>) {
    root = body;
  } else if (body is Map) {
    root = Map<String, dynamic>.from(body);
  } else if (body is String && body.trim().isNotEmpty) {
    return PlacePermanentDeleteBlocked(message: body.trim());
  } else {
    return null;
  }

  final detail = root['detail'];
  Map<String, dynamic>? detailMap;
  if (detail is Map) {
    detailMap = Map<String, dynamic>.from(detail);
  }

  final blocked = <String>[];
  void collectBlocked(Object? raw) {
    if (raw is! List) return;
    for (final e in raw) {
      final s = e?.toString().trim() ?? '';
      if (s.isNotEmpty) blocked.add(s);
    }
  }

  collectBlocked(root['blocked_by'] ?? root['blockedBy']);
  if (detailMap != null) {
    collectBlocked(detailMap['blocked_by'] ?? detailMap['blockedBy']);
  }

  String? message;
  for (final key in ['message', 'detail', 'error']) {
    final v = root[key];
    if (v is String && v.trim().isNotEmpty) {
      message = v.trim();
      break;
    }
  }
  if (message == null && detailMap != null) {
    final m = detailMap['message']?.toString().trim();
    if (m != null && m.isNotEmpty) message = m;
  }
  if (message == null && detail is String && detail.trim().isNotEmpty) {
    message = detail.trim();
  }
  message ??= '연관 데이터가 있어 영구 삭제할 수 없습니다.';

  return PlacePermanentDeleteBlocked(
    message: message,
    blockedBy: blocked,
  );
}

/// 현장 삭제 실패 시 사용자 안내 문구.
String userMessageForPlaceDeleteFailure(Object error) {
  final h = unwrapHttpClientException(error);
  if (h is HttpStatusException && h.statusCode == 409) {
    final blocked = tryParsePlacePermanentDeleteBlocked(h.body);
    if (blocked != null) return blocked.displayMessage;
  }
  if (error is DioException && error.response?.statusCode == 409) {
    final blocked = tryParsePlacePermanentDeleteBlocked(error.response?.data);
    if (blocked != null) return blocked.displayMessage;
  }
  return snackMessageForHttpFailure(error) ?? '현장 삭제에 실패했습니다.';
}
