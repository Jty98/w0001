import 'package:path/path.dart' as p;

import 'package:w0001/data/model/remote/super_admin_json.dart';

/// [`POST /uploads/image`] multipart 필드 `category` 값.
enum ImageUploadCategory {
  /// 현장 사진 (`place_image`)
  placeImage('place_image'),

  /// 도면·계획 사진 (`plan_image`)
  planImage('plan_image'),

  /// 공지 본문·에디터 이미지 (`announcement_image`)
  announcementImage('announcement_image');

  const ImageUploadCategory(this.serverValue);

  final String serverValue;

  /// `PlacePhotoGroup` 의 `phototype` (`site` | `drawing` | `estimate` 등).
  static ImageUploadCategory fromPlacePhotoType(String phototype) {
    switch (phototype) {
      case 'drawing':
        return ImageUploadCategory.planImage;
      case 'estimate':
        // 서버에 견적 전용 `category`가 생기면 여기서 분기. 당분간 현장과 동일 업로드 경로.
        return ImageUploadCategory.placeImage;
      case 'site':
      default:
        return ImageUploadCategory.placeImage;
    }
  }
}

/// [`POST /uploads/image`] 응답을 정규화한 값.
///
/// 서버별 키 차이가 있어도 `display_url` / `original_url` / `originalname` 계열을 먼저 본다.
class ImageUploadResult {
  const ImageUploadResult({
    required this.displayUrl,
    required this.originalUrl,
    required this.originalname,
    this.category,
    this.storageKey,
    this.skipPlacePhotoCreate = false,
  });

  /// 리사이즈·CDN 등 사용자에게 보여 줄 URL (없으면 [originalUrl]과 동일 취급).
  final String displayUrl;
  final String originalUrl;
  final String originalname;

  /// 응답에 포함될 수 있음 (`place_image` | `plan_image` | `announcement_image`).
  final String? category;

  /// 스토리지 키(옵션).
  final String? storageKey;

  /// `POST /place-photos/upload` 가 DB 행까지 만들었을 때 `true` → 이어서 `POST /place-photos` 생략.
  final bool skipPlacePhotoCreate;

  factory ImageUploadResult.fromJson(Map<String, dynamic> m) {
    final display = saString(m['display_url']) ?? '';
    final original = saString(m['original_url']) ?? '';
    final originalName =
        saString(m['originalname']) ?? saString(m['original_name']) ?? '';
    if (display.isEmpty && original.isEmpty) {
      throw StateError(
        'uploads/image 응답에 display_url 또는 original_url 이 없습니다.',
      );
    }
    final resolvedDisplay = display.isNotEmpty ? display : original;
    final resolvedOriginal = original.isNotEmpty ? original : resolvedDisplay;
    return ImageUploadResult(
      displayUrl: resolvedDisplay,
      originalUrl: resolvedOriginal,
      originalname: originalName.isNotEmpty
          ? originalName
          : _basenameFromUrl(resolvedOriginal),
      category: saString(m['category']),
      storageKey: saString(m['storage_key']) ?? saString(m['storageKey']),
      skipPlacePhotoCreate: false,
    );
  }

  /// [`POST /place-photos/upload`] 응답 — `phid` 가 있으면 서버가 행까지 생성한 것으로 보고
  /// [skipPlacePhotoCreate] 를 켠다.
  factory ImageUploadResult.fromPlacePhotoUploadResponse(
    Map<String, dynamic> raw,
  ) {
    Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    final wrapped = m['data'];
    if (wrapped is Map) {
      m = Map<String, dynamic>.from(wrapped);
    }
    _mergePlacePhotoUploadNested(m);
    final display = saString(m['display_url']) ?? '';
    final originalUrl = saString(m['original_url']) ?? '';
    final legacyPhoto = saString(m['photourl']) ?? '';
    final resolved = display.isNotEmpty
        ? display
        : (originalUrl.isNotEmpty ? originalUrl : legacyPhoto);
    final phid = _readPhidFromUploadMap(m);
    if (resolved.isEmpty && phid <= 0) {
      throw StateError(
        'place-photos/upload 응답에 display_url·original_url·photourl 또는 phid 가 없습니다.',
      );
    }
    final disp = resolved.isNotEmpty ? resolved : originalUrl;
    final orig = originalUrl.isNotEmpty ? originalUrl : disp;
    final on =
        saString(m['originalname']) ?? saString(m['original_name']) ?? '';
    return ImageUploadResult(
      displayUrl: disp.isNotEmpty ? disp : orig,
      originalUrl: orig.isNotEmpty ? orig : disp,
      originalname:
          on.isNotEmpty ? on : _basenameFromUrl(orig.isNotEmpty ? orig : disp),
      category: saString(m['category']),
      storageKey: saString(m['storage_key']) ?? saString(m['storageKey']),
      skipPlacePhotoCreate: phid > 0,
    );
  }

  static String guessOriginalnameFallback(String absolutePath) {
    return p.basename(absolutePath);
  }
}

/// `place_photo`·`photo` 등 한 단계 중첩에서 URL·PK를 끌어올려 평탄화.
void _mergePlacePhotoUploadNested(Map<String, dynamic> m) {
  const nestKeys = <String>['place_photo', 'placePhoto', 'photo', 'row'];
  for (final nk in nestKeys) {
    final v = m[nk];
    if (v is! Map) continue;
    final sm = Map<String, dynamic>.from(v);
    void take(String a, [String? b]) {
      final keys = b == null ? <String>[a] : <String>[a, b];
      for (final k in keys) {
        if (m[k] != null &&
            m[k].toString().trim().isNotEmpty &&
            m[k].toString() != '0') {
          return;
        }
      }
      for (final k in keys) {
        final sv = sm[k];
        if (sv != null && sv.toString().trim().isNotEmpty) {
          m[k] = sv;
          return;
        }
      }
    }

    take('display_url', 'displayUrl');
    take('original_url', 'originalUrl');
    take('photourl', 'photoUrl');
    take('originalname', 'original_name');
    take('phid', 'photo_id');
  }
}

int _readPhidFromUploadMap(Map<String, dynamic> m) {
  int? p = saInt(m['phid']);
  if (p != null && p > 0) return p;
  p = saInt(m['photo_id']) ?? saInt(m['photoId']);
  if (p != null && p > 0) return p;
  for (final nk in const <String>['place_photo', 'placePhoto', 'photo']) {
    final v = m[nk];
    if (v is! Map) continue;
    final sm = Map<String, dynamic>.from(v);
    p = saInt(sm['phid']) ?? saInt(sm['photo_id']);
    if (p != null && p > 0) return p;
  }
  return 0;
}

String _basenameFromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    return seg.isNotEmpty ? seg : '';
  } catch (_) {
    return '';
  }
}
