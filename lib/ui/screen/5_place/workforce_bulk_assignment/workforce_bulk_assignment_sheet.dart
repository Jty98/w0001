import 'dart:async';

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/list_query.dart';
import 'package:w0001/data/datasources/remote/place/place_work_day_instructions_api.dart';
import 'package:w0001/data/model/bulk_workforce_assignment.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/domain/process_schedule/process_schedule_editor.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_process_schedule_notifier.dart';
import 'package:w0001/presentation/viewmodel/place_workforce_notifier.dart'
    show placeWorkforceProvider;
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show placeUseCaseProvider, humanUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_members_providers.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_editor_dialog.dart';
import 'package:w0001/ui/screen/2_add/place_recent_workers_sheet.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/human_work_assignability.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/worker_skills_display.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_dialogs.dart';
import 'package:w0001/ui/screen/5_place/process_schedule/process_schedule_helpers.dart';

import 'date_range_picker_sheet.dart';
import 'worker_details_sheet.dart';
import 'workforce_worker_identify_sheet.dart';
import 'assignment_logic.dart';
import 'models.dart';
import 'common_widgets.dart';
import 'post_save_sync.dart';
import 'site_instruction_uploader.dart';
import 'step_detail_widgets.dart';
import 'step_sections.dart';

/// 공정별 투입 현황 정보
class ProcessAssignmentStatus {
  final int totalDays; // 공정 전체 기간
  final int assignedDays; // 투입된 날짜 수
  final int totalWorkers; // 투입된 총 인원 수 (중복 제거)
  final Set<int> assignedDates; // 투입된 날짜 인덱스

  ProcessAssignmentStatus({
    required this.totalDays,
    required this.assignedDays,
    required this.totalWorkers,
    required this.assignedDates,
  });

  double get completionRate => totalDays > 0 ? assignedDays / totalDays : 0.0;
  bool get isFullyAssigned => assignedDays >= totalDays && totalWorkers > 0;
  bool get isPartiallyAssigned => assignedDays > 0 && assignedDays < totalDays;
  bool get hasNoAssignment => assignedDays == 0;
}

enum WorkerSearchType {
  name('name', '이름으로 검색', null, '이름으로 검색'),
  chosung('chosung', '초성으로 검색', '예: ㄱㅎㅅ → 김형수', '초성으로 검색 (예: ㄱㅎㅅ)'),
  specialty('specialty', '주특기로 검색', null, '주특기로 검색');

  const WorkerSearchType(this.value, this.label, this.subtitle, this.hintText);

  final String value;
  final String label;
  final String? subtitle;
  final String hintText;
}

/// 기간별 일괄 인력투입 바텀시트
///
/// 공정표의 기간을 활용하여 여러 날짜에 대한 작업투입을 한 번에 처리합니다.
Future<bool> showBulkWorkforceAssignmentSheet({
  required BuildContext context,
  required int pid,
  String? pname,
  List<ProcessScheduleTask>? processTasks,
  DateTime? gridStart,
  int? placeRevenue, // 공사금액 (옵션)
  int? totalExpenses, // 총 지출 (옵션)
  DateTime? initialDate, // 초기 선택 날짜 (옵션)
  String? defaultWorkrole, // 기본 역할 (옵션)
  ProcessScheduleTask? initialTask, // 공정 카드에서 진입 시 해당 공정
  PlaceInfoModel? placeInfo, // 공정표 연동·저장용
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    useSafeArea: true,
    builder: (context) => Padding(
      // 키보드가 올라올 때 콘텐츠를 위로 밀어올림
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (context, scrollController) => _BulkWorkforceAssignmentSheet(
          pid: pid,
          pname: pname,
          processTasks: processTasks ?? [],
          gridStart: gridStart,
          scrollController: scrollController,
          initialPlaceRevenue: placeRevenue,
          initialTotalExpenses: totalExpenses,
          initialDate: initialDate,
          defaultWorkrole: defaultWorkrole,
          initialTask: initialTask,
          placeInfo: placeInfo,
        ),
      ),
    ),
  );
  return saved == true;
}

class _BulkWorkforceAssignmentSheet extends ConsumerStatefulWidget {
  const _BulkWorkforceAssignmentSheet({
    required this.pid,
    this.pname,
    required this.processTasks,
    this.gridStart,
    required this.scrollController,
    this.initialPlaceRevenue,
    this.initialTotalExpenses,
    this.initialDate,
    this.defaultWorkrole,
    this.initialTask,
    this.placeInfo,
  });

  final int pid;
  final String? pname;
  final List<ProcessScheduleTask> processTasks;
  final DateTime? gridStart;
  final ScrollController scrollController;
  final int? initialPlaceRevenue;
  final int? initialTotalExpenses;
  final DateTime? initialDate;
  final String? defaultWorkrole;
  final ProcessScheduleTask? initialTask;
  final PlaceInfoModel? placeInfo;

  @override
  ConsumerState<_BulkWorkforceAssignmentSheet> createState() =>
      _BulkWorkforceAssignmentSheetState();
}

