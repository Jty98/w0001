import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class ScheduleMemosRemoteApi {
  ScheduleMemosRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<ScheduleMemoRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.scheduleMemos);
    return saMapList(r.data, ScheduleMemoRead.fromJson);
  }

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
