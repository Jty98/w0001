import 'package:dropdown_search/dropdown_search.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/place_work_day_fields.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/workcost_model.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/screen/2_add/add_worker_dialog.dart';
import 'package:w0001/ui/screen/2_add/place_recent_workers_sheet.dart';
import 'package:w0001/ui/screen/2_add/work_cost_tab.dart' show WorkCostProfileCard;
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/domain/place_work_day_cross_place_conflict.dart';
import 'package:w0001/ui/screen/5_place/widgets/cross_place_workday_conflict_dialog.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/worker_skills_display.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 신규 투입 시트: 카드에 표시할 그날 일당·역할(탭으로 일당만 수정).
class WorkforcePendingPick {
  WorkforcePendingPick({
    required this.human,
    required int initialWage,
    required String initialRole,
    List<WorkerAnnouncementBlock>? instructionBlocks,
  })  : wprice = initialWage,
        wrole = initialRole,
        instructionBlocks = instructionBlocks ?? <WorkerAnnouncementBlock>[];

  final HumanModel human;
  int wprice;
  String wrole;
  final List<WorkerAnnouncementBlock> instructionBlocks;
}

/// 바텀시트 전용 — [TextEditingController]는 이 State의 [dispose]에서만 해제한다.
class PlaceWorkforceEditorSheet extends ConsumerStatefulWidget {
  const PlaceWorkforceEditorSheet({
    super.key,
    required this.placeInfo,
    required this.initialDate,
    required this.workers,
    required this.pid,
    required this.humanName,
    required this.onSuccess,
    this.existing,
    this.defaultWorkrole,
  });

  final PlaceInfoModel placeInfo;
  final DateTime initialDate;
  final PlaceWorkDayRead? existing;
  final List<HumanModel> workers;
  final int pid;
  final String? defaultWorkrole;
  final String Function(int hid) humanName;
  final Future<void> Function([String? snackbarMessage]) onSuccess;

  @override
  ConsumerState<PlaceWorkforceEditorSheet> createState() =>
      _PlaceWorkforceEditorSheetState();
}

