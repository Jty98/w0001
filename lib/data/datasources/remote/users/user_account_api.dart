import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/user_account_models.dart';
import 'package:w0001/util/api_endpoint.dart';

final class UserAccountRemoteApi {
  UserAccountRemoteApi(this._http);

  final AppHttpClient _http;

  Future<UserAccountRead> getMine() async {
    final res = await _http.get<dynamic>(ApiEndpoint.usersMeAccount);
    return UserAccountRead.fromJson(saParseObject(res.data));
  }

  Future<UserAccountRead> patchMine(Map<String, dynamic> body) async {
    final res = await _http.patch<dynamic>(
      ApiEndpoint.usersMeAccount,
      data: body,
    );
    return UserAccountRead.fromJson(saParseObject(res.data));
  }
}
