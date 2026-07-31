import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/remote_list_pages.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/human_private_models.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/api_endpoint.dart';

final class HumansRemoteApi {
  HumansRemoteApi(this._http);

  final AppHttpClient _http;

  Future<PagedResult<HumanRead>> listPage(ListQuery query) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.humans,
      queryParameters: query.toQueryParameters(),
    );
    return saParsePagedList(r.data, HumanRead.fromJson);
  }

  Future<List<HumanRead>> listAll(ListQuery query) =>
      fetchAllListPages(listPage, query);

  Future<List<HumanRead>> list() => listAll(const ListQuery());

  Future<HumanRead> get(int hid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.humansHid(hid));
    return HumanRead.fromJson(saParseObject(r.data));
  }

  /// 여러 인력을 한 번에 조회 (N+1 쿼리 방지)
  Future<List<HumanRead>> getBatch(List<int> hids) async {
    if (hids.isEmpty) return [];

    final r = await _http.post<dynamic>(
      '${ApiEndpoint.humans}/batch',
      data: {'hids': hids},
    );

    // 서버 응답이 List<HumanRead> 형태
    return saMapList(r.data, HumanRead.fromJson);
  }

  Future<HumanPrivateRead> getPrivate(int hid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.humansHidPrivate(hid));
    final data = r.data;
    if (data is! Map) {
      throw const FormatException('인력 민감정보 응답 형식이 올바르지 않습니다.');
    }
    return HumanPrivateRead.fromJson(Map<String, dynamic>.from(data));
  }

  Future<HumanPrivateRead> patchPrivate(
    int hid,
    Map<String, dynamic> body,
  ) async {
    final r = await _http.patch<dynamic>(
      ApiEndpoint.humansHidPrivate(hid),
      data: body,
    );
    final data = r.data;
    if (data is! Map) {
      throw const FormatException('인력 민감정보 응답 형식이 올바르지 않습니다.');
    }
    return HumanPrivateRead.fromJson(Map<String, dynamic>.from(data));
  }

  Future<HumanRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.humans, data: body);
    return HumanRead.fromJson(saParseObject(r.data));
  }

  Future<HumanRead> patch(int hid, Map<String, dynamic> body) async {
    final r =
        await _http.patch<dynamic>(ApiEndpoint.humansHid(hid), data: body);
    return HumanRead.fromJson(saParseObject(r.data));
  }

  Future<void> delete(int hid) async {
    await _http.delete<dynamic>(ApiEndpoint.humansHid(hid));
  }

  Future<String> revealRrn({
    required int hid,
    required String reason,
  }) async {
    return _postRevealWithLegacyFallback(
      primary: ApiEndpoint.humansHidPrivateRrnReveal(hid),
      legacy: ApiEndpoint.humansHidRrnRevealLegacy(hid),
      reason: reason,
      keys: const ['rrn', 'hnumber', 'value', 'revealed_value'],
    );
  }

  Future<String> revealHphone({
    required int hid,
    required String reason,
  }) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.humansHidPrivateHphoneReveal(hid),
      data: _revealBody(reason),
    );
    return _extractRevealedValue(
      res.data,
      const ['hphone', 'phone', 'value', 'revealed_value'],
    );
  }

  Future<String> revealLinkedPhone({
    required int hid,
    required String reason,
  }) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.humansHidPrivateLinkedPhoneReveal(hid),
      data: _revealBody(reason),
    );
    return _extractRevealedValue(
      res.data,
      const ['linked_phone', 'linkedPhone', 'phone', 'value', 'revealed_value'],
    );
  }

  Future<String> revealBankAccount({
    required int hid,
    required String reason,
  }) async {
    final res = await _http.post<dynamic>(
      ApiEndpoint.humansHidPrivateBankReveal(hid),
      data: _revealBody(reason),
    );
    return _extractRevealedValue(
      res.data,
      const ['bank_account', 'bankAccount', 'value', 'revealed_value'],
    );
  }

  /// 현장에서 최근 작업한 인원 목록 조회 (통합 API)
  Future<List<HumanRead>> getPlaceRecentWorkers({
    required int pid,
    int limit = 100,
    int offset = 0,
  }) async {
    final startTime = DateTime.now();
    final endpoint = ApiEndpoint.placesRecentWorkers(pid);
    print('🌐 [API 요청] GET $endpoint?limit=$limit&offset=$offset');

    try {
      final res = await _http.get<dynamic>(
        endpoint,
        queryParameters: <String, dynamic>{
          'limit': limit,
          'offset': offset,
        },
      );

      final requestDuration =
          DateTime.now().difference(startTime).inMilliseconds;
      print(
          '📡 [API 응답] HTTP ${res.statusCode}, 서버 응답 시간: ${requestDuration}ms');

      final parseStart = DateTime.now();
      final data = res.data;
      if (data is! List) {
        print('❌ [API 에러] 응답 형식 오류: ${data.runtimeType}');
        throw const FormatException('현장 작업자 목록 응답 형식이 올바르지 않습니다.');
      }

      print('📦 [API 데이터] 받은 작업자 수: ${data.length}명');

      final result =
          data.map((item) => HumanRead.fromJson(saParseObject(item))).toList();

      final parseDuration =
          DateTime.now().difference(parseStart).inMilliseconds;
      final totalDuration = DateTime.now().difference(startTime).inMilliseconds;

      print('⚙️ [파싱] JSON 파싱 시간: ${parseDuration}ms');
      print('✅ [API 완료] 총 API 시간: ${totalDuration}ms');

      return result;
    } catch (e) {
      final errorDuration = DateTime.now().difference(startTime).inMilliseconds;
      print('❌ [API 에러] 요청 실패 (${errorDuration}ms): $e');
      print('💡 [확인 사항] 서버에 /places/{pid}/recent-workers 엔드포인트가 있는지 확인하세요');
      rethrow;
    }
  }

  Future<String> _postRevealWithLegacyFallback({
    required String primary,
    required String legacy,
    required String reason,
    required List<String> keys,
  }) async {
    try {
      final res = await _http.post<dynamic>(primary, data: _revealBody(reason));
      return _extractRevealedValue(res.data, keys);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final res =
            await _http.post<dynamic>(legacy, data: _revealBody(reason));
        return _extractRevealedValue(res.data, keys);
      }
      rethrow;
    }
  }
}

Map<String, dynamic> _revealBody(String reason) =>
    <String, dynamic>{'reason': reason.trim()};

String _extractRevealedValue(Object? data, List<String> keys) {
  if (data is! Map) {
    throw const FormatException('민감정보 조회 응답 형식이 올바르지 않습니다.');
  }
  final m = Map<String, dynamic>.from(data);
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  throw const FormatException('민감정보 조회 응답에 값이 없습니다.');
}
