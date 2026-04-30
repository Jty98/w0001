import 'package:path/path.dart' as p;

import 'package:w0001/data/model/remote/super_admin_json.dart';

/// [`POST /uploads/image`] multipart 필드 `category` 값.
enum ImageUploadCategory {
  /// 현장 사진 (`place_image`)
  placeImage('place_image'),
  /// 도면·계획 사진 (`plan_image`)
  planImage('plan_image');

  const ImageUploadCategory(this.serverValue);

  final String serverValue;

  /// `PlacePhotoGroup` 의 `phototype` (`site` | `drawing`) 에 맞춤.
  static ImageUploadCategory fromPlacePhotoType(String phototype) {
    switch (phototype) {
      case 'drawing':
        return ImageUploadCategory.planImage;
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
  });

  /// 리사이즈·CDN 등 사용자에게 보여 줄 URL (없으면 [originalUrl]과 동일 취급).
  final String displayUrl;
  final String originalUrl;
  final String originalname;
  /// 응답에 포함될 수 있음 (`place_image` | `plan_image`).
  final String? category;
  /// 스토리지 키(옵션).
  final String? storageKey;

  factory ImageUploadResult.fromJson(Map<String, dynamic> m) {
    final display = saString(m['display_url']) ?? '';
    final original = saString(m['original_url']) ?? '';
    final originalName = saString(m['originalname']) ??
        saString(m['original_name']) ??
        '';
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
    );
  }

  static String guessOriginalnameFallback(String absolutePath) {
    return p.basename(absolutePath);
  }
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
