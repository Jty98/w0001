import 'package:w0001/data/model/terms_models.dart';

abstract class TermsRepository {
  Future<List<TermSummary>> listLatest();
  Future<List<TermSummary>> listSignupTerms();
  Future<TermDetail> getTermDetail(int id);
  Future<List<TermAgreementRead>> myAgreements({String? type});
}
