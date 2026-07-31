import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/data/model/worker_dashboard_models.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';

/// 배정·투입 행에서 작업 내용 블록을 해석한다 (서버 blocks 우선, preview·Quill 폴백).
List<WorkerAnnouncementBlock> resolveAssignmentInstructionBlocks({
  List<WorkerAnnouncementBlock> instructionBlocks = const [],
  String memoFallback = '',
}) {
  if (instructionBlocks.isNotEmpty) return instructionBlocks;
  final memo = memoFallback.trim();
  if (memo.isEmpty) return const [];
  if (WorkerAnnouncementQuillCodec.isQuillEnvelopeText(memo)) {
    return [WorkerAnnouncementTextBlock(memo)];
  }
  final parsed = parseWorkerAnnouncementBlockList(memo);
  if (parsed.isNotEmpty) return parsed;
  return const [];
}

/// 같은 날 투입 동료 목록에서 본인(인력 hid·표시 이름) 제외.
List<CoworkerOnSite> excludeSelfFromCoworkers(
  List<CoworkerOnSite> peers, {
  int? workerHid,
  String? viewerUname,
}) {
  final vn = viewerUname?.trim();
  return peers.where((c) {
    if (workerHid != null && workerHid > 0 && c.hid == workerHid) {
      return false;
    }
    if (vn != null && vn.isNotEmpty && c.workerName.trim() == vn) {
      return false;
    }
    return true;
  }).toList(growable: false);
}

/// 현장 투입 명단에서 본인 행 제외.
List<PlaceWorkDayRead> excludeSelfFromPlaceWorkDayRoster(
  List<PlaceWorkDayRead> rows, {
  int? workerHid,
}) {
  if (workerHid == null || workerHid <= 0) return rows;
  return rows.where((r) => r.hid != workerHid).toList(growable: false);
}
