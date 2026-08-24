import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/local/work_instruction_recent_storage.dart';
import 'package:w0001/data/model/bulk_workforce_assignment.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/data/model/worker_announcement_models.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/domain/place_work_day_cross_place_conflict.dart';
import 'package:w0001/domain/process_schedule/process_schedule_models.dart';
import 'package:w0001/navigation/shell_back_navigation.dart';
import 'package:w0001/presentation/viewmodel/place_detail_view_model.dart'
    show workCostUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/place_members_providers.dart';
import 'package:w0001/presentation/viewmodel/place_workforce_notifier.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/ui/screen/5_place/widgets/cross_place_workday_conflict_dialog.dart';
import 'package:w0001/ui/screen/5_place/widgets/place_work_instruction_editor_sheet.dart';
import 'package:w0001/ui/screen/5_place/workforce_bulk_assignment/assignment_logic.dart';
import 'package:w0001/ui/screen/5_place/workforce_bulk_assignment/post_save_sync.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_quill_codec.dart';
import 'package:w0001/ui/screen/announcements/worker_announcement_rich_quill.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/image_upload_progress_dialog.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/funtions.dart';
import 'package:w0001/util/image_attachment/image_upload_result.dart';
import 'package:w0001/util/responsive_layout.dart';
import 'package:w0001/util/worker_skills_display.dart';

class WorkInstructionAssignResult {
  const WorkInstructionAssignResult({
    required this.workers,
    required this.workDate,
    this.endDate,
    this.taskName,
  });

  final List<HumanModel> workers;
  final DateTime workDate;
  final DateTime? endDate;
  final String? taskName;
}

Future<WorkInstructionAssignResult?> showWorkInstructionComposePage({
  required BuildContext context,
  required PlaceInfoModel place,
  required DateTime startDate,
  required DateTime endDate,
  ProcessScheduleTask? task,
  List<HumanModel> workers = const [],
  List<HumanModel> sitePeople = const [],
  List<PlaceWorkDayRead> allWorkRows = const [],
  Set<String> blockedMemberUids = const {},
  bool instructionOnly = false,
  bool scopeSite = true,
}) {
  return Navigator.of(context, rootNavigator: true)
      .push<WorkInstructionAssignResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => _WorkInstructionComposePage(
        place: place,
        startDate: DateTime(startDate.year, startDate.month, startDate.day),
        endDate: DateTime(endDate.year, endDate.month, endDate.day),
        task: task,
        workers: workers,
        sitePeople: sitePeople,
        allWorkRows: allWorkRows,
        blockedMemberUids: blockedMemberUids,
        instructionOnly: instructionOnly,
        scopeSite: scopeSite,
      ),
    ),
  );
}

class _WorkInstructionComposePage extends ConsumerStatefulWidget {
  const _WorkInstructionComposePage({
    required this.place,
    required this.startDate,
    required this.endDate,
    this.task,
    this.workers = const [],
    this.sitePeople = const [],
    this.allWorkRows = const [],
    this.blockedMemberUids = const {},
    this.instructionOnly = false,
    this.scopeSite = true,
  });

  final PlaceInfoModel place;
  final DateTime startDate;
  final DateTime endDate;
  final ProcessScheduleTask? task;
  final List<HumanModel> workers;
  final List<HumanModel> sitePeople;
  final List<PlaceWorkDayRead> allWorkRows;
  final Set<String> blockedMemberUids;
  final bool instructionOnly;
  final bool scopeSite;

  @override
  ConsumerState<_WorkInstructionComposePage> createState() =>
      _WorkInstructionComposePageState();
}

