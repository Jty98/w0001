import 'package:dio/dio.dart';
import 'package:w0001/model/human_model.dart';
import 'package:w0001/model/materialcost_model.dart';
import 'package:w0001/model/place_dropdown_model.dart';
import 'package:w0001/model/place_info_model.dart';
import 'package:w0001/model/place_model.dart';
import 'package:w0001/model/revenue_model.dart';
import 'package:w0001/model/total_cost_model.dart';
import 'package:w0001/model/total_workcost_model.dart';
import 'package:w0001/model/workcost_model.dart';

/// 원격 데이터소스 (백엔드 API 통신)
/// Flutter 앱은 HTTP를 통해 백엔드 서버와 통신합니다.
/// 백엔드 서버가 PostgreSQL과 직접 통신합니다.
class RemoteDataSource {
  final Dio _dio;
  final String baseUrl;

  RemoteDataSource({
    required this.baseUrl,
    String? apiKey,
    Map<String, String>? headers,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (apiKey != null) 'Authorization': 'Bearer $apiKey',
              ...?headers,
            },
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ) {
    // 에러 인터셉터 추가 (선택사항)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          // 에러 처리 로직
          return handler.next(error);
        },
      ),
    );
  }

  // ==================== Place 관련 API ====================

  /// 모든 현장 정보 조회
  Future<List<PlaceInfoModel>> getAllPlaces() async {
    final response = await _dio.get('/api/places');
    return (response.data as List)
        .map((json) => PlaceInfoModel.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  /// 현장 추가
  Future<PlaceModel> insertPlace(PlaceModel place) async {
    final response = await _dio.post(
      '/api/places',
      data: {
        'pname': place.pname,
        'pstart': place.pstart,
        'pend': place.pend,
        'pcomplete': place.pcomplete,
        'prevenue': place.prevenue,
      },
    );
    return PlaceModel.fromMap(response.data as Map<String, dynamic>);
  }

  /// 현장 정보 업데이트
  Future<void> updatePlace(PlaceModel placeModel) async {
    await _dio.put(
      '/api/places/${placeModel.pid}',
      data: {
        'pname': placeModel.pname,
        'prevenue': placeModel.prevenue,
      },
    );
  }

  /// 현장 완료 상태 업데이트
  Future<void> updatePlaceCompletionStatus(
    int pid,
    int pcomplete,
    String endDate,
  ) async {
    await _dio.patch(
      '/api/places/$pid/status',
      data: {
        'pcomplete': pcomplete,
        'pend': endDate,
      },
    );
  }

  /// 미완료 현장 목록 조회
  Future<List<PlaceModel>> getIncompletePlaces() async {
    final response = await _dio.get('/api/places?pcomplete=0');
    return (response.data as List)
        .map((json) => PlaceModel.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  /// 현장별 총 비용 조회
  Future<List<TotalCostModel>> getTotalCostsForPlace(int pid) async {
    final response = await _dio.get('/api/places/$pid/costs');
    return (response.data as List)
        .map((json) => TotalCostModel.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  /// CSV용 현장 요약 정보 조회
  Future<List<Map<String, dynamic>>> getPlaceSummaryForCsv(int pid) async {
    final response = await _dio.get('/api/places/$pid/summary/csv');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  /// CSV용 현장 총 비용 조회
  Future<List<Map<String, dynamic>>> getPlaceTotalCostsForCsv(
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) async {
    final response = await _dio.get(
      '/api/places/$pid/costs/csv',
      queryParameters: {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  // ==================== Human 관련 API ====================

  /// 모든 작업자 조회
  Future<List<HumanModel>> getAllWorkers() async {
    final response = await _dio.get('/api/workers');
    return (response.data as List)
        .map((json) => HumanModel.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  /// 작업자 추가
  Future<HumanModel> addWorker(HumanModel worker) async {
    final response = await _dio.post(
      '/api/workers',
      data: {
        'hname': worker.hname,
        'hnumber': worker.hnumber,
        'hmemo': worker.hmemo,
        'hstar': worker.hstar,
      },
    );
    return HumanModel.fromMap(response.data as Map<String, dynamic>);
  }

  /// 작업자 정보 업데이트
  Future<void> updateWorker(HumanModel humanModel) async {
    await _dio.put(
      '/api/workers/${humanModel.hid}',
      data: {
        'hname': humanModel.hname,
        'hnumber': humanModel.hnumber,
        'hmemo': humanModel.hmemo,
      },
    );
  }

  /// 작업자 즐겨찾기 상태 변경
  Future<void> toggleWorkerStarStatus(int hid, bool isStarred) async {
    await _dio.patch(
      '/api/workers/$hid/star',
      data: {'is_starred': isStarred},
    );
  }

  /// 작업자 삭제 (소프트 삭제)
  Future<void> deleteWorker(int hid) async {
    await _dio.delete('/api/workers/$hid');
  }

  // ==================== WorkCost 관련 API ====================

  /// 기간별 인건비 조회
  Future<List<TotalWorkCostModel>> getWorkCostsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _dio.get(
      '/api/work-costs',
      queryParameters: {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
    );
    return (response.data as List)
        .map((json) => TotalWorkCostModel.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  /// 현장별 인건비 조회
  Future<List<WorkCost2Model>> getWorkCostsByPlaceAndDate(
    int hid,
    DateTime startDate,
    DateTime endDate,
    int pid,
  ) async {
    final response = await _dio.get(
      '/api/work-costs',
      queryParameters: {
        'hid': hid,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        if (pid != 0) 'pid': pid,
      },
    );
    return (response.data as List)
        .map((json) => WorkCost2Model.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  /// 인건비 일괄 추가
  Future<bool> addWorkCosts(List<WorkCostModel> wCostList) async {
    try {
      await _dio.post(
        '/api/work-costs/batch',
        data: wCostList.map((w) => {
          'wpid': w.wpid,
          'whid': w.whid,
          'wdate': w.wdate,
          'wprice': w.wprice,
          'wcomplete': w.wcomplete,
        }).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 인건비 항목 수정
  Future<void> updateWorkCostItem(WorkCostModel workCost) async {
    await _dio.put(
      '/api/work-costs/${workCost.wid}',
      data: {
        'wprice': workCost.wprice,
        'wdate': workCost.wdate,
      },
    );
  }

  /// 인건비 완료 상태 토글
  Future<void> toggleWorkCostCompletionStatus(int wcomplete, int wid) async {
    await _dio.patch(
      '/api/work-costs/$wid/complete',
      data: {'wcomplete': wcomplete == 1 ? 0 : 1},
    );
  }

  /// 인건비 완료 상태 일괄 업데이트
  Future<void> updateWorkCostsToComplete(List<int> widList) async {
    await _dio.patch(
      '/api/work-costs/batch/complete',
      data: {'wid_list': widList},
    );
  }

  /// 인건비 삭제
  Future<void> deleteWorkCost(int wid) async {
    await _dio.delete('/api/work-costs/$wid');
  }

  /// CSV용 인건비 상세 조회
  Future<List<Map<String, dynamic>>> getWorkCostDetailsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _dio.get(
      '/api/work-costs/csv/details',
      queryParameters: {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  /// CSV용 인건비 합계 조회
  Future<List<Map<String, dynamic>>> getWorkCostTotalsForCsv(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _dio.get(
      '/api/work-costs/csv/totals',
      queryParameters: {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  /// 현장 드롭다운 목록 조회
  Future<List<PlaceDropDownModel>> getPlacesForWorkCost(int hid) async {
    final response = await _dio.get('/api/workers/$hid/places');
    final placeList = (response.data as List)
        .map((json) => PlaceDropDownModel.fromMap(json as Map<String, dynamic>))
        .toList();
    return [
      PlaceDropDownModel(pname: '전체 현장', pid: 0),
      ...placeList,
    ];
  }

  // ==================== MaterialCost 관련 API ====================

  /// 자재비 일괄 추가
  Future<bool> addMaterialCosts(List<MaterialCostModel> mCostList) async {
    try {
      await _dio.post(
        '/api/material-costs/batch',
        data: mCostList.map((m) => {
          'mpid': m.mpid,
          'mprice': m.mprice,
          'mname': m.mname,
          'mdate': m.mdate,
          'mcategory': m.mcategory,
        }).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 자재비 항목 수정
  Future<void> updateMaterialCostItem(MaterialCostModel materialCost) async {
    await _dio.put(
      '/api/material-costs/${materialCost.mid}',
      data: {
        'mname': materialCost.mname,
        'mprice': materialCost.mprice,
        'mdate': materialCost.mdate,
        'mcategory': materialCost.mcategory,
      },
    );
  }

  /// 자재비 삭제
  Future<void> deleteMaterialCost(int mid) async {
    await _dio.delete('/api/material-costs/$mid');
  }

  // ==================== Calendar 관련 API ====================

  /// 캘린더 이벤트 조회
  Future<Map<String, List<String>>> getAllEvents() async {
    final response = await _dio.get('/api/calendar/events');
    final Map<String, dynamic> data = response.data as Map<String, dynamic>;
    return data.map(
      (key, value) => MapEntry(
        key,
        (value as List).cast<String>(),
      ),
    );
  }

  /// 날짜별 총 비용 조회
  Future<List<TotalCostModel>> getTotalCostsByDate(DateTime dateTime) async {
    final response = await _dio.get(
      '/api/calendar/costs',
      queryParameters: {
        'date': dateTime.toIso8601String(),
      },
    );
    return (response.data as List)
        .map((json) => TotalCostModel.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  // ==================== Revenue 관련 API ====================

  /// 현장 수익 목록 조회
  Future<List<RevenueModel>> getAllRevenues(int placeId) async {
    final response = await _dio.get('/api/places/$placeId/revenues');
    return (response.data as List)
        .map((json) => RevenueModel.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  /// 수익 추가
  Future<RevenueModel> insertRevenue({
    required int pid,
    required int rprice,
    required String rname,
  }) async {
    final response = await _dio.post(
      '/api/places/$pid/revenues',
      data: {
        'rprice': rprice,
        'rname': rname,
      },
    );
    return RevenueModel.fromMap(response.data as Map<String, dynamic>);
  }

  /// 수익 업데이트
  Future<void> updateRevenue({
    required RevenueModel revenue,
    required int placeId,
  }) async {
    await _dio.put(
      '/api/places/$placeId/revenues/${revenue.rid}',
      data: {
        'rprice': revenue.rprice,
        'rname': revenue.rname,
      },
    );
  }

  /// 수익 삭제
  Future<void> deleteRevenue(int revenueId, int placeId) async {
    await _dio.delete('/api/places/$placeId/revenues/$revenueId');
  }
}
