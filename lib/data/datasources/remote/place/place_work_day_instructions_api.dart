import 'package:dio/dio.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/super_admin/super_admin_api_common.dart';
import 'package:w0001/data/model/place_work_day_instruction_layers.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/util/api_endpoint.dart';

/// 현장·일자 단위 전체·공정별 작업지시 API.
final class PlaceWorkDayInstructionsRemoteApi {
  PlaceWorkDayInstructionsRemoteApi(this._http);

  final AppHttpClient _http;

  Future<PlaceWorkDayInstructionBundle> getBundle({
    required int pid,
    required String workdate,
  }) async {
    final r = await _http.get<dynamic>(
      ApiEndpoint.placeWorkDayInstructions(pid),
      queryParameters: {'workdate': workdate},
    );
    return PlaceWorkDayInstructionBundle.fromJson(saParseObject(r.data));
  }

  Future<void> upsertSite({
    required int pid,
    required String workdate,
    required List<WorkerAnnouncementBlock> blocks,
  }) async {
    await _http.put<dynamic>(
      ApiEndpoint.placeWorkDayInstructionsSite(pid),
      data: <String, dynamic>{
        'workdate': workdate,
        'instruction_blocks': blocks.map((e) => e.toJson()).toList(),
      },
    );
  }

  Future<void> upsertProcess({
    required int pid,
    required String workdate,
    required String workrole,
    required List<WorkerAnnouncementBlock> blocks,
  }) async {
    await _http.put<dynamic>(
      ApiEndpoint.placeWorkDayInstructionsProcess(pid),
      data: <String, dynamic>{
        'workdate': workdate,
        'workrole': workrole,
        'instruction_blocks': blocks.map((e) => e.toJson()).toList(),
      },
    );
  }

  /// 신규 API 미배포 서버(404/501) 여부.
  static bool isLayersApiUnavailable(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      return code == 404 || code == 501;
    }
    return false;
  }
}
