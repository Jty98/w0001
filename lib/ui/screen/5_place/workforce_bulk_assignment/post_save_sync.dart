import 'package:w0001/data/model/bulk_workforce_assignment.dart';
import 'package:w0001/data/model/human_model.dart';

Future<void> runBulkAssignmentPostSaveSync({
  required BulkWorkforceAssignmentResponse response,
  required int pid,
  required DateTime? startDate,
  required List<HumanModel> selectedHumans,
  required Future<void> Function(int pid, List<HumanModel> workers)
      inviteAssignedWorkers,
  required Future<void> Function(PlaceWorkDaySimple workDay)
      ensureWorkCostForWorkDay,
  required Future<void> Function(int pid, DateTime? date) notifyWorkCostChanged,
  required Future<void> Function() reloadWorkforce,
  required Future<void> Function() reloadProcessSchedule,
}) async {
  await inviteAssignedWorkers(pid, selectedHumans);

  for (final wd in response.workDays) {
    try {
      await ensureWorkCostForWorkDay(wd);
    } catch (_) {}
  }

  await notifyWorkCostChanged(pid, startDate);
  await reloadWorkforce();
  await reloadProcessSchedule();
}
