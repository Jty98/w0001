import 'package:w0001/data/datasources/remote/terms/terms_api.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/domain/repository/terms_abst.dart';

class TermsRepositoryImpl implements TermsRepository {
  TermsRepositoryImpl(this._api);

  final TermsApi _api;

  @override
  Future<List<TermSummary>> listLatest() => _api.listLatest();

  @override
  Future<List<TermSummary>> listSignupTerms() async {
    final all = await _api.listLatest();
    return all.where((t) => t.type.isSignupTerm).toList(growable: false);
  }

  Future<TermSummary?> findWorkerTaxTerm() async {
    final all = await _api.listLatest();
    for (final t in all) {
      if (t.type == TermType.workerTax) return t;
    }
    return null;
  }

  @override
  Future<TermDetail> getTermDetail(int id) => _api.getById(id);

  @override
  Future<List<TermAgreementRead>> myAgreements({String? type}) =>
      _api.myAgreements(type: type);
}
