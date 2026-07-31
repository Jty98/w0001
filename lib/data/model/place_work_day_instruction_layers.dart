import 'package:w0001/data/model/worker_announcement_models.dart';

/// 공정별 작업지시 (현장·일자·공정명 단위).
class PlaceWorkDayProcessInstruction {
  const PlaceWorkDayProcessInstruction({
    required this.workrole,
    this.instructionBlocks = const [],
  });

  final String workrole;
  final List<WorkerAnnouncementBlock> instructionBlocks;

  factory PlaceWorkDayProcessInstruction.fromJson(Map<String, dynamic> m) {
    return PlaceWorkDayProcessInstruction(
      workrole: (m['workrole'] ?? m['work_role'] ?? '').toString(),
      instructionBlocks: parseWorkerAnnouncementBlockList(
        m['instruction_blocks'] ??
            m['work_instruction_blocks'] ??
            m['instructionBlocks'],
      ),
    );
  }
}

/// 현장·일자 기준 전체·공정별 작업지시 묶음.
class PlaceWorkDayInstructionBundle {
  const PlaceWorkDayInstructionBundle({
    required this.workdate,
    this.siteInstructionBlocks = const [],
    this.processInstructions = const [],
  });

  final String workdate;
  final List<WorkerAnnouncementBlock> siteInstructionBlocks;
  final List<PlaceWorkDayProcessInstruction> processInstructions;

  factory PlaceWorkDayInstructionBundle.fromJson(Map<String, dynamic> m) {
    final siteRaw = m['site'];
    List<WorkerAnnouncementBlock> siteBlocks = const [];
    if (siteRaw is Map<String, dynamic>) {
      siteBlocks = parseWorkerAnnouncementBlockList(
        siteRaw['instruction_blocks'] ?? siteRaw['instructionBlocks'],
      );
    } else {
      siteBlocks = parseWorkerAnnouncementBlockList(
        m['site_instruction_blocks'] ?? m['siteInstructionBlocks'],
      );
    }

    final processRaw = m['process'] ?? m['process_instructions'];
    final processList = <PlaceWorkDayProcessInstruction>[];
    if (processRaw is List) {
      for (final e in processRaw) {
        if (e is Map<String, dynamic>) {
          processList.add(PlaceWorkDayProcessInstruction.fromJson(e));
        }
      }
    }

    return PlaceWorkDayInstructionBundle(
      workdate: (m['workdate'] ?? m['work_date'] ?? '').toString(),
      siteInstructionBlocks: siteBlocks,
      processInstructions: processList,
    );
  }

  List<WorkerAnnouncementBlock> processBlocksFor(String workrole) {
    final role = workrole.trim();
    if (role.isEmpty) return const [];
    for (final p in processInstructions) {
      if (p.workrole.trim() == role) return p.instructionBlocks;
    }
    return const [];
  }
}
