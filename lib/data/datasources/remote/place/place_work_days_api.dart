import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlaceWorkDaysRemoteApi {
  PlaceWorkDaysRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<PlaceWorkDayRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.placeWorkDays);
    return saMapList(r.data, PlaceWorkDayRead.fromJson);
  }

  Future<PlaceWorkDayRead> get(int pwdid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.placeWorkDaysId(pwdid));
    return PlaceWorkDayRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceWorkDayRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.placeWorkDays, data: body);
    return PlaceWorkDayRead.fromJson(saParseObject(r.data));
  }

  Future<PlaceWorkDayRead> patch(int pwdid, Map<String, dynamic> body) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.placeWorkDaysId(pwdid),
      data: body,
    );
    return PlaceWorkDayRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int pwdid) async {
    await _http.delete<dynamic>(ApiEndpoint.placeWorkDaysId(pwdid));
  }
}
