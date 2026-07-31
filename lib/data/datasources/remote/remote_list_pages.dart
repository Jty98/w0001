import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/model/paged_result.dart';

/// [fetchPage]를 cursor로 반복 호출해 모든 페이지를 합친다.
Future<List<T>> fetchAllListPages<T>(
  Future<PagedResult<T>> Function(ListQuery query) fetchPage,
  ListQuery baseQuery,
) async {
  final out = <T>[];
  String? cursor;
  var guard = 0;
  while (guard < 500) {
    guard++;
    final q = cursor == null
        ? baseQuery.copyWith(clearCursor: true)
        : baseQuery.copyWith(cursor: cursor);
    final page = await fetchPage(q);
    out.addAll(page.items);
    if (!page.canLoadMore) break;
    cursor = page.nextCursor!.trim();
  }
  return out;
}
