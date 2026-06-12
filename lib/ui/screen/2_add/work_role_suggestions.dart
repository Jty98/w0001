import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/ui/screen/5_place/place_workforce_schedule.dart';
import 'package:w0001/util/worker_skills_display.dart';

/// 선택일·공정표 기준 해당 날에 잡혀 있는 공정 이름 목록.
List<String> processTaskNamesForPlaceDay({
  required ProcessScheduleData schedule,
  required DateTime day,
}) {
  var data = schedule;
  var idx = ProcessScheduleEditor.gridIndexForCalendarDay(data, day);
  if (idx == null) {
    data = ProcessScheduleEditor.expandGridToIncludeCalendarDay(data, day);
    idx = ProcessScheduleEditor.gridIndexForCalendarDay(data, day);
  }
  if (idx == null) return const [];

  final names = <String>[];
  final seen = <String>{};
  for (final (_, task) in PlaceWorkforceSchedule.tasksOnDay(data, idx)) {
    final n = task.name.trim();
    if (n.isNotEmpty && seen.add(n)) names.add(n);
  }
  return names;
}

/// 선택된 인력들의 대표·추가·기본 역할.
List<String> workerSkillRoleSuggestions(Iterable<HumanModel> workers) {
  final out = <String>[];
  final seen = <String>{};
  for (final h in workers) {
    final p = h.displayPrimarySpecialty;
    if (p != null && seen.add(p)) out.add(p);
    for (final e in h.displayExtraSpecialties) {
      if (seen.add(e)) out.add(e);
    }
    final def = h.hdefaultRole.trim();
    if (def.isNotEmpty && seen.add(def)) out.add(def);
  }
  return out;
}

/// 한 인력 기준 기본 [wrole] (금액추가 행 생성 시).
String defaultWorkRoleForHuman(HumanModel human) {
  final r = human.effectiveDefaultWorkRole.trim();
  if (r.isNotEmpty) return r;
  return kWorkRoleManualAddDefault;
}

/// 칩으로 선택 가능한 역할(프리셋·공정·인력 스킬).
bool isKnownSelectableWorkRole(
  String role, {
  Iterable<String> processTasks = const [],
  Iterable<String> workerSkills = const [],
}) {
  final t = role.trim();
  if (t.isEmpty || t == '직접입력') return false;
  if (isWorkRoleInPresetList(t)) return true;
  for (final n in processTasks) {
    if (n.trim() == t) return true;
  }
  for (final n in workerSkills) {
    if (n.trim() == t) return true;
  }
  return false;
}

/// 공통 프리셋 중 아직 섹션에 없는 항목만.
List<String> extraPresetRoleChips({
  required Iterable<String> alreadyShown,
}) {
  final seen = alreadyShown.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  final out = <String>[];
  for (final p in kWorkRolePresets) {
    if (p == '직접입력') continue;
    if (seen.contains(p)) continue;
    out.add(p);
  }
  return out;
}

/// 자주 쓰는 역할 — 프리셋(중복 제외) + 맨 끝 `직접입력`.
List<String> frequentRoleChips({
  required Iterable<String> alreadyShown,
}) {
  final out = extraPresetRoleChips(alreadyShown: alreadyShown);
  if (!out.contains('직접입력')) out.add('직접입력');
  return out;
}
