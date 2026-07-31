import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/remote_list_pages.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlaceRevenuesRemoteApi {
  PlaceRevenuesRemoteApi(this._http);

  final AppHttpClient _http;

  Future<PagedResult<PlaceRevenueRead>> listPage(ListQuery query) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.placeRevenues,
      queryParameters: query.toQueryParameters(),
    );
    return saParsePagedList(r.data, PlaceRevenueRead.fromJson);
  }

  Future<List<PlaceRevenueRead>> listAll(ListQuery query) =>
      fetchAllListPages(listPage, query);

  Future<List<PlaceRevenueRead>> list() => listAll(const ListQuery());

  Future<PlaceRevenueRead> get(int rid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.placeRevenuesRid(rid));
    return PlaceRevenueRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceRevenueRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.placeRevenues, data: body);
    return PlaceRevenueRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceRevenueRead> patch(int rid, Map<String, dynamic> body) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.placeRevenuesRid(rid),
      data: body,
    );
    return PlaceRevenueRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int rid) async {
    await _http.delete<dynamic>(ApiEndpoint.placeRevenuesRid(rid));
  }
}
