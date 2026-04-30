import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/place_process_schedule_api.dart';
import 'package:w0001/data/model/remote/process_schedule_dto.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/domain/repository/process_schedule_repository.dart';

/// GET/PUT `/places/{pid}/process-schedule` — [AppHttpClient] JWT·리프레시 공통 처리.
class ProcessScheduleRemoteRepository implements ProcessScheduleRepository {
  ProcessScheduleRemoteRepository(this._api);

  final PlaceProcessScheduleRemoteApi _api;

  ProcessScheduleData _emptyGrid(DateTime gridStartFallback, int dayCount) {
    final start = DateTime(
      gridStartFallback.year,
      gridStartFallback.month,
      gridStartFallback.day,
    );
    return ProcessScheduleData(
      remoteScheduleId: null,
      scheduleVersion: null,
      gridStart: start,
      dayCount: dayCount,
      tasks: const [],
    );
  }

  @override
  Future<ProcessScheduleData> fetchForPlace({
    required int placeId,
    required DateTime gridStartFallback,
    int dayCount = 28,
  }) async {
    if (placeId <= 0) {
      return _emptyGrid(gridStartFallback, dayCount);
    }
    try {
      return await _api.get(placeId);
    } on DioException catch (e) {
      final err = e.error;
      if (err is HttpStatusException && err.statusCode == 404) {
        return _emptyGrid(gridStartFallback, dayCount);
      }
      rethrow;
    }
  }

  @override
  Future<ProcessScheduleData> saveSchedule({
    required int placeId,
    required ProcessScheduleData data,
  }) async {
    if (placeId <= 0) {
      return data;
    }
    final res = await _api.put(placeId, data);
    if (res == null || res.isEmpty) {
      return data;
    }
    return ProcessScheduleDto.mergePutResponse(data, res);
  }
}