class _PlaceWorkforceEditorSheetState
    extends ConsumerState<PlaceWorkforceEditorSheet> {
  /// 메인 캘린더에서 고른 날(또는 수정 중인 행의 workdate).
  late final DateTime _workDate;

  /// 수정 모드 일당 필드용 (초기 포맷 + 입력 중 콤마).
  CurrencyTextInputFormatter? _editWageFmt;
  TextEditingController? _editWageCtrl;
  TextEditingController? _editCustomRoleCtrl;
  String? _editRoleChoice;

  /// 신규 등록 시에만 사용. [DropdownSearch.multiSelection]과 동기화.
  final List<WorkforcePendingPick> _picks = [];

  /// 수정 모드: Rich 작업 내용.
  List<WorkerAnnouncementBlock> _editInstructionBlocks = const [];

  /// 이 현장에서 일했던 인력([HumanUseCase.getPlaceWorkerRecentHids]).
  List<HumanModel> _recentHumans = [];

  List<HumanModel> get _humansForDropdown =>
      _picks.map((p) => p.human).toList();

  /// 공정 카드에서 연 경우 [defaultWorkrole](공정명)을 저장값으로 쓴다.
  /// 인력 프로필 기본 역할은 「기타 투입」 등 default가 비어 있을 때만 사용한다.
  String _initialRoleForNewPick(HumanModel h) {
    final taskRole = (widget.defaultWorkrole ?? '').trim();
    if (taskRole.isNotEmpty) return taskRole;
    final def = h.effectiveDefaultWorkRole;
    if (def.isNotEmpty) return def;
    return '';
  }

  void _syncPicksFromSelection(List<HumanModel> next) {
    final ids = next.map((h) => h.hid).whereType<int>().toSet();
    for (final p in List<WorkforcePendingPick>.from(_picks)) {
      final id = p.human.hid;
      if (id == null || !ids.contains(id)) {
        _picks.remove(p);
      }
    }
    final order = <int, int>{};
    for (var i = 0; i < next.length; i++) {
      final id = next[i].hid;
      if (id != null) order[id] = i;
    }
    for (final h in next) {
      final id = h.hid;
      if (id == null) continue;
      if (_picks.any((p) => p.human.hid == id)) continue;
      _picks.add(
        WorkforcePendingPick(
          human: h,
          initialWage: h.hdailyWage,
          initialRole: _initialRoleForNewPick(h),
        ),
      );
    }
    _picks.sort((a, b) {
      final ia = a.human.hid != null ? order[a.human.hid!] ?? 999 : 999;
      final ib = b.human.hid != null ? order[b.human.hid!] ?? 999 : 999;
      return ia.compareTo(ib);
    });
  }

  void _removePick(WorkforcePendingPick p) {
    setState(() => _picks.remove(p));
  }

  Future<void> _editPickWage(WorkforcePendingPick pick) async {
    final initFmt = CurrencyTextInputFormatter.currency(
      decimalDigits: 0,
      symbol: '',
    );
    final fieldFmt = CurrencyTextInputFormatter.currency(
      decimalDigits: 0,
      symbol: '',
    );
    final ctrl = TextEditingController(
      text: initFmt.formatString('${pick.wprice}'),
    );
    final next = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('일당 · ${pick.human.hname}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: '일당(원)',
            border: OutlineInputBorder(),
            suffixText: '원',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            fieldFmt,
            LengthLimitingTextInputFormatter(13),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(
                    ctrl.text.replaceAll(RegExp(r'[^\d]'), ''),
                  ) ??
                  0;
              Navigator.pop(ctx, v);
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (next != null && mounted) {
      setState(() => pick.wprice = next);
    }
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      final raw = e.workdate.trim();
      final head = raw.length >= 10 ? raw.substring(0, 10) : raw;
      final parsed = DateTime.tryParse(head);
      _workDate = parsed != null
          ? DateTime(parsed.year, parsed.month, parsed.day)
          : DateTime(
              widget.initialDate.year,
              widget.initialDate.month,
              widget.initialDate.day,
            );
    } else {
      _workDate = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
      );
    }
    HumanModel? matched;
    if (e != null) {
      for (final h in widget.workers) {
        if (h.hid == e.hid) {
          matched = h;
          break;
        }
      }
      final wr = e.workrole;
      final roleDefault = wr.isNotEmpty
          ? wr
          : (matched?.hdefaultRole ?? widget.defaultWorkrole ?? '');
      final initWageFmt = CurrencyTextInputFormatter.currency(
        decimalDigits: 0,
        symbol: '',
      );
      _editWageFmt = CurrencyTextInputFormatter.currency(
        decimalDigits: 0,
        symbol: '',
      );
      _editWageCtrl = TextEditingController(
        text: initWageFmt.formatString('${e.dailywage}'),
      );
      _editCustomRoleCtrl = TextEditingController();
      final (chip, customFill) =
          workRolePresetInitialSelection(roleDefault);
      _editRoleChoice = chip;
      if (customFill.isNotEmpty) {
        _editCustomRoleCtrl!.text = customFill;
      }
      _editInstructionBlocks =
          List<WorkerAnnouncementBlock>.from(e.instructionBlocks);
    } else {
      Future.microtask(_loadRecentWorkers);
    }
  }

  Future<void> _loadRecentWorkers() async {
    try {
      final hids =
          await ref.read(humanUseCaseProvider).getPlaceWorkerRecentHids(
                widget.pid,
              );
      final all = await ref.read(humanUseCaseProvider).getAllWorkers();
      final byHid = {for (final h in all) if (h.hid != null) h.hid!: h};
      final list = <HumanModel>[];
      for (final id in hids) {
        final h = byHid[id];
        if (h != null) list.add(h);
      }
      if (mounted) setState(() => _recentHumans = list);
    } catch (_) {
      if (mounted) setState(() => _recentHumans = const []);
    }
  }

  Future<void> _confirmDeleteRecentWorker(int hid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('인원 삭제'),
        content: Text('$name 인원을 이 현장 최근 목록에서 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '삭제',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref
          .read(humanUseCaseProvider)
          .deletePlaceWorkerRecent(widget.pid, hid);
      await _loadRecentWorkers();
    }
  }

  void _addHumanToSelection(HumanModel h) {
    final id = h.hid;
    if (id == null) return;
    if (_picks.any((p) => p.human.hid == id)) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 선택된 인원입니다.')),
      );
      return;
    }
    setState(() {
      _picks.add(
        WorkforcePendingPick(
          human: h,
          initialWage: h.hdailyWage,
          initialRole: _initialRoleForNewPick(h),
        ),
      );
    });
  }

  Widget _workforcePlaceRecentWorkersBox(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const radius = BorderRadius.all(Radius.circular(12));
    final recent = _recentHumans;

    if (recent.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: radius,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.rsi(14),
            horizontal: context.rsi(12),
          ),
          child: Row(
            children: [
              Icon(Icons.history_rounded,
                  size: context.rs(26), color: cs.onSurfaceVariant),
              SizedBox(width: context.rsi(12)),
              Expanded(
                child: Text(
                  '이 현장에 기록된 인원이 없습니다. 검색하거나 인원 추가로 등록해 보세요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: radius,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.rsi(12),
            context.rsi(10),
            context.rsi(12),
            context.rsi(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: context.rs(18), color: cs.onSurfaceVariant),
                  SizedBox(width: context.rsi(6)),
                  Expanded(
                    child: Text(
                      '이 현장에서 일했던 인원',
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showPlaceRecentWorkersGroupedSheet(
                      context: context,
                      initialWorkers: recent,
                      onWorkerTap: (h) async {
                        FocusScope.of(context).unfocus();
                        _addHumanToSelection(h);
                      },
                      onRemoveFromList: (h) async {
                        final hid = h.hid;
                        if (hid == null) return;
                        await ref
                            .read(humanUseCaseProvider)
                            .deletePlaceWorkerRecent(widget.pid, hid);
                      },
                      onWorkersListChanged: _loadRecentWorkers,
                    ),
                    child: Text('전체보기(${recent.length})'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < recent.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      GestureDetector(
                        onLongPress: () async {
                          final hid = recent[i].hid;
                          if (hid == null) return;
                          await _confirmDeleteRecentWorker(
                            hid,
                            recent[i].hname,
                          );
                        },
                        child: ActionChip(
                          label: Text(recent[i].hname),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            _addHumanToSelection(recent[i]);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _editWageCtrl?.dispose();
    _editCustomRoleCtrl?.dispose();
    super.dispose();
  }

  Future<bool> _confirmTroubleOverride(BuildContext ctx) async {
    final r = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('트러블 페어'),
        content: const Text(
          '선택한 인력에 트러블 페어로 묶인 조합이 포함되어 있어, 기본적으로는 같은 날 함께 투입할 수 없습니다.\n\n'
          '그래도 투입을 진행할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('투입 진행'),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _editPickInstruction(WorkforcePendingPick pick) async {
    final next = await showPlaceWorkInstructionEditorSheet(
      context: context,
      pid: widget.pid,
      placeName: widget.placeInfo.pname,
      workerLabel: pick.human.hname,
      initialBlocks: pick.instructionBlocks,
    );
    if (next != null && mounted) {
      setState(() {
        pick.instructionBlocks.clear();
        pick.instructionBlocks.addAll(next);
      });
    }
  }

  Future<void> _editExistingInstruction(PlaceWorkDayRead row) async {
    final next = await showPlaceWorkInstructionEditorSheet(
      context: context,
      pid: widget.pid,
      placeName: widget.placeInfo.pname,
      workerLabel: widget.humanName(row.hid),
      initialBlocks: _editInstructionBlocks,
    );
    if (next != null && mounted) {
      setState(() {
        _editInstructionBlocks = List<WorkerAnnouncementBlock>.from(next);
      });
    }
  }

  Future<void> _submit() async {
    final existing = widget.existing;
    final sheetCtx = context;
    final dk = formatDateTimeToIsoDate(_workDate);

    Future<void> closeAndRefresh([String? snackbarMessage]) async {
      if (!sheetCtx.mounted) return;
      Navigator.of(sheetCtx).pop();
      await Future<void>.delayed(Duration.zero);
      await widget.onSuccess(snackbarMessage);
    }

    if (existing == null) {
      if (_picks.isEmpty) {
        if (sheetCtx.mounted) {
          ScaffoldMessenger.of(sheetCtx).showSnackBar(
            const SnackBar(content: Text('인력을 선택해주세요.')),
          );
        }
        return;
      }

      final hids = _picks.map((p) => p.human.hid).whereType<int>().toList();
      if (hids.isNotEmpty) {
        try {
          final allRows =
              await ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
          final placeNameByPid = <int, String>{
            for (final p in ref.read(placeListProvider).placeList)
              if (p.pid != null) p.pid!: p.pname,
          };
          final humanNameByHid = <int, String>{
            for (final h in widget.workers)
              if (h.hid != null) h.hid!: h.hname,
          };
          final conflicts = findCrossPlaceWorkDayConflicts(
            allRows: allRows,
            targetPid: widget.pid,
            workdateIso: dk,
            hids: hids,
            placeNameByPid: placeNameByPid,
            humanNameByHid: humanNameByHid,
          );
          if (conflicts.isNotEmpty && sheetCtx.mounted) {
            final choice = await showCrossPlaceWorkDayConflictDialog(
              sheetCtx,
              workdateLabel: dk,
              currentPlaceName: widget.placeInfo.pname,
              conflicts: conflicts,
            );
            if (!sheetCtx.mounted) return;
            if (choice != CrossPlaceConflictChoice.proceedAll) {
              return;
            }
          }
        } catch (e) {
          debugPrint('Cross-place workday precheck failed: $e');
        }
      }

      var ok = 0;
      final failLabels = <String>[];
      final troublePicks = <WorkforcePendingPick>[];
      final mergedForAddCost =
          <({HumanModel human, int wprice, String wrole})>[];

      for (final pick in _picks) {
        final hum = pick.human;
        final h = hum.hid;
        if (h == null) {
          failLabels.add(hum.hname);
          continue;
        }
        final w = pick.wprice;
        final roleRaw = pick.wrole.trim();
        try {
          final body = <String, dynamic>{
            'pid': widget.pid,
            'hid': h,
            'workdate': dk,
            'dailywage': w,
            'paid': 0,
            'workrole': roleRaw,
          };
          if (!workInstructionBlocksLookEmpty(pick.instructionBlocks)) {
            body['instruction_blocks'] =
                pick.instructionBlocks.map((e) => e.toJson()).toList();
          }
          await ref.read(superAdminRemoteUseCaseProvider).placeWorkDayCreate(
                body,
              );
          ok++;
          mergedForAddCost.add(
            (human: hum, wprice: w, wrole: roleRaw),
          );
        } catch (e) {
          if (isWorkerTroublePairConflictError(e)) {
            troublePicks.add(pick);
          } else {
            final hErr = unwrapHttpClientException(e);
            if (hErr != null) {
              failLabels.add('${hum.hname}: ${hErr.message}');
            } else {
              failLabels.add('${hum.hname}: $e');
            }
          }
        }
      }

      if (troublePicks.isNotEmpty && sheetCtx.mounted) {
        final overrideOk = await _confirmTroubleOverride(sheetCtx);
        if (overrideOk) {
          for (final pick in troublePicks) {
            final hum = pick.human;
            final h = hum.hid;
            if (h == null) {
              failLabels.add(hum.hname);
              continue;
            }
            final w = pick.wprice;
            final roleRaw = pick.wrole.trim();
            try {
              final body = <String, dynamic>{
                'pid': widget.pid,
                'hid': h,
                'workdate': dk,
                'dailywage': w,
                'paid': 0,
                'workrole': roleRaw,
                PlaceWorkDayFields.acknowledgeTroublePair: true,
              };
              if (!workInstructionBlocksLookEmpty(pick.instructionBlocks)) {
                body['instruction_blocks'] =
                    pick.instructionBlocks.map((e) => e.toJson()).toList();
              }
              await ref.read(superAdminRemoteUseCaseProvider).placeWorkDayCreate(
                    body,
                  );
              ok++;
              mergedForAddCost.add(
                (human: hum, wprice: w, wrole: roleRaw),
              );
            } catch (e) {
              final hErr = unwrapHttpClientException(e);
              if (hErr != null) {
                failLabels.add('${hum.hname}: ${hErr.message}');
              } else {
                failLabels.add('${hum.hname}: $e');
              }
            }
          }
        } else {
          for (final pick in troublePicks) {
            failLabels.add(pick.human.hname);
          }
        }
      }

      if (ok > 0) {
        final workCostUseCase = ref.read(workCostUseCaseProvider);
        for (final pick in mergedForAddCost) {
          final h = pick.human.hid;
          if (h == null) continue;
          try {
            await workCostUseCase.ensureWorkCostForPlaceWorkDay(
              pid: widget.pid,
              hid: h,
              dateKey: dk,
              wprice: pick.wprice,
              wrole: pick.wrole,
            );
          } catch (_) {}
        }
        final total = _picks.length;
        String? msg;
        if (total == 1 && ok == 1) {
          msg = null;
        } else {
          msg = '$ok명 등록했습니다';
          if (failLabels.isNotEmpty) {
            msg = '$msg · 실패 ${failLabels.length}명';
          }
        }
        await closeAndRefresh(msg);
      } else if (failLabels.isNotEmpty && sheetCtx.mounted) {
        ScaffoldMessenger.of(sheetCtx).showSnackBar(
          SnackBar(content: Text(failLabels.join('\n'))),
        );
      }
    } else {
      final w = int.tryParse(
            _editWageCtrl!.text.replaceAll(RegExp(r'[^\d]'), ''),
          ) ??
          0;
      final roleChoice = _editRoleChoice;
      final role = roleChoice == null
          ? ''
          : roleChoice == '직접입력'
              ? _editCustomRoleCtrl!.text.trim()
              : roleChoice;
      try {
        await ref.read(superAdminRemoteUseCaseProvider).placeWorkDayPatch(
              existing.pwdid,
              <String, dynamic>{
                'dailywage': w,
                'workrole': role,
                'instruction_blocks':
                    _editInstructionBlocks.map((e) => e.toJson()).toList(),
              },
            );
        await closeAndRefresh();
      } catch (e) {
        if (!sheetCtx.mounted) return;
        if (isWorkerTroublePairConflictError(e)) {
          final proceed = await _confirmTroubleOverride(sheetCtx);
          if (!sheetCtx.mounted) return;
          if (proceed) {
            try {
              await ref.read(superAdminRemoteUseCaseProvider).placeWorkDayPatch(
                    existing.pwdid,
                    <String, dynamic>{
                      'dailywage': w,
                      'workrole': role,
                      'instruction_blocks': _editInstructionBlocks
                          .map((e) => e.toJson())
                          .toList(),
                      PlaceWorkDayFields.acknowledgeTroublePair: true,
                    },
                  );
              await closeAndRefresh();
            } catch (e2) {
              if (!sheetCtx.mounted) return;
              final hErr = unwrapHttpClientException(e2);
              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                SnackBar(content: Text(hErr?.message ?? '$e2')),
              );
            }
          }
        } else {
          final hErr = unwrapHttpClientException(e);
          ScaffoldMessenger.of(sheetCtx).showSnackBar(
            SnackBar(content: Text(hErr?.message ?? '$e')),
          );
        }
      }
    }
  }

  Widget _workDateBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final line = formatDateTimeWeekDayToString(_workDate);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(14),
          vertical: context.rsi(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.event_available_rounded,
                color: cs.primary, size: context.rs(26)),
            SizedBox(width: context.rsi(10)),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: cs.onPrimaryContainer,
                  ),
                  children: [
                    const TextSpan(text: '작업일 '),
                    TextSpan(
                      text: line,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: context.rsi(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null ? '인력 투입 추가' : '인력 투입 수정',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: context.rsi(10)),
                _workDateBanner(context),
                if (existing == null) ...[
                  SizedBox(height: context.rsi(16)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: context.rs(48),
                          child: DropdownSearch<HumanModel>.multiSelection(
                            asyncItems: (filter) =>
                                ref.read(humanUseCaseProvider).getAllWorkers(),
                            itemAsString: (item) => item.hname,
                            compareFn: (a, b) =>
                                a.hid != null &&
                                b.hid != null &&
                                a.hid == b.hid,
                            selectedItems: _humansForDropdown,
                            onChanged: (values) {
                              setState(() {
                                _syncPicksFromSelection(
                                  List<HumanModel>.from(values),
                                );
                              });
                            },
                            dropdownBuilder: (context, selected) {
                              final n = selected.length;
                              final scheme = Theme.of(context).colorScheme;
                              final dtt = Theme.of(context).textTheme;
                              if (n == 0) {
                                return Text(
                                  '사람 선택',
                                  style: dtt.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
                              return Text(
                                '$n명 선택됨',
                                style: dtt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: '인력',
                                labelStyle: tt.bodyMedium,
                                hintStyle: tt.bodyMedium,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: context.rsi(12),
                                  vertical: context.rsi(12),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(context.rsi(12)),
                                ),
                                hintText: '사람 선택',
                              ),
                            ),
                            popupProps: PopupPropsMultiSelection.menu(
                              itemBuilder: (context, item, isSelected) {
                                return ListTile(
                                  title: Text(
                                    item.hname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    [
                                      if (item.hnumber.isNotEmpty)
                                        item.hnumber,
                                      humanSkillsOneLine(item),
                                      if (item.hdailyWage > 0)
                                        getPrice(price: item.hdailyWage),
                                    ].join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                  isThreeLine: true,
                                );
                              },
                              showSearchBox: true,
                              showSelectedItems: false,
                              searchFieldProps: TextFieldProps(
                                controller: TextEditingController(),
                                decoration: InputDecoration(
                                  constraints: BoxConstraints(
                                    maxHeight: context.rs(40),
                                  ),
                                  hintText: '사람을 검색하세요.',
                                  isDense: true,
                                  hintStyle: tt.labelLarge,
                                  labelStyle: tt.labelLarge,
                                  border: const OutlineInputBorder(
                                    gapPadding: 100,
                                  ),
                                ),
                              ),
                              searchDelay: Duration.zero,
                              emptyBuilder: (context, searchEntry) =>
                                  const Center(
                                child: Text('검색 결과 없음'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.rsi(8)),
                      SizedBox(
                        height: context.rs(48),
                        width: context.rs(48),
                        child: OutlinedButton(
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (_) => const AddWorkerDialog(),
                            ).then((_) {
                              if (mounted) _loadRecentWorkers();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(context.rsi(12)),
                            ),
                          ),
                          child: Icon(
                            Icons.person_add_alt_1,
                            color: cs.primary,
                            size: context.rs(22),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.rsi(10)),
                  _workforcePlaceRecentWorkersBox(context),
                  if (_picks.isNotEmpty) ...[
                    SizedBox(height: context.rsi(14)),
                    Text(
                      '선택된 인원',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    SizedBox(height: context.rsi(8)),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: context.rsi(4)),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: context.rsi(8),
                        crossAxisSpacing: context.rsi(8),
                        childAspectRatio: 0.52,
                      ),
                      itemCount: _picks.length,
                      itemBuilder: (context, index) {
                        final originalIndex = _picks.length - 1 - index;
                        final pick = _picks[originalIndex];
                        final preview = WorkCostModel(
                          wcomplete: 0,
                          wdate: '',
                          hname: pick.human.hname,
                          wprice: pick.wprice,
                          wpid: widget.pid,
                          whid: pick.human.hid,
                          pname: widget.placeInfo.pname,
                          wrole: pick.wrole,
                        );
                        final hasInstruction =
                            !workInstructionBlocksLookEmpty(
                                pick.instructionBlocks);
                        return _PickPersonCardWithInstruction(
                          preview: preview,
                          hasInstruction: hasInstruction,
                          onEditWage: () => _editPickWage(pick),
                          onDelete: () => _removePick(pick),
                          onEditInstruction: () => _editPickInstruction(pick),
                        );
                      },
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '인력',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(widget.humanName(existing.hid)),
                  ),
                ],
                if (existing != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _editWageCtrl,
                    decoration: const InputDecoration(
                      labelText: '일당(원)',
                      border: OutlineInputBorder(),
                      suffixText: '원',
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _editWageFmt!,
                      LengthLimitingTextInputFormatter(13),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '역할(공수)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < kWorkRolePresets.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          ChoiceChip(
                            label: Text(
                              kWorkRolePresets[i],
                              style: tt.labelLarge,
                            ),
                            selected: _editRoleChoice == kWorkRolePresets[i],
                            onSelected: (_) => setState(() {
                              _editRoleChoice = kWorkRolePresets[i];
                              if (kWorkRolePresets[i] != '직접입력') {
                                _editCustomRoleCtrl?.clear();
                              }
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_editRoleChoice == '직접입력') ...[
                    SizedBox(height: context.rsi(8)),
                    TextField(
                      controller: _editCustomRoleCtrl,
                      style: tt.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: '역할 직접 입력',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  SizedBox(height: context.rsi(14)),
                  ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: context.rsi(4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rsi(12)),
                      side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    leading: Icon(Icons.assignment_outlined, color: cs.primary),
                    title: const Text('작업 내용'),
                    subtitle: Text(
                      workInstructionBlocksLookEmpty(_editInstructionBlocks)
                          ? '목공·전기 등 세부 지시와 도면 사진 삽입 (선택)'
                          : '등록된 지시가 있습니다 · 텍스트·사진 수정',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    trailing: Icon(Icons.edit_outlined,
                        color: cs.onSurfaceVariant),
                    onTap: () {
                      final e = widget.existing;
                      if (e != null) _editExistingInstruction(e);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + bottomInset),
          child: FilledButton(
            onPressed: _submit,
            child: Text(existing == null ? '등록' : '저장'),
          ),
        ),
      ],
    );
  }
}

/// 선택 인원 카드 + 하단 작업지시 액션을 한 덩어리로 묶는다.
class _PickPersonCardWithInstruction extends StatelessWidget {
  const _PickPersonCardWithInstruction({
    required this.preview,
    required this.hasInstruction,
    required this.onEditWage,
    required this.onDelete,
    required this.onEditInstruction,
  });

  final WorkCostModel preview;
  final bool hasInstruction;
  final VoidCallback onEditWage;
  final VoidCallback onDelete;
  final VoidCallback onEditInstruction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(context.rs(12));
    final accent = hasInstruction ? cs.tertiary : cs.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: accent.withValues(alpha: hasInstruction ? 0.55 : 0.28),
          width: hasInstruction ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: context.rs(6),
            offset: Offset(0, context.rs(2)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: WorkCostProfileCard(
                item: preview,
                onEdit: onEditWage,
                onDelete: onDelete,
              ),
            ),
            Material(
              color: hasInstruction
                  ? cs.tertiaryContainer
                  : cs.primaryContainer.withValues(alpha: 0.72),
              child: InkWell(
                onTap: onEditInstruction,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: context.rsi(8),
                    horizontal: context.rsi(6),
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: accent.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.rsi(4)),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasInstruction
                              ? Icons.task_alt_rounded
                              : Icons.edit_note_rounded,
                          size: context.rs(15),
                          color: accent,
                        ),
                      ),
                      SizedBox(width: context.rsi(6)),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '작업지시',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: hasInstruction
                                    ? cs.onTertiaryContainer
                                    : cs.onPrimaryContainer,
                                height: 1.1,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              hasInstruction ? '내용 있음 · 수정' : '탭하여 작성',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: (hasInstruction
                                        ? cs.onTertiaryContainer
                                        : cs.onPrimaryContainer)
                                    .withValues(alpha: 0.78),
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: context.rs(18),
                        color: accent.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
