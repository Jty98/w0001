import 'package:w0001/data/model/place_photo_entry.dart';

class PlacePhotoGroupModel {
  final int pgid;
  final int pid;
  final String photoDate; // yyyy-MM-dd
  final String photoType; // site | drawing
  final String title;
  final int sortOrder;
  final int createdAtMs;
  final List<PlacePhotoEntry> photos;

  const PlacePhotoGroupModel({
    required this.pgid,
    required this.pid,
    required this.photoDate,
    required this.photoType,
    required this.title,
    required this.sortOrder,
    required this.createdAtMs,
    required this.photos,
  });

  int get photoCount => photos.length;

  /// 그리드·썸네일용 URL 목록 (WebP 등).
  List<String> get photoUrls => photos.map((e) => e.displayUrl).toList();

  factory PlacePhotoGroupModel.fromMap(Map<String, Object?> map) {
    final rawUrls = (map['photoUrls'] as String?) ?? '';
    final urls = rawUrls.trim().isEmpty
        ? <String>[]
        : rawUrls
            .split('|||')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    return PlacePhotoGroupModel(
      pgid: (map['pgid'] as int?) ?? 0,
      pid: (map['pid'] as int?) ?? 0,
      photoDate: (map['photoDate'] as String?) ?? '',
      photoType: (map['photoType'] as String?) ?? 'site',
      title: (map['title'] as String?) ?? '',
      sortOrder: (map['sortOrder'] as int?) ?? 0,
      createdAtMs: (map['createdAtMs'] as int?) ?? 0,
      photos: urls
          .map(
            (u) => PlacePhotoEntry(phid: 0, displayUrl: u),
          )
          .toList(),
    );
  }
}
