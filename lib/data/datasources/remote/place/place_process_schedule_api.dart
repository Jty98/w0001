import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/remote/process_schedule_dto.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/util/api_endpoint.dart';

final class PlaceProcessScheduleRemoteApi {
  PlaceProcessScheduleRemoteApi(this._http);

  final AppHttpClient _http;

  Future<ProcessScheduleData> get(int pid) async {
    final r = await _http.get<dynamic>(ApiEndpoint.placesProcessSchedule(pid));
    return ProcessScheduleDto.parseGet(saParseObject(r.data));
  }

  /// 응답 본문(Map) 또는 빈 응답 시 `null`.
  Future<Map<String, dynamic>?> put(int pid, ProcessScheduleData data) async {
    final r = await _http.put<dynamic>(
      ApiEndpoint.placesProcessSchedule(pid),
      data: ProcessScheduleDto.buildPutBody(data),
    );
    final body = r.data;
    if (body is Map) {
      return Map<String, dynamic>.from(body);
    }
    return null;
  }
}
