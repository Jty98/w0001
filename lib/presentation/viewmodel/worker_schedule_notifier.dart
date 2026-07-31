import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/schedule_memo/schedule_memos_api.dart';
import 'package:w0001/data/datasources/remote/worker/worker_dashboard_remote_api.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/schedule_memo_model.dart';
import 'package:w0001/data/model/worker_dashboard_models.dart';
import 'package:w0001/util/work_instruction_blocks_resolve.dart';
import 'package:w0001/presentation/viewmodel/dashboard_schedule_view_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_personal_dashboard_notifier.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/dashboard_schedule_editor_sheet.dart';
import 'package:w0001/ui/screen/1_dashboard/widgets/schedule_memo_editor_shared.dart';
import 'package:w0001/util/alarm_permission_helper.dart';
import 'package:w0001/util/schedule_memo_alarm_sync.dart';
import 'package:w0001/util/widget_data_manager.dart';

final workerScheduleNotifierProvider =
    AsyncNotifierProvider<WorkerScheduleNotifier, List<ScheduleMemoRead>>(
  WorkerScheduleNotifier.new,
);

class WorkerScheduleNotifier extends AsyncNotifier<List<ScheduleMemoRead>> {
  ScheduleMemosRemoteApi get _api => ScheduleMemosRemoteApi(AppHttpClient.I);

  WorkerDashboardRemoteApi get _workerApi =>
      ref.read(workerDashboardRemoteApiProvider);

  List<ScheduleMemoRead> _assignmentMemosFromWorkDays(
    Iterable<WorkerDashboardWorkDay> workDays,
  ) {
    final out = <ScheduleMemoRead>[];
    for (final w in workDays) {
      if (w.pid <= 0) continue;
      if (w.pwdid <= 0) continue;
      final k = w.dateKey;
      if (k.isEmpty) continue;
      final blocks = resolveAssignmentInstructionBlocks(
        instructionBlocks: w.instructionBlocks,
        memoFallback: w.instructionPreview,
      );
      final memoPlain = blocks.isNotEmpty ? '' : w.instructionPreview.trim();
      out.add(ScheduleMemoRead(
        /// 서버 스케줄 memo sid와 충돌하지 않도록 음수로.
        sid: -w.pwdid,
        taskdate: k,
        tasktime: '',
        title: w.placeName.trim().isEmpty ? '현장 #${w.pid}' : w.placeName.trim(),
        memo: memoPlain,
        done: false,
        alarmenabled: false,
        sortorder: 0,
        createdatms: 0,
        sourceType: 'assignment',
        workrole: w.workrole,
        pwdid: w.pwdid,
        placePid: w.pid,
        instructionBlocks: blocks,
      ));
    }
    return out;
  }

  List<ScheduleMemoRead> _mergeAndSort(
    List<ScheduleMemoRead> manualMemos,
    List<ScheduleMemoRead> assignmentMemos,
  ) {
    final byKey = <String, ScheduleMemoRead>{};
    for (final m in manualMemos) {
      byKey['manual:${m.sid}'] = m;
    }
    for (final a in assignmentMemos) {
      // 같은 pwdid면 최신 1개만.
      final pwdid = a.pwdid;
      byKey['assign:${pwdid ?? a.sid}'] = a;
    }
    final out = byKey.values.toList(growable: false)
      ..sort((a, b) {
        final da =
            a.taskdate.length >= 10 ? a.taskdate.substring(0, 10) : a.taskdate;
        final db =
            b.taskdate.length >= 10 ? b.taskdate.substring(0, 10) : b.taskdate;
        final dc = da.compareTo(db);
        if (dc != 0) return dc;
        if (a.isAssignment != b.isAssignment) return a.isAssignment ? -1 : 1;
        return a.sortorder.compareTo(b.sortorder);
      });
    return out;
  }

  @override
  Future<List<ScheduleMemoRead>> build() async {
    final user = ref.watch(authSessionProvider).asData?.value;
    final manual = await _api.list();

    // 작업자만 배정(work_days)을 합쳐서 "내 일정"에 표시.
    if (user?.isWorker != true) return manual;

    try {
      final y = DateTime.now().year;
      final summary = await _workerApi.fetchSummary(year: y);
      final assign = _assignmentMemosFromWorkDays(summary.workDays);
      final merged = _mergeAndSort(manual, assign);
      await _syncWidget(merged);
      return merged;
    } catch (_) {
      // 배정 로딩 실패 시에도 개인 메모는 표시.
      await _syncWidget(manual);
      return manual;
    }
  }

