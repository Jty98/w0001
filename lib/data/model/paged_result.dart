/// 서버 cursor 페이지 응답 (`items`, `next_cursor`, `has_more`, `total`).
class PagedResult<T> {
  const PagedResult({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.totalCount,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  /// 서버가 내려주면 탭·목록 총 개수 표시에 사용.
  final int? totalCount;

  /// 스크롤 load-more: `has_more` 이고 `next_cursor` 가 있을 때만 true.
  bool get canLoadMore =>
      hasMore && nextCursor != null && nextCursor!.trim().isNotEmpty;

  PagedResult<T> copyWith({
    List<T>? items,
    String? nextCursor,
    bool? hasMore,
    int? totalCount,
  }) {
    return PagedResult<T>(
      items: items ?? this.items,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

/// id 기준 중복 없이 페이지를 이어 붙인다.
List<T> mergePagedItems<T>(
  List<T> existing,
  List<T> incoming,
  int? Function(T item) idOf,
) {
  if (incoming.isEmpty) return existing;
  final seen = <int>{};
  final out = <T>[];
  for (final e in existing) {
    final id = idOf(e);
    if (id != null) {
      if (!seen.add(id)) continue;
    }
    out.add(e);
  }
  for (final e in incoming) {
    final id = idOf(e);
    if (id != null) {
      if (seen.contains(id)) continue;
      seen.add(id);
    }
    out.add(e);
  }
  return out;
}
