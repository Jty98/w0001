import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/terms_models.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 약관 공개 API (`GET /terms`, `GET /terms/{id}`).
final class TermsApi {
  TermsApi(this._http);

  final AppHttpClient _http;

  Future<List<TermSummary>> listLatest() async {
    final res = await _http.get<dynamic>(ApiEndpoint.terms);
    return parseTermSummaryList(res.data);
  }

  Future<TermDetail> getById(int id) async {
    final res = await _http.get<dynamic>(ApiEndpoint.termById(id));
    final data = res.data;
    if (data is! Map) {
      throw const FormatException('약관 응답 형식이 올바르지 않습니다.');
    }
    return TermDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<TermAgreementRead>> myAgreements({String? type}) async {
    final res = await _http.get<dynamic>(
      ApiEndpoint.usersMeTerms,
      queryParameters: type != null && type.trim().isNotEmpty
          ? <String, dynamic>{'type': type.trim()}
          : null,
    );
    return parseTermAgreementList(res.data);
  }
}