class _WorkInstructionComposePageState
    extends ConsumerState<_WorkInstructionComposePage> {
  final _editorFocus = FocusNode();
  final _quillScroll = ScrollController();
  final _recentStore = WorkInstructionRecentStorage();
  final _picker = WorkerAnnouncementRichQuill.picker();

  late QuillController _quillCtrl;
  late final QuillSimpleToolbarConfig _toolbarConfig;
  var _saving = false;
  var _uploading = false;
  var _loading = true;
  List<PlaceWorkDayRead> _allWorkRows = const [];
  final _people = <int, HumanModel>{};

  int get _pid => widget.place.pid ?? 0;

  String get _workrole => widget.task?.name.trim() ?? '';

  List<DateTime> get _workDates {
    final out = <DateTime>[];
    var d = widget.startDate;
    while (!d.isAfter(widget.endDate)) {
      out.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return out;
  }

  String get _dateLabel =>
      formatMonthDayRange(widget.startDate, widget.endDate);

  @override
  void initState() {
    super.initState();
    for (final h in [...widget.sitePeople, ...widget.workers]) {
      final hid = h.hid;
      if (hid == null || hid <= 0) continue;
      _people[hid] = h;
    }
    _allWorkRows = widget.allWorkRows;
    _quillCtrl = WorkerAnnouncementQuillCodec.createEditingController(
      document: Document(),
    );
    _toolbarConfig = WorkerAnnouncementRichQuill.toolbarConfig(
      onRequestPickImage: _onPickImages,
      afterToolbarButtonPressed: _editorFocus.requestFocus,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadExisting());
    });
  }

  @override
  void dispose() {
    _quillCtrl.dispose();
    _editorFocus.dispose();
    _quillScroll.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      var rows = _allWorkRows;
      if (rows.isEmpty) {
        rows =
            await ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
      }
      final dayKey = formatDateTimeToIsoDate(widget.startDate);
      List<WorkerAnnouncementBlock> existing = const [];
      for (final r in rows) {
        if (r.pid != _pid || normalizePlaceWorkDateKey(r.workdate) != dayKey) {
          continue;
        }
        if (_workrole.isNotEmpty &&
            r.workrole.trim() == _workrole &&
            r.processInstructionBlocks.isNotEmpty) {
          existing = r.processInstructionBlocks;
          break;
        }
        if (r.siteInstructionBlocks.isNotEmpty) {
          existing = r.siteInstructionBlocks;
        }
      }
      if (!mounted) return;
      if (existing.isNotEmpty) {
        final nextDoc = WorkerAnnouncementQuillCodec.decodeToDocument(existing);
        final old = _quillCtrl;
        _quillCtrl = WorkerAnnouncementQuillCodec.createEditingController(
          document: nextDoc,
        );
        old.dispose();
      }
      setState(() {
        _allWorkRows = rows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _onPickImages(BuildContext context) {
    return WorkerAnnouncementRichQuill.galleryPickWorkflow(
      context: context,
      controller: _quillCtrl,
      picker: _picker,
      mounted: () => mounted,
      uploadingGuard: _uploading,
      setUploading: (v) {
        if (mounted) setState(() => _uploading = v);
      },
    );
  }

  void _insertMention(HumanModel h) {
    final t = '${h.hname}님';
    final offset = WorkerAnnouncementRichQuill.safeInsertOffset(_quillCtrl);
    _quillCtrl.replaceText(
      offset,
      0,
      '$t ',
      TextSelection.collapsed(offset: offset + t.length + 1),
    );
    _editorFocus.requestFocus();
  }

  String _chipLabel(HumanModel h) {
    final skill = humanListPrimarySpecialtyLabel(h);
    if (skill != null && skill.isNotEmpty) return '[$skill]${h.hname}';
    return h.hname;
  }

  Future<List<Map<String, dynamic>>?> _instructionBlocks() async {
    if (WorkerAnnouncementQuillCodec.deltaLooksEmpty(_quillCtrl.document)) {
      return null;
    }
    var doc = _quillCtrl.document;
    if (WorkerAnnouncementQuillCodec.documentHasLocalImages(doc)) {
      if (!mounted) return null;
      doc = await runWithImageUploadProgressDialog<Document>(
        context: context,
        body: (setMessage) async {
          return WorkerAnnouncementQuillCodec.uploadLocalImagesInDocument(
            doc,
            category: ImageUploadCategory.placeImage,
            onProgress: (current, total) {
              setMessage('이미지 업로드 중… ($current/$total)');
            },
          );
        },
      );
    }
    final encoded = WorkerAnnouncementQuillCodec.blocksForApi(doc);
    if (workInstructionBlocksLookEmpty(encoded)) return null;
    final plain = doc.toPlainText().trim();
    if (plain.isNotEmpty) unawaited(_recentStore.remember(plain));
    return encoded.map((b) => b.toJson()).toList();
  }

  List<CrossPlaceWorkDayConflict> _conflictsFor(Iterable<int> hids) {
    final places = {
      for (final p in ref.read(placeListProvider).placeList)
        if (p.pid != null) p.pid!: p.pname,
    };
    final names = <int, String>{
      for (final h in [..._people.values, ...widget.workers])
        if (h.hid != null) h.hid!: h.hname,
    };
    final out = <CrossPlaceWorkDayConflict>[];
    final seen = <String>{};
    for (final day in _workDates) {
      final found = findCrossPlaceWorkDayConflicts(
        allRows: _allWorkRows,
        targetPid: _pid,
        workdateIso: formatDateTimeToIsoDate(day),
        hids: hids,
        placeNameByPid: places,
        humanNameByHid: names,
      );
      for (final c in found) {
        final key = '${formatDateTimeToIsoDate(day)}-${c.hid}';
        if (seen.add(key)) out.add(c);
      }
    }
    return out;
  }

  Future<void> _save() async {
    if (_saving) return;
    final workers = [
      for (final h in widget.workers)
        if (h.hid != null && h.hid! > 0) h,
    ];
    if (!widget.instructionOnly && workers.isEmpty) return;

    if (workers.isNotEmpty) {
      final conflicts = _conflictsFor([
        for (final h in workers)
          if (h.hid != null) h.hid!,
      ]);
      if (conflicts.isNotEmpty) {
        final choice = await showCrossPlaceWorkDayConflictDialog(
          context,
          workdateLabel: _dateLabel,
          currentPlaceName: widget.place.pname,
          conflicts: conflicts,
        );
        if (choice != CrossPlaceConflictChoice.proceedAll || !mounted) return;
      }
    }

    setState(() => _saving = true);
    try {
      final blocks = await _instructionBlocks();
      if (!mounted) return;
      final useProcess = !widget.scopeSite && _workrole.isNotEmpty;

      if (workers.isNotEmpty && !widget.instructionOnly) {
        final roles = <int, String>{
          for (final h in workers)
            if (h.hid != null)
              h.hid!: _workrole.isNotEmpty
                  ? _workrole
                  : (h.effectiveDefaultWorkRole.isNotEmpty
                      ? h.effectiveDefaultWorkRole
                      : '투입'),
        };
        final wages = <int, int>{
          for (final h in workers)
            if (h.hid != null) h.hid!: h.hdailyWage,
        };
        final request = buildBulkWorkforceAssignmentRequest(
          startDate: widget.startDate,
          endDate: widget.endDate,
          selectedHumans: workers,
          humanWorkRoles: roles,
          humanWages: wages,
          fallbackWorkRole: _workrole,
          siteInstructionBlocks: useProcess ? null : blocks,
          processInstructionBlocks:
              useProcess && blocks != null ? {_workrole: blocks} : null,
        );
        final raw = await ref.read(placeUseCaseProvider).bulkAssignWorkforce(
              pid: _pid,
              requestBody: request.toJson(),
            );
        final response = BulkWorkforceAssignmentResponse.fromJson(raw);
        await runBulkAssignmentPostSaveSync(
          response: response,
          pid: _pid,
          startDate: widget.startDate,
          selectedHumans: workers,
          inviteAssignedWorkers: (pid, list) async {
            await ref
                .read(placeMembersUseCaseProvider)
                .inviteAssignedWorkersToPlace(pid, list);
          },
          ensureWorkCostForWorkDay: (wd) async {
            await ref
                .read(workCostUseCaseProvider)
                .ensureWorkCostForPlaceWorkDay(
                  pid: wd.pid,
                  hid: wd.hid,
                  dateKey: wd.workdate,
                  wprice: wd.dailywage,
                  wrole: wd.workrole,
                );
          },
          notifyWorkCostChanged: (pid, date) async {
            await FetchData.onDataChanged(
              DataChangeEvent(DataChangeKind.workCost, pid: pid, date: date),
              background: false,
            );
          },
          reloadWorkforce: () => ref
              .read(placeWorkforceProvider(_pid).notifier)
              .reload(silent: true),
          reloadProcessSchedule: () async {},
        );
      } else if (blocks != null) {
        final parsed = WorkerAnnouncementQuillCodec.decodeToDocument(
          [
            for (final m in blocks) WorkerAnnouncementBlock.fromJson(m),
          ],
        );
        final apiBlocks = WorkerAnnouncementQuillCodec.blocksForApi(parsed);
        final uc = ref.read(superAdminRemoteUseCaseProvider);
        for (final day in _workDates) {
          final dateKey = formatDateTimeToIsoDate(day);
          if (useProcess) {
            await uc.placeWorkDayProcessInstructionUpsert(
              pid: _pid,
              workdate: dateKey,
              workrole: _workrole,
              blocks: apiBlocks,
            );
          } else {
            await uc.placeWorkDaySiteInstructionUpsert(
              pid: _pid,
              workdate: dateKey,
              blocks: apiBlocks,
            );
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        WorkInstructionAssignResult(
          workers: workers,
          workDate: widget.startDate,
          endDate: widget.endDate == widget.startDate ? null : widget.endDate,
          taskName: widget.task?.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = kb > 0;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final toolbarH = context.rs(52) + (_uploading ? context.rsi(28) : 0);
    final chips = _people.values.toList()
      ..sort((a, b) => a.hname.compareTo(b.hname));

    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!Navigator.of(context).canPop()) return false;
        consumeDedupedBackEvent();
        Navigator.of(context).pop();
        return true;
      },
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (!Navigator.of(context).canPop()) return;
          consumeDedupedBackEvent();
          Navigator.of(context).pop();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: keyboardOpen
              ? null
              : AppBar(
                  titleSpacing: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: '이전',
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '작업지시',
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [
                          if (_workrole.isNotEmpty) _workrole,
                          _dateLabel,
                        ].join('  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: EdgeInsets.only(right: context.rsi(8)),
                      child: FilledButton(
                        onPressed: _saving || _uploading ? null : _save,
                        child: Text(
                          _saving
                              ? '저장 중'
                              : (widget.instructionOnly ? '저장' : '투입 완료'),
                        ),
                      ),
                    ),
                  ],
                ),
          body: SafeArea(
            top: keyboardOpen,
            bottom: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (chips.isNotEmpty)
                      Material(
                        color: cs.surface,
                        elevation: keyboardOpen ? 1 : 0,
                        child: SizedBox(
                          height: context.rs(48),
                          child: ListView.separated(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rsi(12),
                              vertical: context.rsi(6),
                            ),
                            scrollDirection: Axis.horizontal,
                            itemCount: chips.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(width: context.rsi(6)),
                            itemBuilder: (context, i) {
                              final h = chips[i];
                              return ActionChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(_chipLabel(h)),
                                onPressed: () => _insertMention(h),
                              );
                            },
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: context.rsi(12),
                          right: context.rsi(12),
                          top: context.rsi(8),
                          bottom: toolbarH + (keyboardOpen ? kb : 0),
                        ),
                        child: _loading
                            ? const Center(
                                child: HammerLoadingIndicator(size: 56))
                            : WorkerAnnouncementRichQuillDocumentEditor(
                                controller: _quillCtrl,
                                focusNode: _editorFocus,
                                scrollController: _quillScroll,
                                placeholder: '작업 내용을 입력하세요',
                                decorated: true,
                                fillParentHeight: true,
                                scrollable: true,
                                padding: EdgeInsets.fromLTRB(
                                  context.rsi(12),
                                  context.rsi(16),
                                  context.rsi(12),
                                  context.rsi(24),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: kb,
                  child: SafeArea(
                    top: false,
                    bottom: !keyboardOpen,
                    child: Material(
                      elevation: 6,
                      shadowColor: cs.shadow.withValues(alpha: 0.12),
                      color: cs.surface,
                      child: WorkerAnnouncementRichQuillToolbar(
                        controller: _quillCtrl,
                        variant: WorkerAnnouncementRichQuillToolbarVariant
                            .bottomSheetBar,
                        toolbarConfig: _toolbarConfig,
                        uploading: _uploading,
                      ),
                    ),
                  ),
                ),
                if (_uploading)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(context.rsi(20)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const HammerLoadingIndicator(size: 28),
                              SizedBox(height: context.rsi(12)),
                              Text(
                                '이미지 처리 중…',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
