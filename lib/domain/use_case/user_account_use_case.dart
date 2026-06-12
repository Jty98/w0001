import 'package:w0001/data/datasources/remote/users/user_account_api.dart';
import 'package:w0001/data/model/user_account_models.dart';

class UserAccountUseCase {
  UserAccountUseCase(this._api);

  final UserAccountRemoteApi _api;

  Future<UserAccountRead> getMine() => _api.getMine();

  Future<UserAccountRead> updateName(String uname) => _api.patchMine(
        userAccountPatchBody(uname: uname),
      );

  Future<UserAccountRead> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _api.patchMine(
        userAccountPatchBody(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );

  Future<UserAccountRead> updatePhone({
    required String phone,
    required String phoneVerificationToken,
  }) =>
      _api.patchMine(
        userAccountPatchBody(
          phone: phone,
          phoneVerificationToken: phoneVerificationToken,
        ),
      );
}
