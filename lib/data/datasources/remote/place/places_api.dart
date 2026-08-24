import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/remote_list_pages.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlacesRemoteApi {
  PlacesRemoteApi(this._http);

  final AppHttpClient _http;

  Future<PagedResult<PlaceRead>> listPage(ListQuery query) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.places,
      queryParameters: query.toQueryParameters(),
    );
    return saParsePagedList(r.data, PlaceRead.fromJson);
  }

  Future<List<PlaceRead>> listAll(ListQuery query) =>
      fetchAllListPages(listPage, query);

  Future<List<PlaceRead>> list() => listAll(const ListQuery());

  /// 워커 등 — `GET /places/me` (스코프 현장, cursor 페이지).
  Future<PagedResult<PlaceRead>> listMinePage(ListQuery query) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.placesMe,
      queryParameters: query.toQueryParameters(),
    );
    return saParsePagedList(r.data, PlaceRead.fromJson);
  }

  Future<List<PlaceRead>> listMineAll(ListQuery query) =>
      fetchAllListPages(listMinePage, query);

  Future<List<PlaceRead>> listMine() => listMineAll(const ListQuery());

  Future<PlaceRead> get(int pid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.placesPid(pid));
    return PlaceRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.places, data: body);
    return PlaceRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceRead> patch(int pid, Map<String, dynamic> body) async {
    final r =
        await _http.patch<dynamic>(ApiEndpoint.placesPid(pid), data: body);
    return PlaceRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int pid, {bool permanent = false}) async {
    await _http.delete<dynamic>(
      ApiEndpoint.placesPid(pid),
      queryParameters: permanent ? const <String, dynamic>{'permanent': true} : null,
    );
  }

  /// 기간별 일괄 인력투입
  Future<Map<String, dynamic>> bulkAssignWorkforce({
    required int pid,
    required Map<String, dynamic> body,
  }) async {
    print('📞 [API] POST /places/$pid/workforce/bulk-assign');
    print('   - Body: $body');

    final startTime = DateTime.now();
    final r = await _http.post<dynamic>(
      ApiEndpoint.placesWorkforceBulkAssign(pid),
      data: body,
    );
    final duration = DateTime.now().difference(startTime).inMilliseconds;

    print('✅ [API] 일괄 투입 완료: ${duration}ms');

    if (r.data is! Map) {
      throw const FormatException('일괄 투입 응답 형식이 올바르지 않습니다.');
    }

    return Map<String, dynamic>.from(r.data as Map);
  }
}
