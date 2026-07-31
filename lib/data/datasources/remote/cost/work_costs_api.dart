import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/remote_list_pages.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/paged_result.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/work_cost_period_totals.dart';
import 'package:w0001/data/model/work_cost_worker_summary.dart';
import 'package:w0001/util/api_endpoint.dart';

final class WorkCostsRemoteApi {
  WorkCostsRemoteApi(this._http);

  final AppHttpClient _http;

  Future<PagedResult<WorkCostRead>> listPage(ListQuery query) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.workCosts,
      queryParameters: query.toQueryParameters(),
    );
    return saParsePagedList(r.data, WorkCostRead.fromJson);
  }

  Future<List<WorkCostRead>> listAll(ListQuery query) =>
      fetchAllListPages(listPage, query);

  Future<List<WorkCostRead>> list() => listAll(const ListQuery());

  Future<WorkCostRead> get(int wid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.workCostsWid(wid));
    return WorkCostRead.fromJson(saParseObject(r.data));
  }

  Future<WorkCostRead> create(Map<String, dynamic> body) async {
    final r = await _http.post<dynamic>(ApiEndpoint.workCosts, data: body);
    return WorkCostRead.fromJson(saParseObject(r.data));
  }

  Future<WorkCostRead> patch(int wid, Map<String, dynamic> body) async {
    final r =
        await _http.patch<dynamic>(ApiEndpoint.workCostsWid(wid), data: body);
    return WorkCostRead.fromJson(saParseObject(r.data));
  }

  /// 경량 지급상태 토글 ACK (`PATCH /work-costs/{wid}/complete`).
  ///
  /// 서버 응답은 `wid/wcomplete/updated_at/wcompleted_at`만 내려올 수 있어
  /// 목록 모델 파싱 없이 성공 여부만 확인합니다.
  Future<void> patchComplete(int wid, int wcomplete) async {
    await _http.patch<dynamic>(
      ApiEndpoint.workCostsWidComplete(wid),
      data: <String, dynamic>{'wcomplete': wcomplete},
    );
  }

  Future<void> delete(int wid) async {
    await _http.delete<dynamic>(ApiEndpoint.workCostsWid(wid));
  }

  /// 기간·필터 집계. 서버 미구현(404)이면 null.
  Future<WorkCostPeriodTotals?> fetchPeriodTotals(ListQuery query) async {
    try {
      final r = await _http.get<dynamic>(
        ApiEndpoint.workCostsTotals,
        queryParameters: query.toQueryParameters(),
      );
      return WorkCostPeriodTotals.fromJson(saParseObject(r.data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 인력별 요약 목록(1단 UI용). 서버 미구현(404)이면 null.
  Future<PagedResult<WorkCostWorkerSummary>?> fetchWorkerSummariesPage(
    ListQuery query,
  ) async {
    try {
      final r = await _http.get<dynamic>(
        ApiEndpoint.workCostsWorkerSummaries,
        queryParameters: query.toQueryParameters(),
      );
      return saParsePagedList(r.data, WorkCostWorkerSummary.fromJson);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
