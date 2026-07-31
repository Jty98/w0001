import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';

List<WorkerAnnouncementBlock> _cloneBlocks(List<WorkerAnnouncementBlock> src) =>
    src.map((e) => WorkerAnnouncementBlock.fromJson(e.toJson())).toList();

/// 전체 → 공정별 → 개별 순으로 병합. 레거시 [mergedFallback]만 있으면 그대로 사용.
List<WorkerAnnouncementBlock> mergeWorkInstructionLayers({
  List<WorkerAnnouncementBlock> site = const [],
  List<WorkerAnnouncementBlock> process = const [],
  List<WorkerAnnouncementBlock> individual = const [],
  List<WorkerAnnouncementBlock> mergedFallback = const [],
}) {
  final hasLayer = !workInstructionBlocksLookEmpty(site) ||
      !workInstructionBlocksLookEmpty(process) ||
      !workInstructionBlocksLookEmpty(individual);

  if (!hasLayer && !workInstructionBlocksLookEmpty(mergedFallback)) {
    return _cloneBlocks(mergedFallback);
  }

  final out = <WorkerAnnouncementBlock>[];
  void append(List<WorkerAnnouncementBlock> src) {
    if (workInstructionBlocksLookEmpty(src)) return;
    out.addAll(_cloneBlocks(src));
  }

  append(site);
  append(process);
  append(individual);
  return out;
}

/// [instruction_blocks] JSON 배열을 개별 레이어로만 해석 (구 서버 호환 없음).
List<WorkerAnnouncementBlock> parseIndividualInstructionBlocks(
  Map<String, dynamic> m,
) {
  return parseWorkerAnnouncementBlockList(
    m['individual_instruction_blocks'] ??
        m['individualInstructionBlocks'] ??
        m['instruction_blocks'] ??
        m['work_instruction_blocks'] ??
        m['instructionBlocks'],
  );
}

List<WorkerAnnouncementBlock> parseSiteInstructionBlocks(
    Map<String, dynamic> m) {
  return parseWorkerAnnouncementBlockList(
    m['site_instruction_blocks'] ?? m['siteInstructionBlocks'],
  );
}

List<WorkerAnnouncementBlock> parseProcessInstructionBlocks(
  Map<String, dynamic> m,
) {
  return parseWorkerAnnouncementBlockList(
    m['process_instruction_blocks'] ?? m['processInstructionBlocks'],
  );
}
