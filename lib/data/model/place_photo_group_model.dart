class PlacePhotoGroupModel {
  final int pgid;
  final int pid;
  final String photoDate; // yyyy-MM-dd
  final String title;
  final int sortOrder;
  final int createdAtMs;
  final int photoCount;
  final List<String> photoUrls;

  const PlacePhotoGroupModel({
    required this.pgid,
    required this.pid,
    required this.photoDate,
    required this.title,
    required this.sortOrder,
    required this.createdAtMs,
    required this.photoCount,
    required this.photoUrls,
  });

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
      title: (map['title'] as String?) ?? '',
      sortOrder: (map['sortOrder'] as int?) ?? 0,
      createdAtMs: (map['createdAtMs'] as int?) ?? 0,
      photoCount: (map['photoCount'] as int?) ?? 0,
      photoUrls: urls,
    );
  }
}
