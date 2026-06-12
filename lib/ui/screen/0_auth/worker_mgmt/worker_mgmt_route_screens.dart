import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/util/worker_skills_display.dart';
import 'package:w0001/domain/use_case/super_admin_remote_use_case.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_mgmt_view_model.dart';
import 'package:w0001/ui/screen/0_auth/worker_mgmt/worker_mgmt_hid_content.dart';
import 'package:w0001/theme/app_segmented_button.dart';
import 'package:w0001/util/worker_mgmt_messages.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 인력 목록에서 작업자 hid를 고른 뒤 메모·평가 화면으로 이동하는 허브.
class WorkerMgmtMemosHubScreen extends ConsumerStatefulWidget {
  const WorkerMgmtMemosHubScreen({super.key});

  @override
  ConsumerState<WorkerMgmtMemosHubScreen> createState() =>
      _WorkerMgmtMemosHubScreenState();
}

class _WorkerMgmtMemosHubScreenState
    extends ConsumerState<WorkerMgmtMemosHubScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reloadHumans() => ref
      .read(workerMgmtHumanDirectoryProvider.notifier)
      .reload(blocking: false);

  HumanModel _humanModel(HumanRead h) => HumanModel(
        hid: h.hid,
        hname: h.hname,
        hnumber: h.hnumber,
        hmemo: h.hmemo,
        hdailyWage: h.hdailywage,
        hdefaultRole: h.hdefaultrole,
        primarySpecialty: h.primarySpecialty,
        specialties: h.specialties,
        hstar: h.hstar,
        hdelete: h.hdelete,
      );

  String _avatarLetter(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final it = t.runes.iterator;
    return it.moveNext() ? String.fromCharCode(it.current) : '?';
  }

  @override
  Widget build(BuildContext context) {
    final dir = ref.watch(workerMgmtHumanDirectoryProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sortedHumans = dir.humans.where((h) => h.hdelete == 0).toList()
      ..sort((a, b) => a.hname.compareTo(b.hname));
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? sortedHumans
        : sortedHumans
            .where(
              (h) =>
                  h.hname.toLowerCase().contains(q) ||
                  h.hnumber.toLowerCase().contains(q),
            )
            .toList();

    final blockingLoading =
        dir.initialLoading && dir.humans.isEmpty && dir.error == null;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        centerTitle: false,
        title: const Text('작업자 평가/메모'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(20),
              context.rsi(8),
              context.rsi(20),
              context.rsi(12),
            ),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: cs.onSurfaceVariant,
                ),
                hintText: '이름 또는 주민번호로 검색',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.rsi(18),
                  vertical: context.rsi(14),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: blockingLoading
                ? Skeletonizer(
                    enabled: true,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(20),
                        context.rsi(4),
                        context.rsi(20),
                        context.rsi(28),
                      ),
                      itemCount: 7,
                      itemBuilder: (context, i) => Padding(
                        padding: EdgeInsets.only(bottom: context.rsi(12)),
                        child: Material(
                          color: cs.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.55),
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              foregroundColor: cs.onPrimaryContainer,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text('작업자 이름 ${i + 1}'),
                            subtitle: const Text('메모·평가 요약'),
                          ),
                        ),
                      ),
                    ),
                  )
                : dir.error != null && sortedHumans.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(context.rsi(28)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                size: context.rs(44),
                                color: cs.outline,
                              ),
                              SizedBox(height: context.rsi(12)),
                              Text(
                                workerMgmtUserMessage(dir.error!),
                                textAlign: TextAlign.center,
                                style: tt.bodyMedium,
                              ),
                              SizedBox(height: context.rsi(16)),
                              FilledButton.tonalIcon(
                                onPressed:
                                    dir.refreshing ? null : _reloadHumans,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _reloadHumans,
                        color: cs.primary,
                        child: filtered.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.sizeOf(context).height *
                                        0.25,
                                  ),
                                  Icon(
                                    Icons.people_outline_rounded,
                                    size: context.rs(48),
                                    color: cs.outline,
                                  ),
                                  SizedBox(height: context.rsi(12)),
                                  Center(
                                    child: Text(
                                      '조건에 맞는 인력이 없습니다.',
                                      style: tt.bodyLarge?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  context.rsi(20),
                                  context.rsi(4),
                                  context.rsi(20),
                                  context.rsi(28),
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final h = filtered[i];
                                  return Padding(
                                    padding:
                                        EdgeInsets.only(bottom: context.rsi(12)),
                                    child: Material(
                                      color: cs.surface,
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      surfaceTintColor: cs.surfaceTint,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        side: BorderSide(
                                          color: cs.outlineVariant
                                              .withValues(alpha: 0.55),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (ctx) =>
                                                  WorkerMgmtWorkerDetailScreen(
                                                workerHid: h.hid,
                                                initialName: h.hname,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: context.rsi(16),
                                            vertical: context.rsi(14),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: context.rs(24),
                                                backgroundColor:
                                                    cs.primaryContainer,
                                                foregroundColor:
                                                    cs.onPrimaryContainer,
                                                child: Text(
                                                  _avatarLetter(h.hname),
                                                  style:
                                                      tt.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: context.rsi(14)),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      h.hname,
                                                      style: tt.titleSmall
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        height: context.rsi(8)),
                                                    HumanSkillsChipRow(
                                                      human: _humanModel(h),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: context.rs(16),
                                                color: cs.outline,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// 단일 작업자 hid에 대한 메모·트러블 편집 (전체 화면).
class WorkerMgmtWorkerDetailScreen extends ConsumerStatefulWidget {
  const WorkerMgmtWorkerDetailScreen({
    super.key,
    required this.workerHid,
    this.initialName = '',
  });

  final int workerHid;
  final String initialName;

  @override
  ConsumerState<WorkerMgmtWorkerDetailScreen> createState() =>
      _WorkerMgmtWorkerDetailScreenState();
}

class _WorkerMgmtWorkerDetailScreenState
    extends ConsumerState<WorkerMgmtWorkerDetailScreen> {
  Future<void> _refreshAll() async {
    await ref
        .read(workerMgmtHumanDirectoryProvider.notifier)
        .reload(blocking: false);
    await ref
        .read(workerMgmtHidVmProvider(widget.workerHid).notifier)
        .reload(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final displayName = widget.initialName.trim().isNotEmpty
        ? widget.initialName.trim()
        : '작업자';

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('메모 · 평가'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  context.rsi(20),
                  context.rsi(8),
                  context.rsi(20),
                  context.rsi(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primaryContainer.withValues(alpha: 0.85),
                            cs.secondaryContainer.withValues(alpha: 0.35),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.rsi(22),
                          context.rsi(22),
                          context.rsi(22),
                          context.rsi(24),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: context.rs(28),
                              backgroundColor:
                                  cs.surface.withValues(alpha: 0.92),
                              foregroundColor: cs.onPrimaryContainer,
                              child: Text(
                                displayName.runes.isEmpty
                                    ? '?'
                                    : String.fromCharCode(
                                        displayName.runes.first,
                                      ),
                                style: tt.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: tt.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '관리 메모 · 평가 · 트러블 인력',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onPrimaryContainer
                                          .withValues(alpha: 0.88),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    WorkerMgmtHidContent(
                      workerHid: widget.workerHid,
                      displayName: displayName,
                      embedInScrollView: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 트러블 페어 전체 목록·추가.
class WorkerMgmtTroublesHubScreen extends ConsumerStatefulWidget {
  const WorkerMgmtTroublesHubScreen({super.key});

  @override
  ConsumerState<WorkerMgmtTroublesHubScreen> createState() =>
      _WorkerMgmtTroublesHubScreenState();
}

class _WorkerMgmtTroublesHubScreenState
    extends ConsumerState<WorkerMgmtTroublesHubScreen> {
  SuperAdminRemoteUseCase get _uc => ref.read(superAdminRemoteUseCaseProvider);

  String _hname(List<HumanRead> humans, int hid) {
    for (final h in humans) {
      if (h.hid == hid) return h.hname;
    }
    return '알 수 없음';
  }

  Future<void> _reloadConflicts() =>
      ref.read(workerMgmtConflictsHubProvider.notifier).reload(silent: false);

  Future<void> _ensureHumans() async {
    await ref
        .read(workerMgmtHumanDirectoryProvider.notifier)
        .reload(blocking: false);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref
          .read(workerMgmtHumanDirectoryProvider.notifier)
          .reload(blocking: false);
    });
  }

  Future<void> _setActiveOnly(bool v) =>
      ref.read(workerMgmtConflictsHubProvider.notifier).setActiveOnly(v);

  Future<void> _deleteConflict(WorkerMgmtConflictRead c) async {
    final pid = c.pairId;
    if (pid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제할 페어 번호가 없습니다.')),
        );
      }
      return;
    }
    final humans = ref.read(workerMgmtHumanDirectoryProvider).humans;
    final left = _hname(humans, c.workerAHid);
    final right = _hname(humans, c.workerBHid);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('트러블 페어 삭제'),
        content: Text(
          '「$left」·「$right」 페어를 삭제할까요?\n삭제 후에는 두 작업자를 같은 현장에 함께 투입할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _uc.workerMgmtConflictDelete(pid);
      ref.invalidate(workerMgmtHidVmProvider(c.workerAHid));
      ref.invalidate(workerMgmtHidVmProvider(c.workerBHid));
      await ref
          .read(workerMgmtConflictsHubProvider.notifier)
          .reload(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(workerMgmtUserMessage(e))),
        );
      }
    }
  }

  Future<void> _openAddDialog() async {
    await _ensureHumans();
    if (!mounted) return;
    final humans = ref.read(workerMgmtHumanDirectoryProvider).humans;
    final activeHumans = humans.where((h) => h.hdelete == 0).toList()
      ..sort((a, b) => a.hname.compareTo(b.hname));
    if (activeHumans.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인력이 2명 이상이어야 합니다.')),
        );
      }
      return;
    }

    HumanRead? a = activeHumans.first;
    HumanRead? b = activeHumans[1];
    final noteCtrl = TextEditingController();
    var severity = 2;
    var active = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text('트러블 페어 등록'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '작업자 A',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  DropdownButton<HumanRead>(
                    isExpanded: true,
                    value: a,
                    items: activeHumans
                        .map(
                          (h) => DropdownMenuItem(
                            value: h,
                            child: Text(h.hname),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => a = v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '작업자 B',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  DropdownButton<HumanRead>(
                    isExpanded: true,
                    value: b,
                    items: activeHumans
                        .map(
                          (h) => DropdownMenuItem(
                            value: h,
                            child: Text(h.hname),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => b = v),
                  ),
                  const SizedBox(height: 12),
                  Text('심각도', style: Theme.of(ctx).textTheme.labelLarge),
                  Slider(
                    value: severity.toDouble(),
                    min: 1,
                    max: 3,
                    divisions: 2,
                    label: '$severity',
                    onChanged: (v) => setLocal(() => severity = v.round()),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('활성'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '비고',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => noteCtrl.dispose());

    if (ok != true || !mounted) return;
    final ha = a;
    final hb = b;
    if (ha == null || hb == null || ha.hid == hb.hid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서로 다른 작업자 두 명을 선택해 주세요.')),
      );
      return;
    }

    try {
      await _uc.workerMgmtConflictUpsert(
        workerAHid: ha.hid,
        workerBHid: hb.hid,
        severity: severity,
        note: noteCtrl.text.trim(),
        active: active,
      );
      await ref
          .read(workerMgmtConflictsHubProvider.notifier)
          .reload(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(workerMgmtUserMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hub = ref.watch(workerMgmtConflictsHubProvider);
    final humans = ref.watch(workerMgmtHumanDirectoryProvider).humans;

    final blockingHub =
        hub.initialLoading && hub.conflicts.isEmpty && hub.error == null;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        centerTitle: false,
        title: const Text('트러블 페어 관리'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: hub.refreshing ? null : _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('페어 등록'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(20),
              context.rsi(12),
              context.rsi(20),
              context.rsi(6),
            ),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: AppSegmentedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rsi(14),
                  vertical: context.rsi(12),
                ),
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('활성만'),
                  icon: Icon(Icons.visibility_rounded, size: 18),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('전체'),
                  icon: Icon(Icons.list_rounded, size: 18),
                ),
              ],
              selected: {hub.activeOnly},
              onSelectionChanged: (s) {
                final v = s.first;
                unawaited(_setActiveOnly(v));
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.rsi(20),
              0,
              context.rsi(20),
              context.rsi(8),
            ),
            child: Text(
              '같은 조합을 다시 저장하면 서버에서 이어서 갱신됩니다.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: blockingHub
                ? Skeletonizer(
                    enabled: true,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        context.rsi(20),
                        context.rsi(4),
                        context.rsi(20),
                        context.rsi(28),
                      ),
                      itemCount: 6,
                      itemBuilder: (_, i) => Padding(
                        padding: EdgeInsets.only(bottom: context.rsi(12)),
                        child: Material(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(18),
                          child: const ListTile(
                            title: Text('트러블 페어'),
                            subtitle: Text('인력 A · 인력 B'),
                          ),
                        ),
                      ),
                    ),
                  )
                : hub.error != null && hub.conflicts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(context.rsi(28)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                size: context.rs(44),
                                color: cs.outline,
                              ),
                              SizedBox(height: context.rsi(12)),
                              Text(
                                workerMgmtUserMessage(hub.error!),
                                textAlign: TextAlign.center,
                                style: tt.bodyMedium,
                              ),
                              SizedBox(height: context.rsi(16)),
                              FilledButton.tonalIcon(
                                onPressed:
                                    hub.refreshing ? null : _reloadConflicts,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: cs.primary,
                        onRefresh: _reloadConflicts,
                        child: hub.conflicts.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height * 0.2,
                                  ),
                                  Icon(
                                    Icons.handshake_outlined,
                                    size: context.rs(48),
                                    color: cs.outline,
                                  ),
                                  SizedBox(height: context.rsi(12)),
                                  Center(
                                    child: Text(
                                      '등록된 트러블 페어가 없습니다.',
                                      style: tt.bodyLarge?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  context.rsi(20),
                                  context.rsi(4),
                                  context.rsi(20),
                                  context.rsi(100),
                                ),
                                itemCount: hub.conflicts.length,
                                itemBuilder: (context, i) {
                                  final c = hub.conflicts[i];
                                  final left = _hname(humans, c.workerAHid);
                                  final right = _hname(humans, c.workerBHid);
                                  return Padding(
                                    padding:
                                        EdgeInsets.only(bottom: context.rsi(12)),
                                    child: Material(
                                      color: cs.surface,
                                      elevation: 0,
                                      surfaceTintColor: cs.surfaceTint,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        side: BorderSide(
                                          color: cs.outlineVariant
                                              .withValues(alpha: 0.55),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Padding(
                                        padding: EdgeInsets.all(context.rsi(16)),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '$left · $right',
                                                    style:
                                                        tt.titleSmall?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                if (c.pairId != null)
                                                  IconButton(
                                                    tooltip: '페어 삭제',
                                                    icon: Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color: cs.error,
                                                    ),
                                                    onPressed: () =>
                                                        _deleteConflict(c),
                                                  ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: context.rsi(10),
                                                    vertical: context.rsi(4),
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: c.active
                                                        ? cs.tertiaryContainer
                                                            .withValues(
                                                                alpha: 0.55)
                                                        : cs.surfaceContainerHighest,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Text(
                                                    c.active ? '활성' : '비활성',
                                                    style: tt.labelMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: c.active
                                                          ? cs.onTertiaryContainer
                                                          : cs.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Text(
                                                  '심각도',
                                                  style:
                                                      tt.labelMedium?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                _TroubleSeverityDots(
                                                  severity: c.severity,
                                                ),
                                              ],
                                            ),
                                            if (c.note.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                c.note,
                                                style: tt.bodySmall?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// 심각도 1~3: 회색 원 3개 중 앞에서부터 [ColorScheme.error]로 채움 (0이면 전부 회색).
class _TroubleSeverityDots extends StatelessWidget {
  const _TroubleSeverityDots({required this.severity});

  final int severity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final level = severity.clamp(0, 3);
    final empty = cs.outline.withValues(alpha: 0.42);
    final filled = cs.error;

    return Tooltip(
      message: '심각도 $severity / 3',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 7),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < level ? filled : empty,
              ),
            ),
          );
        }),
      ),
    );
  }
}
