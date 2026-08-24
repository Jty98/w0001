import 'package:w0001/data/model/bulk_workforce_assignment.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/util/human_work_assignability.dart';

bool canProceedBulkAssignmentStep({
  required bool saving,
  required int currentStep,
  required DateTime? startDate,
  required DateTime? endDate,
  required int dayCount,
  required int selectedWorkerCount,
}) {
  if (saving) return false;
  switch (currentStep) {
    case 0:
      return startDate != null && endDate != null && dayCount > 0;
    case 1:
      return selectedWorkerCount > 0;
    case 2:
      return true;
    default:
      return false;
  }
}

List<HumanModel> blockedWorkersForBulkAssignment(
  List<HumanModel> selectedHumans, {
  required Set<String> blockedMemberUids,
}) {
  return selectedHumans
      .where(
        (h) => !humanCanBeAssignedToWork(
          h,
          blockedMemberUids: blockedMemberUids,
        ),
      )
      .toList();
}

BulkWorkforceAssignmentRequest buildBulkWorkforceAssignmentRequest({
  required DateTime startDate,
  required DateTime endDate,
  required List<HumanModel> selectedHumans,
  required Map<int, String> humanWorkRoles,
  required Map<int, int> humanWages,
  String? fallbackWorkRole,
  List<Map<String, dynamic>>? siteInstructionBlocks,
  Map<String, List<Map<String, dynamic>>>? processInstructionBlocks,
}) {
  return BulkWorkforceAssignmentRequest(
    startDate: startDate,
    endDate: endDate,
    assignments: selectedHumans.map((human) {
      return WorkforceAssignmentItem(
        hid: human.hid!,
        workrole: humanWorkRoles[human.hid] ?? fallbackWorkRole ?? '',
        dailyWage: humanWages[human.hid] ?? human.hdailyWage,
        workerRank: human.workerRank.isNotEmpty ? human.workerRank : null,
      );
    }).toList(),
    siteInstructionBlocks: siteInstructionBlocks,
    processInstructionBlocks: processInstructionBlocks,
  );
}
