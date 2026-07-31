import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/worker_schedule_notifier.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_editor_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/schedule_memo_editor_shared.dart';

/// 관리자 [openDashboardMemoEditor]와 동일한 시트·검증; 저장만 작업자 API 로직으로 처리합니다.
Future<void> openWorkerScheduleMemoEditor(
  BuildContext context,
  WidgetRef ref, {
  required ScheduleMemoRead? existing,
  DateTime? initialDateOverride,
}) async {
  final model = existing != null ? scheduleMemoReadToModel(existing) : null;
  final initialDate = model != null
      ? scheduleDateFromTaskKey(model.taskDate)
      : scheduleDateOnly(initialDateOverride ?? DateTime.now());
  final initialTime =
      model != null ? parseScheduleMemoTaskTime(model.taskTime) : null;

  List<PlaceInfoModel> places = const [];
  final me = ref.read(authSessionProvider).maybeWhen(
        data: (u) => u,
        orElse: () => null,
      );
  if (me != null) {
    try {
      // 작업자·일반 관리자: GET /places/me (접근 가능 현장만).
      // 슈퍼관리자: /dashboard/places-info → 실패 시 GET /places.
      places = await ref.read(placeUseCaseProvider).getAllPlaces(
            managementPlacesInfoFirst: me.isManagementRole,
            role: me.role,
          );
    } catch (e) {
      places = const [];
      if (context.mounted) {
        final msg =
            unwrapHttpClientException(e)?.message ?? '현장 목록을 불러오지 못했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('현장') ? msg : '현장 목록을 불러오지 못했습니다. ($msg)',
            ),
          ),
        );
      }
    }
  }
  if (!context.mounted) return;
  final placeList = List<PlaceInfoModel>.from(places);
  placeList.sort((a, b) => (b.pid ?? 0).compareTo(a.pid ?? 0));
  final seen = <String>{};
  final placeNameSuggestions = <String>[];
  for (final p in placeList) {
    final name = p.pname.trim();
    if (name.isEmpty || seen.contains(name)) continue;
    seen.add(name);
    placeNameSuggestions.add(name);
  }

  final result = await showModalBottomSheet<DashboardMemoEditorResult?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: DashboardScheduleMemoEditorSheet(
        existing: model,
        initialDate: initialDate,
        initialTime: initialTime,
        onPickTime: (initial) => pickScheduleMemoTaskTime(context, initial),
        placeNameSuggestions: placeNameSuggestions,
      ),
    ),
  );

  if (result == null || !context.mounted) return;

  final notifier = ref.read(workerScheduleNotifierProvider.notifier);
  if (existing == null) {
    await notifier.addMemoFromEditor(result);
  } else {
    await notifier.updateMemoFromEditor(existing, result);
  }
}
