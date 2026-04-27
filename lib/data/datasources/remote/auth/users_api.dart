import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class UsersRemoteApi {
  UsersRemoteApi(this._http);

  final AppHttpClient _http;

  Future<List<UserRead>> list() async {
    final r = await _http.get<dynamic>(ApiEndpoint.users);
    return saMapList(r.data, userReadFromJson);
  }

  Future<UserRead> get(String uid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.usersUid(uid));
    return userReadFromJson(saParseObject(r.data));
  }

  Future<UserRead> create(UserCreateBody body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.users, data: body.toJson());
    return userReadFromJson(saParseObject(r.data));
  }

  Future<UserRead> patch(String uid, Map<String, dynamic> body) async {
    final r = await _http.patch<dynamic>(ApiEndpoint.usersUid(uid), data: body);
    return userReadFromJson(saParseObject(r.data));
  }

  Future<void> delete(String uid) async {
    await _http.delete<dynamic>(ApiEndpoint.usersUid(uid));
  }
}
