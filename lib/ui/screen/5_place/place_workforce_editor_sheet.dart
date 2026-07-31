import 'dart:async' show unawaited;

import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/place_work_day_fields.dart';
import 'package:w0001/data/datasources/remote/place/place_work_day_instructions_api.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_members_providers.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/screen/2_add/add_worker_dialog.dart';
import 'package:w0001/ui/screen/2_add/place_recent_workers_sheet.dart';
import 'package:w0001/ui/screen/2_add/work_role_presets.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/domain/place_work_day_cross_place_conflict.dart';
import 'package:w0001/ui/screen/5_place/widgets/cross_place_workday_conflict_dialog.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';
import 'package:w0001/ui/widget/human_picker/human_search_pick_sheet.dart';
import 'package:w0001/util/fetch_data.dart';
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

  /// 신규 다인 투입 — 공정 카드에서만 공정 작업지시 (개별은 [WorkforcePendingPick.instructionBlocks]).
  List<WorkerAnnouncementBlock> _processInstructionBlocks = const [];
  List<WorkerAnnouncementBlock> _siteInstructionBlocks = const [];
  bool _siteInstructionTouchedByUser = false;
  bool _processInstructionTouchedByUser = false;

  String? get _processRoleLabel {
    final r = (widget.defaultWorkrole ?? '').trim();
    return r.isEmpty ? null : r;
  }

  /// 공정 카드에서 연 신규 투입 — 공정 작업지시만 시트에 표시.
  bool get _isProcessScopedCreate =>
      widget.existing == null && _processRoleLabel != null;

  /// 수정 모드: Rich 작업 내용.
  List<WorkerAnnouncementBlock> _editInstructionBlocks = const [];

  /// 목록 API에는 [instruction_blocks] 본문이 비어 있을 수 있어 상세 조회로 채운다.
  var _loadingInstructionDetail = false;
  Future<void>? _instructionDetailFuture;

  /// 이 현장에서 일했던 인력([HumanUseCase.getPlaceWorkerRecentHids]).
  List<HumanModel> _recentHumans = [];

  var _saving = false;
  String _saveStatus = '';

  void _setSaveProgress(String message) {
    if (!mounted) return;
    setState(() {
      _saving = true;
      _saveStatus = message;
    });
  }

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

  List<WorkerAnnouncementBlock> _cloneInstructionBlocks(
    List<WorkerAnnouncementBlock> src,
  ) =>
      src.map((e) => WorkerAnnouncementBlock.fromJson(e.toJson())).toList();

  List<WorkerAnnouncementBlock> _mergedInstructionForPick(
    WorkforcePendingPick pick,
  ) {
    final merged = <WorkerAnnouncementBlock>[];
    void append(List<WorkerAnnouncementBlock> src) {
      if (workInstructionBlocksLookEmpty(src)) return;
      merged.addAll(_cloneInstructionBlocks(src));
    }

    append(_siteInstructionBlocks);
    if (_isProcessScopedCreate) {
      append(_processInstructionBlocks);
    }
    append(pick.instructionBlocks);
    return merged;
  }

  List<WorkerAnnouncementBlock> _applicableInstructionForPick(
    WorkforcePendingPick pick,
  ) =>
      _mergedInstructionForPick(pick);

  /// 공정 작업지시만 별도 API에 저장. `false`면 구 서버(행에 병합 저장).
  Future<bool> _persistProcessInstructionLayer(String workdate) async {
    if (!_isProcessScopedCreate) return true;

    final role = _processRoleLabel;
    if (role == null) return true;

    final uc = ref.read(superAdminRemoteUseCaseProvider);
    try {
      await uc.placeWorkDayProcessInstructionUpsert(
        pid: widget.pid,
        workdate: workdate,
        workrole: role,
        blocks: _processInstructionBlocks,
      );
      return true;
    } catch (e) {
      if (PlaceWorkDayInstructionsRemoteApi.isLayersApiUnavailable(e)) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> _loadInstructionLayersForNewMode() async {
    if (widget.existing != null) return;

    final dk = formatDateTimeToIsoDate(_workDate);
    final role = _processRoleLabel;

    try {
      final bundle = await ref
          .read(superAdminRemoteUseCaseProvider)
          .placeWorkDayInstructionBundle(pid: widget.pid, workdate: dk);
      if (!mounted) return;
      setState(() {
        _siteInstructionBlocks = List<WorkerAnnouncementBlock>.from(
          bundle.siteInstructionBlocks,
        );
        if (_isProcessScopedCreate && role != null) {
          _processInstructionBlocks = List<WorkerAnnouncementBlock>.from(
            bundle.processBlocksFor(role),
          );
        }
      });
    } catch (e) {
      if (!PlaceWorkDayInstructionsRemoteApi.isLayersApiUnavailable(e)) {
        debugPrint('load instruction layers: $e');
      }
    }
  }

  Future<bool> _persistSiteInstructionLayer(String workdate) async {
    if (workInstructionBlocksLookEmpty(_siteInstructionBlocks)) return true;

    final uc = ref.read(superAdminRemoteUseCaseProvider);
    try {
      await uc.placeWorkDaySiteInstructionUpsert(
        pid: widget.pid,
        workdate: workdate,
        blocks: _siteInstructionBlocks,
      );
      return true;
    } catch (e) {
      if (PlaceWorkDayInstructionsRemoteApi.isLayersApiUnavailable(e)) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> _openInstructionEditor({
    required String sheetTitle,
    required String workerLabel,
    required List<WorkerAnnouncementBlock> initial,
    required void Function(List<WorkerAnnouncementBlock> next) onSaved,
  }) async {
    final next = await showPlaceWorkInstructionEditorSheet(
      context: context,
      pid: widget.pid,
      placeName: widget.placeInfo.pname,
      workerLabel: workerLabel,
      sheetTitle: sheetTitle,
      initialBlocks: initial,
    );
    if (next == null || !mounted) return;
    setState(() => onSaved(next));
  }

  Future<void> _editSiteInstruction() {
    return _openInstructionEditor(
      sheetTitle: '전체 작업지시',
      workerLabel: '현장 전체',
      initial: _siteInstructionBlocks,
      onSaved: (next) {
        _siteInstructionTouchedByUser = true;
        _siteInstructionBlocks = workInstructionBlocksLookEmpty(next)
            ? const []
            : List<WorkerAnnouncementBlock>.from(next);
      },
    );
  }

  Widget _siteInstructionPanel(BuildContext context) {
    final hasSite = !workInstructionBlocksLookEmpty(_siteInstructionBlocks);

    return _instructionEditorTile(
      context: context,
      title: '전체 작업지시',
      subtitle: '이 날짜 투입 인원 전체에 적용',
      icon: Icons.assignment_outlined,
      hasContent: hasSite,
      onEdit: _editSiteInstruction,
    );
  }

  Future<void> _editProcessInstruction() {
    final role = _processRoleLabel ?? '공정';
    return _openInstructionEditor(
      sheetTitle: '공정 작업지시',
      workerLabel: role,
      initial: _processInstructionBlocks,
      onSaved: (next) {
        _processInstructionTouchedByUser = true;
        _processInstructionBlocks = workInstructionBlocksLookEmpty(next)
            ? const []
            : List<WorkerAnnouncementBlock>.from(next);
      },
    );
  }

  Widget _processInstructionPanel(BuildContext context) {
    final role = _processRoleLabel ?? '공정';
    final hasProcess =
        !workInstructionBlocksLookEmpty(_processInstructionBlocks);

    return _instructionEditorTile(
      context: context,
      title: '공정 작업지시',
      subtitle: '$role 공정 투입 인원에게 적용',
      icon: Icons.construction_outlined,
      hasContent: hasProcess,
      onEdit: _editProcessInstruction,
    );
  }

  Widget _instructionEditorTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool hasContent,
    required VoidCallback onEdit,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.rs(10)),
        border: Border.all(
          color: hasContent
              ? cs.primary.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.rsi(10),
          context.rsi(8),
          context.rsi(6),
          context.rsi(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: context.rs(20), color: cs.primary),
            SizedBox(width: context.rsi(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: context.rsi(2)),
                  Text(
                    hasContent ? '작성됨 · $subtitle' : subtitle,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onEdit,
              child: Text(hasContent ? '수정' : '작성'),
            ),
          ],
        ),
      ),
    );
  }

  String _primarySpecialtyLabel(HumanModel human) {
    final p = human.displayPrimarySpecialty?.trim();
    if (p != null && p.isNotEmpty) return p;
    return '주특기 미등록';
  }

  Widget _selectedWorkRoleBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final roles = _picks
        .map((p) => p.wrole.trim())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList();
    if (roles.isEmpty) return const SizedBox.shrink();

    final roleText = roles.length == 1 ? roles.first : roles.join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(context.rs(10)),
        border: Border.all(
          color: cs.secondary.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rsi(12),
          vertical: context.rsi(9),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: context.rs(18),
              color: cs.onSecondaryContainer,
            ),
            SizedBox(width: context.rsi(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공정 내용',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSecondaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                  SizedBox(height: context.rsi(2)),
                  Text(
                    roleText,
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSecondaryContainer,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _openHumanMultiPick() async {
    final picked = await showWorkforceHumanMultiPickSheet(
      context: context,
      ref: ref,
      initialSelected: _humansForDropdown,
    );
    if (picked == null || !mounted) return;
    setState(() => _syncPicksFromSelection(picked));
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
        content: AppTextField(
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
      final (chip, customFill) = workRolePresetInitialSelection(roleDefault);
      _editRoleChoice = chip;
      if (customFill.isNotEmpty) {
        _editCustomRoleCtrl!.text = customFill;
      }
      _editInstructionBlocks =
          List<WorkerAnnouncementBlock>.from(e.instructionBlocks);
      _loadingInstructionDetail = true;
      _instructionDetailFuture = _fetchInstructionBlocksFromServer(e.pwdid);
      unawaited(_instructionDetailFuture);
    } else {
      Future.microtask(() async {
        await _loadRecentWorkers();
        await _loadInstructionLayersForNewMode();
      });
    }
  }

  Future<void> _fetchInstructionBlocksFromServer(int pwdid) async {
    try {
      final full = await ref
          .read(superAdminRemoteUseCaseProvider)
          .placeWorkDayGet(pwdid);
      if (!mounted) return;
      setState(() {
        final individual = full.individualInstructionBlocks;
        _editInstructionBlocks = individual.isNotEmpty
            ? List<WorkerAnnouncementBlock>.from(individual)
            : List<WorkerAnnouncementBlock>.from(full.instructionBlocks);
        _loadingInstructionDetail = false;
      });
    } catch (e, st) {
      debugPrint('placeWorkDayGet instruction_blocks: $e\n$st');
      if (mounted) {
        setState(() => _loadingInstructionDetail = false);
      }
    }
  }

  Future<void> _ensureInstructionBlocksLoaded(PlaceWorkDayRead row) async {
    final pending = _instructionDetailFuture;
    if (pending != null) {
      await pending;
      return;
    }
    if (_loadingInstructionDetail) return;
    _loadingInstructionDetail = true;
    _instructionDetailFuture = _fetchInstructionBlocksFromServer(row.pwdid);
    await _instructionDetailFuture;
  }

  Future<void> _loadRecentWorkers() async {
    print('\n🚀 [인력투입] 최근 작업자 목록 로드 시작 (PID: ${widget.pid})');
    final startTime = DateTime.now();

    try {
      // ✅ 새로운 통합 API 사용 (1회 호출)
      final list = await ref.read(humanUseCaseProvider).getPlaceRecentWorkers(
            widget.pid,
            limit: 100,
          );

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print('✅ [인력투입] 작업자 목록 로드 완료: ${duration}ms, ${list.length}명\n');

      if (mounted) setState(() => _recentHumans = list);
    } catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      print('❌ [인력투입] 작업자 목록 로드 실패: ${duration}ms - $e\n');

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
      sheetTitle: '개별 작업지시',
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
    await _ensureInstructionBlocksLoaded(row);
    if (!mounted) return;
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
    if (_saving) return;
    final existing = widget.existing;
    final sheetCtx = context;
    final dk = formatDateTimeToIsoDate(_workDate);

    Future<void> closeAndRefresh([String? snackbarMessage]) async {
      if (!sheetCtx.mounted) return;
      Navigator.of(sheetCtx).pop();
      await Future<void>.delayed(Duration.zero);
      await widget.onSuccess(snackbarMessage);
      await FetchData.onDataChanged(
        DataChangeEvent(
          DataChangeKind.workCost,
          pid: widget.pid,
          date: _workDate,
        ),
        background: false,
      );
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
    }

    _setSaveProgress(
      existing == null ? '저장 준비 중…' : '작업 내용 저장 중…',
    );
    try {
      if (existing == null) {
        await _submitCreate(sheetCtx, dk, closeAndRefresh);
      } else {
        await _submitEdit(sheetCtx, existing, closeAndRefresh);
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveStatus = '';
        });
      }
    }
  }

  Future<void> _submitCreate(
    BuildContext sheetCtx,
    String dk,
    Future<void> Function([String? snackbarMessage]) closeAndRefresh,
  ) async {
    final hids = _picks.map((p) => p.human.hid).whereType<int>().toList();
    if (hids.isNotEmpty) {
      try {
        _setSaveProgress('다른 현장 일정 확인 중…');
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
    final mergedForAddCost = <({HumanModel human, int wprice, String wrole})>[];
    final total = _picks.length;

    _setSaveProgress('작업지시 저장 중…');
    if (_siteInstructionTouchedByUser) {
      await _persistSiteInstructionLayer(dk);
    }
    var layersSaved = true;
    if (_processInstructionTouchedByUser) {
      layersSaved = await _persistProcessInstructionLayer(dk);
    }

    for (var i = 0; i < _picks.length; i++) {
      final pick = _picks[i];
      final hum = pick.human;
      final h = hum.hid;
      final instructionForRow = layersSaved
          ? pick.instructionBlocks
          : _mergedInstructionForPick(pick);
      final hasInstruction = !workInstructionBlocksLookEmpty(instructionForRow);
      _setSaveProgress(
        hasInstruction
            ? '작업지시 등록 중… (${i + 1}/$total)'
            : '인력 등록 중… (${i + 1}/$total)',
      );
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
        if (hasInstruction) {
          body['instruction_blocks'] =
              instructionForRow.map((e) => e.toJson()).toList();
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
      _setSaveProgress('트러블 페어 확인 중…');
      final overrideOk = await _confirmTroubleOverride(sheetCtx);
      if (overrideOk) {
        for (var i = 0; i < troublePicks.length; i++) {
          final pick = troublePicks[i];
          _setSaveProgress(
            '재시도 중… (${i + 1}/${troublePicks.length})',
          );
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
            final instructionForRow = layersSaved
                ? pick.instructionBlocks
                : _mergedInstructionForPick(pick);
            if (!workInstructionBlocksLookEmpty(instructionForRow)) {
              body['instruction_blocks'] =
                  instructionForRow.map((e) => e.toJson()).toList();
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
      _setSaveProgress('공수 반영 중…');
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
      await ref.read(placeMembersUseCaseProvider).inviteAssignedWorkersToPlace(
            widget.pid,
            mergedForAddCost.map((e) => e.human),
          );
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
  }

  Future<void> _submitEdit(
    BuildContext sheetCtx,
    PlaceWorkDayRead existing,
    Future<void> Function([String? snackbarMessage]) closeAndRefresh,
  ) async {
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
      _setSaveProgress('작업 내용 저장 중…');
      await ref.read(superAdminRemoteUseCaseProvider).placeWorkDayPatch(
        existing.pwdid,
        <String, dynamic>{
          'dailywage': w,
          'workrole': role,
          'instruction_blocks':
              _editInstructionBlocks.map((e) => e.toJson()).toList(),
          PlaceWorkDayFields.individualInstructionBlocks:
              _editInstructionBlocks.map((e) => e.toJson()).toList(),
        },
      );
      await ref.read(workCostUseCaseProvider).ensureWorkCostForPlaceWorkDay(
            pid: widget.pid,
            hid: existing.hid,
            dateKey: formatDateTimeToIsoDate(_workDate),
            wprice: w,
            wrole: role,
          );
      await closeAndRefresh();
    } catch (e) {
      if (!sheetCtx.mounted) return;
      if (isWorkerTroublePairConflictError(e)) {
        final proceed = await _confirmTroubleOverride(sheetCtx);
        if (!sheetCtx.mounted) return;
        if (proceed) {
          try {
            _setSaveProgress('작업 내용 저장 중…');
            await ref.read(superAdminRemoteUseCaseProvider).placeWorkDayPatch(
              existing.pwdid,
              <String, dynamic>{
                'dailywage': w,
                'workrole': role,
                'instruction_blocks':
                    _editInstructionBlocks.map((e) => e.toJson()).toList(),
                PlaceWorkDayFields.individualInstructionBlocks:
                    _editInstructionBlocks.map((e) => e.toJson()).toList(),
                PlaceWorkDayFields.acknowledgeTroublePair: true,
              },
            );
            await ref
                .read(workCostUseCaseProvider)
                .ensureWorkCostForPlaceWorkDay(
                  pid: widget.pid,
                  hid: existing.hid,
                  dateKey: formatDateTimeToIsoDate(_workDate),
                  wprice: w,
                  wrole: role,
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
                    const TextSpan(text: '업로드일 '),
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

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: context.rsi(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            existing == null ? '단일 날짜 투입' : '인력 투입 수정',
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.rsi(10)),
                    _workDateBanner(context),
                    if (existing == null) ...[
                      SizedBox(height: context.rsi(14)),
                      _siteInstructionPanel(context),
                      if (_isProcessScopedCreate) ...[
                        SizedBox(height: context.rsi(14)),
                        _processInstructionPanel(context),
                      ],
                      SizedBox(height: context.rsi(14)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: context.rs(48),
                              child: OutlinedButton(
                                onPressed: _openHumanMultiPick,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.rsi(12),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(context.rsi(12)),
                                  ),
                                  alignment: Alignment.centerLeft,
                                ),
                                child: Text(
                                  _picks.isEmpty
                                      ? '사람 선택'
                                      : '${_picks.length}명 선택됨',
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: _picks.isEmpty
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                    color: _picks.isEmpty
                                        ? cs.onSurfaceVariant
                                        : cs.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
                        _selectedWorkRoleBanner(context),
                        SizedBox(height: context.rsi(10)),
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
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: context.rsi(8),
                            crossAxisSpacing: context.rsi(8),
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _picks.length,
                          itemBuilder: (context, index) {
                            final originalIndex = _picks.length - 1 - index;
                            final pick = _picks[originalIndex];
                            final hasIndividual =
                                !workInstructionBlocksLookEmpty(
                              _applicableInstructionForPick(pick),
                            );
                            return _WorkforcePickGridCard(
                              name: pick.human.hname,
                              specialtyLabel:
                                  _primarySpecialtyLabel(pick.human),
                              priceText: getPrice(price: pick.wprice),
                              hasIndividualInstruction: hasIndividual,
                              onEditWage: () => _editPickWage(pick),
                              onDelete: () => _removePick(pick),
                              onEditIndividualInstruction: () =>
                                  _editPickInstruction(pick),
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
                      AppTextField(
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
                            for (var i = 0;
                                i < kWorkRolePresets.length;
                                i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              ChoiceChip(
                                label: Text(
                                  kWorkRolePresets[i],
                                  style: tt.labelLarge,
                                ),
                                selected:
                                    _editRoleChoice == kWorkRolePresets[i],
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
                        AppTextField(
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
                        leading:
                            Icon(Icons.assignment_outlined, color: cs.primary),
                        title: const Text('작업 내용'),
                        subtitle: Text(
                          _loadingInstructionDetail
                              ? '작업 내용 불러오는 중…'
                              : workInstructionBlocksLookEmpty(
                                      _editInstructionBlocks)
                                  ? '목공·전기 등 세부 지시와 도면 사진 삽입 (선택)'
                                  : '등록된 지시가 있습니다 · 텍스트·사진 수정',
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                        trailing: _loadingInstructionDetail
                            ? SizedBox(
                                width: context.rs(22),
                                height: context.rs(22),
                                child: const HammerLoadingIndicator(size: 20),
                              )
                            : Icon(Icons.edit_outlined,
                                color: cs.onSurfaceVariant),
                        onTap: _loadingInstructionDetail || _saving
                            ? null
                            : () {
                                final e = widget.existing;
                                if (e != null) {
                                  unawaited(_editExistingInstruction(e));
                                }
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
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: context.rs(18),
                            height: context.rs(18),
                            child: const HammerLoadingIndicator(size: 18),
                          ),
                          SizedBox(width: context.rsi(10)),
                          Text(
                            _saveStatus.isEmpty ? '저장 중…' : _saveStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : Text(existing == null ? '등록' : '저장'),
              ),
            ),
          ],
        ),
        if (_saving)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.28),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.rsi(24),
                        vertical: context.rsi(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HammerLoadingIndicator(size: 28),
                          SizedBox(height: context.rsi(14)),
                          Text(
                            _saveStatus.isEmpty ? '저장 중…' : _saveStatus,
                            textAlign: TextAlign.center,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 선택 인원 그리드 카드 — 주특기·일당 표시, 하단 개별 작업지시.
class _WorkforcePickGridCard extends StatelessWidget {
  const _WorkforcePickGridCard({
    required this.name,
    required this.specialtyLabel,
    required this.priceText,
    required this.hasIndividualInstruction,
    required this.onEditWage,
    required this.onDelete,
    required this.onEditIndividualInstruction,
  });

  final String name;
  final String specialtyLabel;
  final String priceText;
  final bool hasIndividualInstruction;
  final VoidCallback onEditWage;
  final VoidCallback onDelete;
  final VoidCallback onEditIndividualInstruction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(context.rs(10));
    final accent = hasIndividualInstruction ? cs.tertiary : cs.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: radius,
        border: Border.all(
          color:
              accent.withValues(alpha: hasIndividualInstruction ? 0.5 : 0.28),
          width: hasIndividualInstruction ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onEditWage,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.rsi(8),
                            context.rsi(10),
                            context.rsi(8),
                            context.rsi(4),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: tt.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              SizedBox(height: context.rsi(3)),
                              Text(
                                specialtyLabel,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                ),
                              ),
                              SizedBox(height: context.rsi(4)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  priceText,
                                  style: tt.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Material(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.only(
                        topRight: radius.topRight,
                        bottomLeft: Radius.circular(context.rs(8)),
                      ),
                      child: InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.only(
                          topRight: radius.topRight,
                          bottomLeft: Radius.circular(context.rs(8)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(context.rsi(4)),
                          child: Icon(
                            Icons.close_rounded,
                            size: context.rs(15),
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: hasIndividualInstruction
                  ? cs.tertiaryContainer.withValues(alpha: 0.85)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.7),
              child: InkWell(
                onTap: onEditIndividualInstruction,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: context.rsi(6),
                    horizontal: context.rsi(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasIndividualInstruction
                            ? Icons.person_pin_rounded
                            : Icons.person_outline_rounded,
                        size: context.rs(14),
                        color: accent,
                      ),
                      SizedBox(width: context.rsi(4)),
                      Flexible(
                        child: Text(
                          hasIndividualInstruction ? '개별지시·수정' : '개별지시',
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: hasIndividualInstruction
                                ? cs.onTertiaryContainer
                                : cs.onSurfaceVariant,
                          ),
                        ),
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
