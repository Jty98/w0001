import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/remote_list_pages.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class ScheduleMemosRemoteApi {
  ScheduleMemosRemoteApi(this._http);

  final AppHttpClient _http;

  Future<PagedResult<ScheduleMemoRead>> listPage(ListQuery query) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.scheduleMemos,
      queryParameters: query.toQueryParameters(),
    );
    return saParsePagedList(r.data, ScheduleMemoRead.fromJson);
  }

  Future<List<ScheduleMemoRead>> listAll(ListQuery query) =>
      fetchAllListPages(listPage, query);

  Future<List<ScheduleMemoRead>> list() => listAll(const ListQuery());

  Future<ScheduleMemoRead> get(int sid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.scheduleMemosSid(sid));
    return ScheduleMemoRead.fromJson(saParseObject(r.data));
  }

  Future<ScheduleMemoRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.scheduleMemos, data: body);
    return ScheduleMemoRead.fromJson(saParseObject(r.data));
  }

  Future<ScheduleMemoRead> patch(int sid, Map<String, dynamic> body) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.scheduleMemosSid(sid),
      data: body,
    );
    return ScheduleMemoRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int sid) async {
    await _http.delete<dynamic>(ApiEndpoint.scheduleMemosSid(sid));
  }
}