  Future<void> _syncWidget(List<ScheduleMemoRead> list) async {
    try {
      await WidgetDataManager.syncWorkerScheduleReads(
        list,
        weekMonday: scheduleStartOfWeekMonday(DateTime.now()),
      );
    } catch (e) {
      debugPrint('Worker schedule widget sync failed: $e');
    }
  }

  Future<void> _syncLocalAlarmsForManualMemos(
      List<ScheduleMemoRead> memos) async {
    await AlarmPermissionHelper.ensurePermissions();
    await syncScheduleMemoLocalAlarmsFromReads(memos);
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(build);
    final list = state.asData?.value;
    if (list != null) {
      await _syncLocalAlarmsForManualMemos(list);
      await _syncWidget(list);
    }
  }

  /// 홈 위젯 스냅샷을 즉시 갱신 (앱 포그라운드 복귀 등).
  Future<void> syncWidgetSnapshotNow() async {
    final list = state.asData?.value;
    if (list != null) {
      await _syncWidget(list);
      return;
    }
    await reload();
  }

  Future<int> _nextSortOrder(String taskDate) async {
    final current = await build();
    final dateKey =
        taskDate.length >= 10 ? taskDate.substring(0, 10) : taskDate;
    final sameDay = current.where((e) {
      final d =
          e.taskdate.length >= 10 ? e.taskdate.substring(0, 10) : e.taskdate;
      return d == dateKey;
    }).toList();
    if (sameDay.isEmpty) return 0;
    return sameDay.map((e) => e.sortorder).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> addMemoFromEditor(DashboardMemoEditorResult result) async {
    final t = result.title.trim();
    if (t.isEmpty) return;
    final taskDateKey0 = scheduleDateKey(scheduleDateOnly(result.date));
    final sort = await _nextSortOrder(taskDateKey0);
    final ms = DateTime.now().millisecondsSinceEpoch;
    final taskTime =
        result.time == null ? '' : scheduleMemoTimeToKey(result.time!);
    final draft = ScheduleMemoModel(
      taskDate: taskDateKey0,
      taskTime: taskTime,
      title: t,
      memo: normalizeScheduleMemoBulletText(result.memo),
      done: false,
      alarmEnabled: result.alarmEnabled,
      alarmOffsetMinutes: result.alarmEnabled ? result.alarmOffsetMinutes : 0,
      sortOrder: sort,
      createdAtMs: ms,
    );
    final created = await _api.create(scheduleMemoToCreateBody(draft));
    final withSid = scheduleMemoReadToModel(created);
    await syncScheduleMemoLocalAlarmSafe(withSid);
    await reload();
  }

  Future<void> updateMemoFromEditor(
    ScheduleMemoRead previous,
    DashboardMemoEditorResult result,
  ) async {
    if (previous.isAssignment) return;
    final t = result.title.trim();
    if (t.isEmpty) return;
    final base = scheduleMemoReadToModel(previous);
    final taskTime =
        result.time == null ? '' : scheduleMemoTimeToKey(result.time!);
    final updated = base.copyWith(
      taskDate: scheduleDateKey(scheduleDateOnly(result.date)),
      taskTime: taskTime,
      title: t,
      memo: normalizeScheduleMemoBulletText(result.memo),
      alarmEnabled: result.alarmEnabled,
      alarmOffsetMinutes: result.alarmEnabled ? result.alarmOffsetMinutes : 0,
    );
    final row =
        await _api.patch(previous.sid, scheduleMemoToPatchBody(updated));
    await syncScheduleMemoLocalAlarmSafe(scheduleMemoReadToModel(row));
    await reload();
  }

  Future<void> updateMemo(
    ScheduleMemoRead row, {
    String? title,
    String? memo,
    String? taskdate,
    String? tasktime,
    bool? done,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (memo != null) body['memo'] = memo;
    if (taskdate != null) body['taskdate'] = taskdate;
    if (tasktime != null) body['tasktime'] = tasktime;
    if (done != null) body['done'] = done;
    if (body.isEmpty) return;
    final patched = await _api.patch(row.sid, body);
    await syncScheduleMemoLocalAlarmSafe(scheduleMemoReadToModel(patched));
    await reload();
  }

  Future<void> deleteMemo(int sid) async {
    await _api.delete(sid);
    try {
      await Alarm.stop(sid);
    } catch (e, st) {
      debugPrint('Alarm stop failed on worker deleteMemo($sid): $e\n$st');
    }
    await reload();
  }
}
