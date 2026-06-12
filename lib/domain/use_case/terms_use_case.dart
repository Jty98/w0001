import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/domain/repository/terms_abst.dart';

class TermsUseCase {
  TermsUseCase(this._repository);

  final TermsRepository _repository;

  Future<List<TermSummary>> listLatest() => _repository.listLatest();

  Future<List<TermSummary>> listSignupTerms() => _repository.listSignupTerms();

  Future<TermDetail> getTermDetail(int id) => _repository.getTermDetail(id);

  Future<List<TermAgreementRead>> myAgreements({String? type}) =>
      _repository.myAgreements(type: type);
}
