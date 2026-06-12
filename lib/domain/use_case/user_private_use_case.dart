import 'package:w0001/data/datasources/remote/users/user_private_api.dart';
import 'package:w0001/data/model/user_private_models.dart';

class UserPrivateUseCase {
  UserPrivateUseCase(this._api);

  final UserPrivateRemoteApi _api;

  Future<UserPrivateRead> getMine() => _api.getMine();

  Future<UserPrivateRead> getWorkerPrivate(String uid) =>
      _api.getWorkerPrivate(uid);

  Future<String> revealWorkerRrn({
    required String uid,
    required String reason,
  }) =>
      _api.revealWorkerRrn(uid: uid, reason: reason);

  Future<String> revealWorkerBankAccount({
    required String uid,
    required String reason,
  }) =>
      _api.revealWorkerBankAccount(uid: uid, reason: reason);

  Future<UserPrivateRead> saveMine({
    String? rrn,
    String? bankAccount,
    String? bankOwner,
    String? bankName,
    int? workerTaxTermId,
    String? workerTaxTermVersion,
  }) {
    return _api.patchMine(
      userPrivatePatchBody(
        rrn: rrn,
        bankAccount: bankAccount,
        bankOwner: bankOwner,
        bankName: bankName,
        workerTaxTermId: workerTaxTermId,
        workerTaxTermVersion: workerTaxTermVersion,
      ),
    );
  }
}
