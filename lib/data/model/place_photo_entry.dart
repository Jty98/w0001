/// 현장 사진 한 장 — 그리드/공유 등 UI용.
class PlacePhotoEntry {
  const PlacePhotoEntry({
    required this.phid,
    required this.displayUrl,
    this.originalName,
  });

  /// 서버 행 PK. 로컬/시드만 있거나 미동기 시 0일 수 있음.
  final int phid;

  /// 썸네일·표시(WebP `display_url` 등).
  final String displayUrl;

  /// DB `originalname` (원본 저장 시 파일명에 사용 가능).
  final String? originalName;

  bool get canFetchOriginalViaApi => phid > 0;
}
