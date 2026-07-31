/// 현장 문서 한 건(사진·도면·PDF·엑셀 등) — 그리드·공유 등 UI용.
class PlacePhotoEntry {
  const PlacePhotoEntry({
    required this.phid,
    required this.displayUrl,
    this.originalName,
    this.originalUrl,
    this.mediaKind,
    this.createdByUid,
    this.authorDisplayName,
    this.memo,
  });

  /// 서버 행 PK. 로컬/시드만 있거나 미동기 시 0일 수 있음.
  final int phid;

  /// 썸네일·표시(WebP `display_url` 등).
  final String displayUrl;

  /// DB `originalname` (원본 저장 시 파일명에 사용 가능).
  final String? originalName;

  /// 원본 파일 URL (`original_url`). 썸네일만 있을 때 확장자 힌트용.
  final String? originalUrl;

  /// `image` | `document` 등 서버 `mediakind`.
  final String? mediaKind;

  /// PDF·엑셀 등 비이미지 원본 (`mediakind == document`).
  bool get isDocumentMedia => mediaKind?.trim().toLowerCase() == 'document';

  /// 업로더 계정 UID ([UsersRemoteApi.get] 등으로 이름 보강).
  final String? createdByUid;

  /// 캐시된 표시명 (없으면 UID 일부만 표시).
  final String? authorDisplayName;

  /// 서버 `memo` 등 — 장당 현장 메모 (PATCH로 수정).
  final String? memo;

  bool get canFetchOriginalViaApi => phid > 0;

  bool get hasMemo => memo != null && memo!.trim().isNotEmpty;

  PlacePhotoEntry copyWith({
    int? phid,
    String? displayUrl,
    String? originalName,
    String? originalUrl,
    String? mediaKind,
    String? createdByUid,
    String? authorDisplayName,
    String? memo,
  }) =>
      PlacePhotoEntry(
        phid: phid ?? this.phid,
        displayUrl: displayUrl ?? this.displayUrl,
        originalName: originalName ?? this.originalName,
        originalUrl: originalUrl ?? this.originalUrl,
        mediaKind: mediaKind ?? this.mediaKind,
        createdByUid: createdByUid ?? this.createdByUid,
        authorDisplayName: authorDisplayName ?? this.authorDisplayName,
        memo: memo ?? this.memo,
      );
}
