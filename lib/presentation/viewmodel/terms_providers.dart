import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/terms/terms_api.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/data/repository/terms_impl.dart';
import 'package:w0001/domain/repository/terms_abst.dart';
import 'package:w0001/domain/use_case/terms_use_case.dart';

final termsApiProvider = Provider<TermsApi>(
  (ref) => TermsApi(AppHttpClient.I),
);

final termsRepositoryProvider = Provider<TermsRepository>(
  (ref) => TermsRepositoryImpl(ref.read(termsApiProvider)),
);

final termsUseCaseProvider = Provider<TermsUseCase>(
  (ref) => TermsUseCase(ref.read(termsRepositoryProvider)),
);

/// 회원가입용 필수 약관 목록.
final signupTermsProvider = FutureProvider<List<TermSummary>>((ref) async {
  return ref.read(termsUseCaseProvider).listSignupTerms();
});

/// 본인 세무정보(`worker_tax`) 약관 동의 이력.
final workerTaxAgreementsProvider =
    FutureProvider<List<TermAgreementRead>>((ref) async {
  return ref.read(termsUseCaseProvider).myAgreements(type: 'worker_tax');
});