class _BulkWorkforceAssignmentSheetState
    extends ConsumerState<_BulkWorkforceAssignmentSheet> {
  // 단계 관리
  int _currentStep = 0;

  // Step 0: 공정 및 기간 선택
  ProcessScheduleTask? _selectedTask;
  int? _selectedTaskIndex;
  DateTime? _startDate;
  DateTime? _endDate;

  // Step 1: 인력 선택
  List<HumanModel> _selectedHumans = [];
  final Map<int, String> _humanWorkRoles = {}; // hid -> workrole
  final Map<int, int> _humanWages = {}; // hid -> daily_wage
  List<HumanModel> _recentWorkers = []; // 최근 작업자 목록
  bool _loadingRecentWorkers = false;
  String _searchQuery = ''; // 검색어
  WorkerSearchType _searchType = WorkerSearchType.name;
  List<HumanModel> _searchResults = [];
  bool _searchLoading = false;
  List<HumanModel> _allWorkersCache = [];
  Set<String> _blockedMemberUids = {};
  bool _blockedUidsLoaded = false;
  Timer? _searchDebounce;

  // Step 2: 저장 중
  bool _saving = false;
  String _saveError = '';
  var _scheduleRangeSynced = false;
  List<WorkerAnnouncementBlock> _globalWorkInstructionBlocks = []; // 전체 작업지시
  bool _workInstructionExpanded = false; // 작업지시 섹션 확장 상태
  String? _siteInstructionLoadedForIso;
  bool _siteInstructionTouchedByUser = false;

  // 현장 재무 데이터
  int _placeRevenue = 0; // 공사금액
  int _totalExpenses = 0; // 총 지출
  bool _loadingFinancialData = false;

  // 공정별 투입 현황
  Map<String, ProcessAssignmentStatus> _processAssignmentStatus = {};

  /// 시트 오픈 시점 스냅샷 — 공정 추가·동기화 후 provider에서 갱신한다.
  late List<ProcessScheduleTask> _processTasks;
  DateTime? _gridStart;

  @override
  void initState() {
    super.initState();
    _processTasks = List<ProcessScheduleTask>.from(widget.processTasks);
    _gridStart = widget.gridStart;

    final initialDay = widget.initialDate ?? DateTime.now();
    _startDate = DateTime(initialDay.year, initialDay.month, initialDay.day);
    _endDate = _startDate;

    final matchedTask = _resolveInitialTask();
    if (matchedTask != null) {
      _selectedTask = matchedTask;
      _selectedTaskIndex = _taskIndexOf(matchedTask);
      _applyProcessDateRange(matchedTask);
    }

    // 초기 재무 데이터가 제공된 경우 사용
    if (widget.initialPlaceRevenue != null) {
      _placeRevenue = widget.initialPlaceRevenue!;
    }
    if (widget.initialTotalExpenses != null) {
      _totalExpenses = widget.initialTotalExpenses!;
    }

    // 최근 작업자 로드
    _loadRecentWorkers();
    _loadBlockedMemberUids();

    // 재무 데이터가 제공되지 않은 경우에만 로드
    if (widget.initialPlaceRevenue == null ||
        widget.initialTotalExpenses == null) {
      _loadFinancialData();
    } else {
      debugPrint('💰 [재무 데이터] 파라미터로 제공됨');
      debugPrint('   - 공사금액: $_placeRevenue');
      debugPrint('   - 총 지출: $_totalExpenses');
    }

    // 공정별 투입 현황 계산
    _calculateProcessAssignmentStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncProcessSnapshotFromProvider(recalcStatus: false);
      unawaited(_loadExistingSiteInstruction(force: true));
    });

    if (widget.initialTask != null || widget.defaultWorkrole != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openInitialDatePickerIfNeeded();
      });
    }
  }

  void _onWorkPeriodChanged() {
    _scheduleRangeSynced = false;
    _siteInstructionTouchedByUser = false;
    _siteInstructionLoadedForIso = null;
    unawaited(_loadExistingSiteInstruction(force: true));
  }

  /// 해당 기간 시작일에 저장된 전체 작업지시를 불러온다 (추가 투입 시 기존 내용 유지).
  Future<void> _loadExistingSiteInstruction({bool force = false}) async {
    final start = _startDate;
    if (start == null) return;
    final iso = formatDateTimeToIsoDate(start);
    if (!force && _siteInstructionLoadedForIso == iso) return;

    try {
      final bundle = await ref
          .read(superAdminRemoteUseCaseProvider)
          .placeWorkDayInstructionBundle(pid: widget.pid, workdate: iso);
      if (!mounted) return;
      setState(() {
        _siteInstructionLoadedForIso = iso;
        if (!_siteInstructionTouchedByUser) {
          _globalWorkInstructionBlocks = List<WorkerAnnouncementBlock>.from(
            bundle.siteInstructionBlocks,
          );
        }
      });
    } catch (e) {
      if (!PlaceWorkDayInstructionsRemoteApi.isLayersApiUnavailable(e)) {
        debugPrint('load bulk site instruction: $e');
      }
      if (mounted) {
        setState(() => _siteInstructionLoadedForIso = iso);
      }
    }
  }

  int? _taskIndexOf(ProcessScheduleTask task) {
    for (var i = 0; i < _processTasks.length; i++) {
      if (identical(_processTasks[i], task)) return i;
    }
    final id = task.serverId?.trim();
    if (id != null && id.isNotEmpty) {
      for (var i = 0; i < _processTasks.length; i++) {
        if (_processTasks[i].serverId?.trim() == id) return i;
      }
    }
    return null;
  }

  void _syncProcessSnapshotFromProvider({bool recalcStatus = true}) {
    final arg = _scheduleArg;
    if (arg == null) return;
    final st = ref.read(placeProcessScheduleProvider(arg));
    if (!st.isReady) return;

    final prevTask = _selectedTask;
    final prevIndex = _selectedTaskIndex;

    setState(() {
      _processTasks = List<ProcessScheduleTask>.from(st.data.tasks);
      _gridStart = st.data.gridStart;

      if (prevTask != null) {
        final idx = _findTaskIndexInData(
          st.data,
          serverId: prevTask.serverId,
          name: prevTask.name.trim(),
        );
        if (idx != null) {
          _selectedTask = st.data.tasks[idx];
          _selectedTaskIndex = idx;
        }
      } else if (prevIndex != null &&
          prevIndex >= 0 &&
          prevIndex < st.data.tasks.length) {
        _selectedTask = st.data.tasks[prevIndex];
        _selectedTaskIndex = prevIndex;
      }
    });

    if (recalcStatus) _calculateProcessAssignmentStatus();
  }

  ProcessScheduleFamilyArg? get _scheduleArg {
    final place = widget.placeInfo;
    final pid = place?.pid;
    if (place == null || pid == null || pid <= 0) return null;
    return (pid: pid, pstart: place.pstart, pend: place.pend);
  }

  /// 투입 기간을 공정표에 반영 — 범위 밖 날짜는 해당 공정 행을 확장해 저장한다.
  Future<void> _syncProcessScheduleForRange(
    DateTime rangeStart,
    DateTime rangeEnd, {
    ProcessScheduleTask? taskOverride,
    int? taskIndexOverride,
  }) async {
    final arg = _scheduleArg;
    if (arg == null) return;

    final notifier = ref.read(placeProcessScheduleProvider(arg).notifier);
    var scheduleState = ref.read(placeProcessScheduleProvider(arg));
    if (!scheduleState.isReady) return;

    final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    var taskIndex = taskIndexOverride ?? _selectedTaskIndex;
    var taskName =
        taskOverride?.name.trim() ?? _selectedTask?.name.trim() ?? '';

    if (taskIndex == null && taskName.isEmpty) {
      taskName = widget.defaultWorkrole?.trim() ?? '';
    }

    if (taskIndex == null && taskName.isEmpty && _humanWorkRoles.isNotEmpty) {
      final roles = _humanWorkRoles.values
          .map((r) => r.trim())
          .where((r) => r.isNotEmpty)
          .toSet();
      if (roles.length == 1) {
        taskName = roles.first;
      }
    }

    if (taskIndex == null && taskName.isNotEmpty) {
      for (var i = 0; i < scheduleState.data.tasks.length; i++) {
        if (scheduleState.data.tasks[i].name.trim() == taskName) {
          taskIndex = i;
          break;
        }
      }
    }

    if (taskIndex != null &&
        taskIndex >= 0 &&
        taskIndex < scheduleState.data.tasks.length) {
      notifier.extendTaskToCoverCalendarRange(taskIndex, start, end);
      await notifier.persist(syncPlaceMaster: widget.placeInfo);
      if (!mounted) return;
      _scheduleRangeSynced = true;
      _syncProcessSnapshotFromProvider(recalcStatus: false);
      return;
    }

    if (taskName.isNotEmpty) {
      notifier.expandGridToIncludeDay(start);
      notifier.expandGridToIncludeDay(end);
      scheduleState = ref.read(placeProcessScheduleProvider(arg));
      final lo = ProcessScheduleEditor.gridIndexForCalendarDay(
        scheduleState.data,
        start,
      );
      final hi = ProcessScheduleEditor.gridIndexForCalendarDay(
        scheduleState.data,
        end,
      );
      if (lo == null || hi == null) return;
      notifier.upsertProcess(taskName, lo, hi);
      await notifier.persist(syncPlaceMaster: widget.placeInfo);
      if (!mounted) return;
      _scheduleRangeSynced = true;
      _syncProcessSnapshotFromProvider(recalcStatus: false);
    }
  }

  int? _findTaskIndexInData(
    ProcessScheduleData data, {
    String? serverId,
    required String name,
  }) {
    final id = serverId?.trim();
    if (id != null && id.isNotEmpty) {
      for (var i = 0; i < data.tasks.length; i++) {
        if (data.tasks[i].serverId?.trim() == id) return i;
      }
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    for (var i = 0; i < data.tasks.length; i++) {
      if (data.tasks[i].name.trim() == trimmed) return i;
    }
    return null;
  }

  ProcessScheduleTask? _resolveInitialTask() {
    final direct = widget.initialTask;
    if (direct != null) return direct;

    final role = widget.defaultWorkrole?.trim();
    if (role == null || role.isEmpty) return null;

    ProcessScheduleTask? lastMatch;
    for (final task in _processTasks) {
      if (task.name.trim() == role) lastMatch = task;
    }
    return lastMatch;
  }

  void _applyProcessDateRange(ProcessScheduleTask task) {
    final gridStart = _gridStart;
    final indices = task.scheduledDayIndices;
    if (gridStart == null || indices.isEmpty) return;

    _startDate = gridStart.add(Duration(days: indices.first));
    _endDate = gridStart.add(Duration(days: indices.last));
  }

  Future<void> _openInitialDatePickerIfNeeded() async {
    final task = _selectedTask ?? _resolveInitialTask();
    if (task == null || _gridStart == null) return;

    final indices = task.scheduledDayIndices;
    if (indices.isEmpty) return;

    final processStart = _gridStart!.add(Duration(days: indices.first));
    final processEnd = _gridStart!.add(Duration(days: indices.last));
    await _showDateRangePickerDialog(
      context,
      task,
      _taskIndexOf(task) ?? 0,
      processStart,
      processEnd,
    );
  }

  /// 공정별 투입 현황 계산
  void _calculateProcessAssignmentStatus() {
    if (_gridStart == null) return;

    final wf = ref.read(placeWorkforceProvider(widget.pid));
    final workDays = wf.rows; // 현재 투입된 작업일정 목록

    // 각 공정별로 투입 현황 계산
    final statusMap = <String, ProcessAssignmentStatus>{};

    for (var i = 0; i < _processTasks.length; i++) {
      final task = _processTasks[i];
      final dayIndices = task.scheduledDayIndices;
      if (dayIndices.isEmpty) continue;

      final totalDays = dayIndices.last - dayIndices.first + 1;

      // 이 공정에 투입된 날짜와 인원 찾기
      final assignedDates = <int>{};
      final assignedWorkers = <int>{};

      for (final workDay in workDays) {
        // workrole이 공정명과 일치하는지 확인
        if (workDay.workrole.trim() != task.name) continue;

        // workdate를 날짜 인덱스로 변환
        final workDateStr = workDay.workdate.length >= 10
            ? workDay.workdate.substring(0, 10)
            : workDay.workdate;
        final workDate = DateTime.tryParse(workDateStr);

        if (workDate != null) {
          final dayIndex = workDate.difference(_gridStart!).inDays;
          // 공정 기간 내의 날짜인지 확인
          if (dayIndices.contains(dayIndex)) {
            assignedDates.add(dayIndex);
            assignedWorkers.add(workDay.hid);
          }
        }
      }

      statusMap[processTaskKey(task, i)] = ProcessAssignmentStatus(
        totalDays: totalDays,
        assignedDays: assignedDates.length,
        totalWorkers: assignedWorkers.length,
        assignedDates: assignedDates,
      );
    }

    if (mounted) {
      setState(() {
        _processAssignmentStatus = statusMap;
      });
    }
  }

  /// 공정 데이터 모델
  List<ProcessEventData> _buildProcessEventData() {
    if (_processTasks.isEmpty || _gridStart == null) {
      return [];
    }

    return _processTasks
        .asMap()
        .entries
        .map((entry) {
          final taskIndex = entry.key;
          final task = entry.value;
          final dayIndices = task.scheduledDayIndices;
          if (dayIndices.isEmpty) return null;

          final firstIdx = dayIndices.first;
          final lastIdx = dayIndices.last;
          final startDate = _gridStart!.add(Duration(days: firstIdx));
          final endDate = _gridStart!.add(Duration(days: lastIdx));

          return ProcessEventData(
            task: task,
            taskIndex: taskIndex,
            startDate: startDate,
            endDate: endDate,
            isSelected: isSameProcessTask(
              _selectedTask,
              _selectedTaskIndex,
              task,
              taskIndex,
            ),
          );
        })
        .whereType<ProcessEventData>()
        .toList();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  List<HumanModel> _assignableWorkers(Iterable<HumanModel> workers) {
    return workers
        .where(
          (h) => humanCanBeAssignedToWork(
            h,
            blockedMemberUids: _blockedMemberUids,
          ),
        )
        .toList();
  }

  Future<void> _ensureBlockedMemberUids() async {
    if (_blockedUidsLoaded) return;
    await _loadBlockedMemberUids();
  }

  Future<void> _loadBlockedMemberUids() async {
    try {
      final uids = await fetchNonAssignableMemberUids(
        ref.read(superAdminRemoteUseCaseProvider),
      );
      if (!mounted) return;
      setState(() {
        _blockedMemberUids = uids;
        _blockedUidsLoaded = true;
        _selectedHumans = _assignableWorkers(_selectedHumans);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _blockedUidsLoaded = true);
      }
    }
  }

  Future<void> _performWorkerSearch() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchLoading = false;
        });
      }
      return;
    }

    setState(() => _searchLoading = true);

    try {
      await _ensureBlockedMemberUids();
      if (!mounted) return;

      List<HumanModel> candidates;
      if (_searchType == WorkerSearchType.name) {
        final page = await ref.read(humanUseCaseProvider).searchWorkersPage(
              q: query,
              limit: 50,
            );
        candidates = page.items.where((h) => h.hdelete == 0).toList();
      } else {
        if (_allWorkersCache.isEmpty) {
          _allWorkersCache =
              await ref.read(humanUseCaseProvider).fetchAllWorkers(
                    const ListQuery(),
                  );
        }
        candidates = _allWorkersCache.where((human) {
          switch (_searchType) {
            case WorkerSearchType.chosung:
              return _getChosung(human.hname).contains(query.toUpperCase());
            case WorkerSearchType.specialty:
              final specialty = human.displayPrimarySpecialty?.trim() ?? '';
              return specialty.toLowerCase().contains(query.toLowerCase());
            case WorkerSearchType.name:
              return false;
          }
        }).toList();
      }

      if (mounted) {
        setState(() {
          _searchResults = candidates;
          _searchLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 인력 검색 실패: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchLoading = false;
        });
      }
    }
  }

  void _onSearchQueryChanged(String value) {
    final normalized = value.toLowerCase();
    setState(() => _searchQuery = normalized);
    _searchDebounce?.cancel();
    if (normalized.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _performWorkerSearch,
    );
  }

  void _clearSearchQuery() {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _searchLoading = false;
    });
  }

  Future<void> _removeRecentWorker(HumanModel human) async {
    final hid = human.hid;
    if (hid == null) return;
    await ref
        .read(humanUseCaseProvider)
        .deletePlaceWorkerRecent(widget.pid, hid);
    if (!mounted) return;
    setState(() {
      _recentWorkers.removeWhere((h) => h.hid == hid);
      _selectedHumans.removeWhere((h) => h.hid == hid);
      _humanWorkRoles.remove(hid);
      _humanWages.remove(hid);
    });
  }

  /// 최근 작업자 목록 로드
  Future<void> _loadRecentWorkers() async {
    if (_loadingRecentWorkers) return;

    setState(() => _loadingRecentWorkers = true);

    try {
      final workers =
          await ref.read(humanUseCaseProvider).getPlaceRecentWorkers(
                widget.pid,
                limit: 50,
              );

      if (mounted) {
        setState(() {
          _recentWorkers = workers.where((h) => h.hdelete == 0).toList();
          _loadingRecentWorkers = false;
        });
      }
    } catch (e) {
      debugPrint('❌ 최근 작업자 로드 실패: $e');
      if (mounted) {
        setState(() => _loadingRecentWorkers = false);
      }
    }
  }

  /// 인력관리와 동일한 비회원 등록 다이얼로그
  Future<void> _showAddWorkerDialog(BuildContext context) async {
    ref.read(workerProvider.notifier).cancelHumanEditorForm();
    await showHumanEditorDialog(
      context: context,
      ref: ref,
    );
    // 다이얼로그가 닫힌 후 최근 작업자 목록 다시 로드
    if (mounted) {
      await _loadRecentWorkers();
    }
  }

  /// 최근 작업자 전체보기 시트
  Future<void> _showRecentWorkersFullList(BuildContext context) async {
    await showPlaceRecentWorkersGroupedSheet(
      context: context,
      initialWorkers: _recentWorkers,
      onWorkerTap: (human) async {
        // 이미 선택된 인원인지 확인
        final isAlreadySelected =
            _selectedHumans.any((h) => h.hid == human.hid);
        if (isAlreadySelected) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이미 선택된 인원입니다.')),
            );
          }
          return;
        }

        // 인원을 선택 목록에 추가
        if (mounted) {
          setState(() {
            _selectedHumans.add(human);
            // 기본 일당 설정
            if (human.hid != null) {
              _humanWages[human.hid!] = human.hdailyWage;
              // 기본 역할 설정
              final role = widget.defaultWorkrole ??
                  _selectedTask?.name ??
                  human.effectiveDefaultWorkRole;
              if (role.isNotEmpty) {
                _humanWorkRoles[human.hid!] = role;
              }
            }
          });
        }
      },
      onRemoveFromList: (human) async {
        final hid = human.hid;
        if (hid == null) return;
        await ref
            .read(humanUseCaseProvider)
            .deletePlaceWorkerRecent(widget.pid, hid);
      },
      onWorkersListChanged: _loadRecentWorkers,
      closeSheetOnWorkerTap: false,
    );
  }

  /// 현장 재무 데이터 로드
  Future<void> _loadFinancialData() async {
    if (_loadingFinancialData) return;

    setState(() => _loadingFinancialData = true);

    try {
      final placeUseCase = ref.read(placeUseCaseProvider);

      // 현장 목록에서 해당 현장 찾기 (관리자 데이터로 조회)
      final places = await placeUseCase.getAllPlaces(
        managementPlacesInfoFirst: true,
      );

      debugPrint('📋 [DEBUG] 현장 목록 조회: ${places.length}개');

      final targetPlace = places.firstWhere(
        (p) => p.pid == widget.pid,
        orElse: () {
          debugPrint('⚠️ [DEBUG] 현장 목록에서 PID ${widget.pid} 를 찾지 못함!');
          return PlaceInfoModel(
            pid: widget.pid,
            pname: widget.pname ?? '',
            pstart: '',
            pend: '',
            paddress: '',
            pcomplete: 0,
            pfirstrevenue: 0,
            pcontractTotal: 0,
            workerCount: 0,
            totalAdditionalRevenue: 0,
            mTotal: 0,
            wTotal: 0,
            wIncomplete: 0,
            woodTotal: 0,
            metalTotal: 0,
            electricTotal: 0,
            lightingTotal: 0,
            cleaningTotal: 0,
            filmTotal: 0,
            landscapeTotal: 0,
            hardwareTotal: 0,
            paintTotal: 0,
            facilityTotal: 0,
            tileTotal: 0,
            glassTotal: 0,
            fuelTotal: 0,
            accommodationTotal: 0,
            foodTotal: 0,
            personalExpensesTotal: 0,
            firefightingTotal: 0,
            signageTotal: 0,
            airConditioningTotal: 0,
            demolitionTotal: 0,
            customMadeTotal: 0,
            otherExpensesTotal: 0,
          );
        },
      );

      if (mounted) {
        // 디버깅 로그
        debugPrint('\n💰 [재무 데이터 로드]');
        debugPrint('   현장: ${targetPlace.pname} (PID: ${targetPlace.pid})');
        debugPrint('   pfirstrevenue: ${targetPlace.pfirstrevenue}');
        debugPrint('   pcontractTotal: ${targetPlace.pcontractTotal}');
        debugPrint(
            '   totalAdditionalRevenue: ${targetPlace.totalAdditionalRevenue}');
        debugPrint('   wTotal (인건비): ${targetPlace.wTotal}');
        debugPrint('   mTotal (재료비): ${targetPlace.mTotal}');

        setState(() {
          // 공사금액 = pcontractTotal이 있으면 사용, 없으면 pfirstrevenue + 추가금액
          // pcontractTotal이 총 계약 금액일 가능성이 높음
          _placeRevenue = targetPlace.pcontractTotal > 0
              ? targetPlace.pcontractTotal
              : (targetPlace.pfirstrevenue +
                  targetPlace.totalAdditionalRevenue);
          // 총 지출 = 인건비 + 재료비
          _totalExpenses = targetPlace.wTotal + targetPlace.mTotal;
          _loadingFinancialData = false;

          debugPrint('   ✅ 최종 공사금액: $_placeRevenue');
          debugPrint('   ✅ 최종 지출: $_totalExpenses');
        });
      }
    } catch (e) {
      debugPrint('❌ 재무 데이터 로드 실패: $e');
      if (mounted) {
        setState(() => _loadingFinancialData = false);
      }
    }
  }

  int get _dayCount {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  int get _totalAssignments {
    return _dayCount * _selectedHumans.length;
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return '공정 및 기간 선택';
      case 1:
        return '인력 선택';
      case 2:
        return '투입 확인';
      default:
        return '';
    }
  }

  /// 총 인건비 계산
  int _calculateTotalLaborCost() {
    if (_selectedHumans.isEmpty || _dayCount == 0) return 0;

    int total = 0;
    for (final human in _selectedHumans) {
      final wage = _humanWages[human.hid] ?? human.hdailyWage;
      total += wage * _dayCount;
    }
    return total;
  }

  /// 통화 포맷팅 (천 단위 콤마)
  String _formatCurrency(int amount) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return amount
        .toString()
        .replaceAllMapped(formatter, (match) => '${match[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 헤더
          BulkAssignmentSheetHeader(
            placeName: widget.pname,
            onClose: () => Navigator.of(context).pop(),
          ),

          // 진행 단계 표시
          BulkAssignmentStepIndicator(currentStep: _currentStep),
          SizedBox(height: context.rsi(8)),
          // 메인 콘텐츠 + 버튼 (모두 스크롤 가능)
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: EdgeInsets.only(
                left: context.rs(16),
                right: context.rs(16),
                top: context.rs(12),
                bottom: context.rs(12),
              ),
              children: [
                if (_currentStep == 0)
                  _buildStep0ProcessAndDateSelection(context, cs, tt),
                if (_currentStep == 1)
                  _buildStep1SelectWorkers(context, cs, tt),
                if (_currentStep == 2) _buildStep2Confirmation(context),

                // ✅ 버튼을 ListView 내부 마지막에 배치 (키보드가 올라오면 키보드 아래에 숨김)
                if (!isKeyboardVisible) ...[
                  SizedBox(height: context.rsi(16)),
                  _buildBottomButtonsInline(context, cs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 0: 공정 리스트 및 기간 선택
  Widget _buildStep0ProcessAndDateSelection(
      BuildContext context, ColorScheme cs, TextTheme tt) {
    return BulkStep0Section(
      stepTitle: _stepTitle,
      onAddProcess: () => _showAddProcessDialog(context),
      processList: _processTasks.isEmpty
          ? _buildEmptyProcessList(context)
          : _buildProcessList(context, cs, tt),
    );
  }

  /// 공정 리스트
  Widget _buildProcessList(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Column(
      children: _processTasks.asMap().entries.map((entry) {
        final taskIndex = entry.key;
        final task = entry.value;
        final dayIndices = task.scheduledDayIndices;

        if (dayIndices.isEmpty || _gridStart == null) {
          return const SizedBox.shrink();
        }

        final firstIdx = dayIndices.first;
        final lastIdx = dayIndices.last;
        final startDate = _gridStart!.add(Duration(days: firstIdx));
        final endDate = _gridStart!.add(Duration(days: lastIdx));
        final totalDays = lastIdx - firstIdx + 1;

        final status =
            _processAssignmentStatus[processTaskKey(task, taskIndex)];
        final isCompleted = status != null && status.isFullyAssigned;
        final isPartial = status != null && status.isPartiallyAssigned;

        final isSelected = isSameProcessTask(
          _selectedTask,
          _selectedTaskIndex,
          task,
          taskIndex,
        );

        return Padding(
          padding: EdgeInsets.only(bottom: context.rsi(8)),
          child: BulkProcessSelectionCard(
            taskName: task.name,
            dateLabel:
                '${startDate.month}/${startDate.day} ~ ${endDate.month}/${endDate.day} · $totalDays일',
            isSelected: isSelected,
            isCompleted: isCompleted,
            isPartial: isPartial,
            onTap: () => _showDateRangePickerDialog(
              context,
              task,
              taskIndex,
              startDate,
              endDate,
            ),
            statusBar: status != null && !status.hasNoAssignment
                ? _buildAssignmentStatusBar(context, cs, tt, status)
                : null,
          ),
        );
      }).toList(),
    );
  }

  /// 투입 현황 바
  Widget _buildAssignmentStatusBar(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    ProcessAssignmentStatus status,
  ) {
    final percentage = (status.completionRate * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.isFullyAssigned ? '투입 완료' : '투입 진행중',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              '${status.assignedDays}/${status.totalDays}일',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            SizedBox(width: context.rsi(8)),
            Text(
              '${status.totalWorkers}명',
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rsi(6)),
        ClipRRect(
          borderRadius: BorderRadius.circular(context.rs(3)),
          child: LinearProgressIndicator(
            value: status.completionRate.clamp(0.0, 1.0),
            minHeight: context.rs(5),
            backgroundColor: cs.surfaceContainerHighest,
            color: cs.primary.withValues(alpha: 0.75),
          ),
        ),
        SizedBox(height: context.rsi(2)),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$percentage%',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// 빈 공정 리스트
  Widget _buildEmptyProcessList(BuildContext context) {
    return BulkEmptyProcessList(
      onSelectDateDirectly: () => _showDirectDateSelection(context),
    );
  }

  /// 날짜 범위 선택 다이얼로그
  Future<void> _showDateRangePickerDialog(
    BuildContext context,
    ProcessScheduleTask task,
    int taskIndex,
    DateTime processStart,
    DateTime processEnd,
  ) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => DateRangePickerSheet(
        task: task,
        processStart: processStart,
        processEnd: processEnd,
        initialStart: processStart,
        initialEnd: processEnd,
        allProcessEvents: _buildProcessEventData(),
        gridStart: _gridStart,
        onProcessDateModified: (newStart, newEnd) {
          unawaited(
            _syncProcessScheduleForRange(
              newStart,
              newEnd,
              taskOverride: task,
              taskIndexOverride: taskIndex,
            ),
          );
        },
      ),
    );

    if (result != null && result['start'] != null && result['end'] != null) {
      setState(() {
        _selectedTask = task;
        _selectedTaskIndex = taskIndex;
        _startDate = result['start'] as DateTime;
        _endDate = result['end'] as DateTime;
        // 날짜 선택 완료 후 자동으로 Step 1(인력 선택)로 이동
        _currentStep = 1;
      });
      _onWorkPeriodChanged();
    }
  }

  /// 직접 날짜 선택
  Future<void> _showDirectDateSelection(BuildContext context) async {
    final now = DateTime.now();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => DateRangePickerSheet(
        task: null,
        processStart: now,
        processEnd: now.add(const Duration(days: 30)),
        initialStart: now,
        initialEnd: now,
        allProcessEvents: _buildProcessEventData(),
        gridStart: _gridStart,
      ),
    );

    if (result != null && result['start'] != null && result['end'] != null) {
      setState(() {
        _selectedTask = null;
        _startDate = result['start'] as DateTime;
        _endDate = result['end'] as DateTime;
        // 날짜 선택 완료 후 자동으로 Step 1(인력 선택)로 이동
        _currentStep = 1;
      });
      _onWorkPeriodChanged();
    }
  }

  /// 공정 추가 다이얼로그
  Future<void> _showAddProcessDialog(BuildContext context) async {
    final arg = _scheduleArg;
    if (arg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현장 정보가 없어 공정을 추가할 수 없습니다.')),
      );
      return;
    }

    final scheduleState = ref.read(placeProcessScheduleProvider(arg));
    if (!scheduleState.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공정표를 불러온 뒤 다시 시도해 주세요.')),
      );
      return;
    }

    final data = scheduleState.data;
    if (data.dayCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('공정표에 날짜가 없습니다. 공사 기간을 먼저 설정해 주세요.'),
        ),
      );
      return;
    }

    final dates = ProcessScheduleEditor.columnDates(data);
    final dateLabels = [
      for (final d in dates) scheduleDateHeaderLabel(d),
    ];

    final result = await showDialog<AddProcessDialogResult>(
      context: context,
      builder: (ctx) => AddProcessDialog(dateLabels: dateLabels),
    );
    if (result == null || !mounted) return;

    final name = result.name.trim();
    if (name.isEmpty) return;

    final last = data.dayCount - 1;
    final lo = result.startIdx.clamp(0, last);
    var hi = result.endIdx.clamp(0, last);
    if (hi < lo) hi = lo;

    final notifier = ref.read(placeProcessScheduleProvider(arg).notifier);
    notifier.upsertProcess(name, lo, hi);

    try {
      await notifier.persist(syncPlaceMaster: widget.placeInfo);
      if (!mounted) return;

      final refreshed = ref.read(placeProcessScheduleProvider(arg));
      final idx = _findTaskIndexInData(refreshed.data, name: name);

      setState(() {
        _processTasks = List<ProcessScheduleTask>.from(refreshed.data.tasks);
        _gridStart = refreshed.data.gridStart;
        if (idx != null) {
          _selectedTask = refreshed.data.tasks[idx];
          _selectedTaskIndex = idx;
          _applyProcessDateRange(_selectedTask!);
        }
        _scheduleRangeSynced = true;
      });
      _calculateProcessAssignmentStatus();
      _siteInstructionTouchedByUser = false;
      _siteInstructionLoadedForIso = null;
      unawaited(_loadExistingSiteInstruction(force: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공정 "$name"을(를) 반영했습니다.')),
      );
    } catch (e) {
      await notifier.reloadFromServer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PlaceProcessScheduleNotifier.messageForPersistError(e),
          ),
        ),
      );
    }
  }

  Widget _buildStep1SelectWorkers(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return BulkStep1Section(
      stepTitle: _stepTitle,
      isSearching: _searchQuery.isNotEmpty,
      recentWorkerCount: _recentWorkers.length,
      searchHintText: _getSearchHintText(),
      searchQuery: _searchQuery,
      onSearchChanged: _onSearchQueryChanged,
      onClearSearch: _clearSearchQuery,
      onShowSearchFilter: () => _showSearchFilterDialog(context),
      onAddWorker: () => _showAddWorkerDialog(context),
      onShowRecentWorkersFullList: () => _showRecentWorkersFullList(context),
      showRecentWorkersFullList: _recentWorkers.isNotEmpty,
      workersGrid: _buildRecentWorkersGrid(context, cs, tt),
      selectedSummary: _selectedHumans.isNotEmpty
          ? _buildSelectedWorkersSummaryCard(context, cs, tt)
          : null,
    );
  }

  Widget _buildSelectedWorkersSummaryCard(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Container(
      padding: EdgeInsets.all(context.rsi(12)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(context.rs(10)),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '선택 ${_selectedHumans.length}명 · $_dayCount일',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${_formatCurrency(_calculateTotalLaborCost())}원',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rsi(4)),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '예상 인건비',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  /// 검색 힌트 텍스트
  String _getSearchHintText() {
    return _searchType.hintText;
  }

  void _resetSearchOnTypeChange(WorkerSearchType type) {
    setState(() {
      _searchType = type;
      _searchQuery = '';
      _searchResults = [];
      _searchLoading = false;
    });
  }

  /// 검색 필터 선택 다이얼로그
  Future<void> _showSearchFilterDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('검색 방식 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<WorkerSearchType>(
              title: Text(WorkerSearchType.name.label),
              value: WorkerSearchType.name,
              groupValue: _searchType,
              onChanged: (value) {
                _resetSearchOnTypeChange(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<WorkerSearchType>(
              title: Text(WorkerSearchType.chosung.label),
              subtitle: const Text('예: ㄱㅎㅅ → 김형수'),
              value: WorkerSearchType.chosung,
              groupValue: _searchType,
              onChanged: (value) {
                _resetSearchOnTypeChange(value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<WorkerSearchType>(
              title: Text(WorkerSearchType.specialty.label),
              value: WorkerSearchType.specialty,
              groupValue: _searchType,
              onChanged: (value) {
                _resetSearchOnTypeChange(value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 한글을 초성으로 변환
  String _getChosung(String text) {
    const chosungs = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ'
    ];

    final result = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0xAC00 && code <= 0xD7A3) {
        // 한글 유니코드 범위
        final chosungIndex = ((code - 0xAC00) / 28 / 21).floor();
        result.write(chosungs[chosungIndex]);
      } else {
        result.write(text[i]);
      }
    }
    return result.toString();
  }

  /// 최근 작업자 그리드
  Widget _buildRecentWorkersGrid(
      BuildContext context, ColorScheme cs, TextTheme tt) {
    final isSearching = _searchQuery.trim().isNotEmpty;

    if (_loadingRecentWorkers || (isSearching && _searchLoading)) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: context.rs(200)),
        child: Center(
          child: Padding(
            padding: ResponsiveLayout.all(context, 40),
            child: const HammerLoadingIndicator(size: 28),
          ),
        ),
      );
    }

    if (!isSearching && _recentWorkers.isEmpty) {
      return const BulkWorkerSearchEmptyState(
        icon: Icons.people_outline,
        title: '최근 작업 이력이 없습니다',
        subtitle: '검색하거나 인원 추가로 등록해 보세요.',
      );
    }

    final displayWorkers = isSearching ? _searchResults : _recentWorkers;

    if (displayWorkers.isEmpty) {
      return const BulkWorkerSearchEmptyState(
        icon: Icons.search_off,
        title: '검색 결과가 없습니다',
        subtitle: '다른 검색어를 입력해 보세요.',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // ✅ 3 → 4로 변경
        mainAxisSpacing: context.rsi(8), // ✅ 10 → 8로 축소
        crossAxisSpacing: context.rsi(8), // ✅ 10 → 8로 축소
        childAspectRatio: 0.75, // ✅ 0.85 → 0.75로 조정 (약간 더 세로로 길게)
      ),
      itemCount: displayWorkers.length,
      itemBuilder: (context, index) {
        final human = displayWorkers[index];
        final isSelected = _selectedHumans.any((h) => h.hid == human.hid);
        final workrole = _humanWorkRoles[human.hid] ??
            _selectedTask?.name ??
            human.hdefaultRole;
        final wage = _humanWages[human.hid] ?? human.hdailyWage;

        return BulkWorkerGridItem(
          name: human.hname,
          isSelected: isSelected,
          blockedLabel: humanCanBeAssignedToWork(
            human,
            blockedMemberUids: _blockedMemberUids,
          )
              ? null
              : (humanWorkAssignBlockMessage(
                  human,
                  blockedMemberUids: _blockedMemberUids,
                ).contains('정지')
                  ? '정지'
                  : '불가'),
          workRole: isSelected ? workrole : null,
          wageLabel:
              isSelected ? '${(wage / 10000).toStringAsFixed(0)}만원' : null,
          primarySpecialty: isSelected ? null : human.displayPrimarySpecialty,
          onTap: () => _toggleWorkerSelection(human, isSelected),
          onLongPress: () => _showWorkerIdentifySheet(
            context,
            human,
            isSelected: isSelected,
            allowRemoveFromRecent: !isSearching,
          ),
        );
      },
    );
  }

  void _toggleWorkerSelection(HumanModel human, bool isSelected) {
    if (!isSelected &&
        !humanCanBeAssignedToWork(
          human,
          blockedMemberUids: _blockedMemberUids,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanWorkAssignBlockMessage(
              human,
              blockedMemberUids: _blockedMemberUids,
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      if (isSelected) {
        _selectedHumans.removeWhere((h) => h.hid == human.hid);
        _humanWorkRoles.remove(human.hid);
        _humanWages.remove(human.hid);
        return;
      }

      _selectedHumans.add(human);
      if (!_humanWorkRoles.containsKey(human.hid)) {
        _humanWorkRoles[human.hid!] = _selectedTask?.name ?? human.hdefaultRole;
      }
      if (!_humanWages.containsKey(human.hid)) {
        _humanWages[human.hid!] = human.hdailyWage;
      }
    });
  }

  /// 인력 구분용 미리보기 (동명이인 등)
  Future<void> _showWorkerIdentifySheet(
    BuildContext context,
    HumanModel human, {
    required bool isSelected,
    bool allowRemoveFromRecent = false,
  }) async {
    await showWorkforceWorkerIdentifySheet(
      context: context,
      human: human,
      onEditAssignment: isSelected ? () => _editWorkerDetails(human) : null,
      onRemoveFromRecent:
          allowRemoveFromRecent ? () => _removeRecentWorker(human) : null,
    );
  }

  /// 인력 상세 정보 수정
  Future<void> _editWorkerDetails(HumanModel human) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => WorkerDetailsSheet(
        human: human,
        currentRole: _humanWorkRoles[human.hid] ?? human.hdefaultRole,
        currentWage: _humanWages[human.hid] ?? human.hdailyWage,
        onSave: (role, wage) {
          setState(() {
            _humanWorkRoles[human.hid!] = role;
            _humanWages[human.hid!] = wage;
          });
        },
      ),
    );
  }

  Widget _buildStep2Confirmation(BuildContext context) {
    final selectedWorkerDetails = _selectedHumans
        .map(
          (human) => BulkSelectedWorkerDetail(
            human: human,
            workRole: _humanWorkRoles[human.hid] ??
                _selectedTask?.name ??
                human.hdefaultRole,
            wage: _humanWages[human.hid] ?? human.hdailyWage,
          ),
        )
        .toList();

    return BulkStep2Section(
      stepTitle: _stepTitle,
      financialSummary: BulkAssignmentFinancialSummary(
        loadingFinancialData: _loadingFinancialData,
        placeRevenue: _placeRevenue,
        totalExpenses: _totalExpenses,
        selectedLaborCost: _calculateTotalLaborCost(),
        formatCurrency: _formatCurrency,
      ),
      assignmentSummary: BulkAssignmentSummaryCard(
        dayCount: _dayCount,
        workerCount: _selectedHumans.length,
        totalAssignments: _totalAssignments,
        periodLabel:
            '${_startDate!.month}/${_startDate!.day} ~ ${_endDate!.month}/${_endDate!.day} ($_dayCount일)',
      ),
      workerDetails: BulkSelectedWorkersDetailCard(
        workers: selectedWorkerDetails,
        dayCount: _dayCount,
      ),
      // TODO(작업지시탭 이관): 일괄 투입 작업지시 섹션 — 삭제 예정
      // workInstruction: _buildWorkInstructionSection(context),
      workInstruction: const SizedBox.shrink(),
      saveError: _saveError,
    );
  }

  /// 전체 작업지시 섹션 (토글 가능)
  Widget _buildWorkInstructionSection(BuildContext context) {
    final hasInstruction = _globalWorkInstructionBlocks.isNotEmpty &&
        !workInstructionBlocksLookEmpty(_globalWorkInstructionBlocks);

    return BulkWorkInstructionSection(
      hasInstruction: hasInstruction,
      expanded: _workInstructionExpanded,
      onToggle: () =>
          setState(() => _workInstructionExpanded = !_workInstructionExpanded),
      onEdit: () => _editWorkInstruction(context),
      onClear: () => setState(() {
        _globalWorkInstructionBlocks = [];
        _siteInstructionTouchedByUser = true;
      }),
    );
  }

  /// 작업지시 편집
  Future<void> _editWorkInstruction(BuildContext context) async {
    final result = await showPlaceWorkInstructionEditorSheet(
      context: context,
      pid: widget.pid,
      placeName: widget.pname ?? '현장',
      workerLabel: '전체 인력',
      initialBlocks: _globalWorkInstructionBlocks,
      sheetTitle: '전체 작업지시',
    );

    if (result != null) {
      setState(() {
        _globalWorkInstructionBlocks = result;
        _siteInstructionTouchedByUser = true;
      });
    }
  }

  /// ListView 내부용 버튼
  Widget _buildBottomButtonsInline(BuildContext context, ColorScheme cs) {
    // Step 0에서는 버튼 숨김 (공정 리스트만 표시)
    if (_currentStep == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: context.rsi(8)),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() => _currentStep--);
                        if (_currentStep == 0) {
                          _calculateProcessAssignmentStatus();
                        }
                      },
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(context.rs(44)),
                ),
                child: const Text('이전'),
              ),
            ),
            SizedBox(width: context.rsi(10)),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _canProceed() ? _handleNext : null,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(context.rs(44)),
              ),
              child: _saving
                  ? SizedBox(
                      width: context.rs(18),
                      height: context.rs(18),
                      child: const HammerLoadingIndicator(size: 24),
                    )
                  : Text(_currentStep == 2 ? '투입 완료' : '다음'),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    return canProceedBulkAssignmentStep(
      saving: _saving,
      currentStep: _currentStep,
      startDate: _startDate,
      endDate: _endDate,
      dayCount: _dayCount,
      selectedWorkerCount: _selectedHumans.length,
    );
  }

  Future<void> _handleNext() async {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      // 최종 저장
      await _saveAssignments();
    }
  }

  String? _validateBeforeSave() {
    if (_startDate == null || _endDate == null || _selectedHumans.isEmpty) {
      return '투입 기간과 인력을 확인해 주세요.';
    }

    final blocked = blockedWorkersForBulkAssignment(
      _selectedHumans,
      blockedMemberUids: _blockedMemberUids,
    );
    if (blocked.isEmpty) return null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${blocked.first.hname} — ${humanWorkAssignBlockMessage(blocked.first, blockedMemberUids: _blockedMemberUids)}',
          ),
        ),
      );
      setState(() {
        _selectedHumans = _assignableWorkers(_selectedHumans);
      });
    }
    return '선택 인력 중 배정 불가 인력이 있습니다.';
  }

  Future<List<Map<String, dynamic>>?> _prepareSiteInstructionBlocks() async {
    return prepareBulkSiteInstructionBlocks(
      context: context,
      mounted: mounted,
      touchedByUser: _siteInstructionTouchedByUser,
      globalWorkInstructionBlocks: _globalWorkInstructionBlocks,
    );
  }

  BulkWorkforceAssignmentRequest _buildBulkAssignmentRequest(
    List<Map<String, dynamic>>? siteInstructionBlocks,
  ) {
    return buildBulkWorkforceAssignmentRequest(
      startDate: _startDate!,
      endDate: _endDate!,
      selectedHumans: _selectedHumans,
      humanWorkRoles: _humanWorkRoles,
      humanWages: _humanWages,
      fallbackWorkRole: _selectedTask?.name,
      siteInstructionBlocks: siteInstructionBlocks,
    );
  }

  Future<void> _syncAfterBulkSave(
      BulkWorkforceAssignmentResponse response) async {
    await runBulkAssignmentPostSaveSync(
      response: response,
      pid: widget.pid,
      startDate: _startDate,
      selectedHumans: _selectedHumans,
      inviteAssignedWorkers: (pid, workers) async {
        await ref
            .read(placeMembersUseCaseProvider)
            .inviteAssignedWorkersToPlace(pid, workers);
      },
      ensureWorkCostForWorkDay: (wd) async {
        final workCostUseCase = ref.read(workCostUseCaseProvider);
        await workCostUseCase.ensureWorkCostForPlaceWorkDay(
          pid: wd.pid,
          hid: wd.hid,
          dateKey: wd.workdate,
          wprice: wd.dailywage,
          wrole: wd.workrole,
        );
      },
      notifyWorkCostChanged: (pid, date) async {
        await FetchData.onDataChanged(
          DataChangeEvent(
            DataChangeKind.workCost,
            pid: pid,
            date: date,
          ),
          background: false,
        );
      },
      reloadWorkforce: () async {
        await ref.read(placeWorkforceProvider(widget.pid).notifier).reload(
              silent: true,
            );
      },
      reloadProcessSchedule: () async {
        final scheduleArg = _scheduleArg;
        if (scheduleArg == null) return;
        await ref
            .read(placeProcessScheduleProvider(scheduleArg).notifier)
            .reloadFromServer();
      },
    );
  }

  void _beginSavingState() {
    setState(() {
      _saving = true;
      _saveError = '';
    });
  }

  void _finishSavingStateIfMounted() {
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  void _logSaveStart() {
    debugPrint('\n🚀 [일괄 투입] 저장 시작');
    debugPrint('   - 기간: $_startDate ~ $_endDate ($_dayCount일)');
    debugPrint('   - 인력: ${_selectedHumans.length}명');
    debugPrint('   - 총 품수: $_totalAssignments품');
  }

  void _handleSaveSuccess(BulkWorkforceAssignmentResponse response) {
    debugPrint('✅ [일괄 투입] 저장 완료');
    debugPrint('   - 생성된 항목: ${response.createdCount}건');
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${response.createdCount}건의 작업이 생성되었습니다'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    Navigator.of(context).pop(true);
  }

  void _handleSaveFailure(Object e, StackTrace stack) {
    debugPrint('❌ [일괄 투입] 저장 실패: $e');
    debugPrint('Stack: $stack');
    setState(() {
      _saveError = '저장 중 오류가 발생했습니다: ${e.toString()}';
    });
  }

  Future<void> _saveAssignments() async {
    final validationError = _validateBeforeSave();
    if (validationError != null) {
      return;
    }

    _beginSavingState();

    try {
      if (!_scheduleRangeSynced) {
        await _syncProcessScheduleForRange(_startDate!, _endDate!);
      }

      _logSaveStart();

      final siteInstructionBlocks = await _prepareSiteInstructionBlocks();
      final request = _buildBulkAssignmentRequest(siteInstructionBlocks);

      final placeUseCase = ref.read(placeUseCaseProvider);
      final result = await placeUseCase.bulkAssignWorkforce(
        pid: widget.pid,
        requestBody: request.toJson(),
      );

      final response = BulkWorkforceAssignmentResponse.fromJson(result);
      await _syncAfterBulkSave(response);
      _handleSaveSuccess(response);
    } catch (e, stack) {
      _handleSaveFailure(e, stack);
    } finally {
      _finishSavingStateIfMounted();
    }
  }
}

/// 날짜 범위 선택 바텀시트
