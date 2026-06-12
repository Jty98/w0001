import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_member_model.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/place_members_providers.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/widget/human_worker_search_bar.dart';
import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 멤버 관리 화면.
class PlaceMembersScreen extends ConsumerStatefulWidget {
  const PlaceMembersScreen({super.key, required this.place});

  final PlaceInfoModel place;

  @override
  ConsumerState<PlaceMembersScreen> createState() =>
      _PlaceMembersScreenState();
}

class _PlaceMembersScreenState extends ConsumerState<PlaceMembersScreen> {
  Future<void> _reload() async {
    ref.invalidate(placeMembersProvider(widget.place.pid ?? 0));
  }

  /// 멤버 [workerUid]에 연결된 인력(hid)의 해당 현장 작업지시 건수.
  Future<int?> _countPlaceWorkdaysForMember(int pid, String workerUid) async {
    try {
      await ref.read(workerProvider.notifier).fetchWorkerInfo();
      final workers = ref.read(workerProvider).filteredWorkerList;
      final hid = workers
          .where((w) => w.uid != null && w.uid == workerUid)
          .map((w) => w.hid)
          .whereType<int>()
          .firstOrNull;
      if (hid == null) return null;
      final rows =
          await ref.read(superAdminRemoteUseCaseProvider).placeWorkDaysList();
      return rows.where((r) => r.pid == pid && r.hid == hid).length;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final pid = widget.place.pid;
    if (pid == null) return;

    await ref.read(workerProvider.notifier).fetchWorkerInfo();
    final allWorkers = ref.read(workerProvider).filteredWorkerList;
    final currentMembers = ref.read(placeMembersProvider(pid)).asData?.value ?? [];
    final currentUids = currentMembers.map((m) => m.uid).toSet();
    
    final availableWorkers = allWorkers
        .where((w) => 
            w.canBePlaceMember &&                // app_user 계정이 있는 워커만
            !currentUids.contains(w.uid) &&      // uid로 비교
            w.hdelete == 0
        )
        .toList();

    if (!context.mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _AddMemberDialog(workers: availableWorkers),
    );

    if (selected == null || !context.mounted) return;

    try {
      await ref.read(placeMembersUseCaseProvider).addMember(pid, selected);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작업자를 현장에 초대했습니다.')),
      );
      await _reload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초대 실패: $e')),
        );
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context, PlaceMemberRead member) async {
    final pid = widget.place.pid;
    if (pid == null) return;

    final workdayCount = await _countPlaceWorkdaysForMember(pid, member.uid);
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 제거'),
        content: Text(
          workdayCount != null && workdayCount > 0
              ? '${member.uname}님을 현장에서 제거할까요?\n\n'
                  '이 작업자에게 이 현장의 작업지시(투입)가 '
                  '$workdayCount건 있습니다.\n'
                  '제거하면 현장 접근 권한만 해제되고, 작업지시 이력은 그대로 남습니다.'
              : '${member.uname}님을 현장에서 제거할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('제거'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    try {
      final res =
          await ref.read(placeMembersUseCaseProvider).removeMember(pid, member.uid);
      if (!context.mounted) return;
      final preWarned =
          workdayCount != null && workdayCount > 0;
      if (res.hasWorkdayWarning && !preWarned) {
        final w = res.warning!;
        final body = w.message.trim().isNotEmpty
            ? w.message.trim()
            : '이 작업자는 이 현장에 작업지시(투입) 이력이 '
                '${w.workdayCount}건 있습니다.\n'
                '접근 권한은 해제되었지만, 이력은 남아있습니다.';
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('작업지시 이력이 있습니다'),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('멤버를 제거했습니다.')),
      );
      await _reload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('제거 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pid = widget.place.pid ?? 0;
    final membersAsync = ref.watch(placeMembersProvider(pid));
    final me = ref.watch(authSessionProvider).asData?.value;
    final isAdmin = me?.isManagementRole ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.place.pname} · 현장 멤버'),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddMemberDialog(context),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('작업자 초대'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: membersAsync.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: ListView.builder(
              padding: EdgeInsets.all(context.rsi(16)),
              itemCount: 5,
              itemBuilder: (ctx, i) => Padding(
                padding: EdgeInsets.only(bottom: context.rsi(12)),
                child: _MemberCard(
                  member: PlaceMemberRead(
                    uid: 'user$i',
                    uname: '사용자 $i',
                    role: 'worker',
                    addedAt: DateTime.now(),
                  ),
                  onRemove: null,
                ),
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: EdgeInsets.all(context.rsi(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$e', textAlign: TextAlign.center),
                  SizedBox(height: context.rsi(16)),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
          data: (members) {
            if (members.isEmpty) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.rsi(24)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: context.rs(64),
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            SizedBox(height: context.rsi(16)),
                            Text(
                              '현장 멤버가 없습니다',
                              style: tt.titleMedium?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: context.rsi(8)),
                            Text(
                              '작업자를 초대하면 이 현장의 공지와 정보를 받을 수 있습니다.',
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            if (isAdmin) ...[
                              SizedBox(height: context.rsi(24)),
                              FilledButton.icon(
                                onPressed: () => _showAddMemberDialog(context),
                                icon: const Icon(Icons.person_add_outlined),
                                label: const Text('작업자 초대하기'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final admins = members.where((m) => m.isAdmin).toList();
            final workers = members.where((m) => m.isWorker).toList();

            return ListView(
              padding: EdgeInsets.fromLTRB(
                context.rsi(16),
                context.rsi(16),
                context.rsi(16),
                context.rsi(100),
              ),
              children: [
                if (admins.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.admin_panel_settings_outlined,
                    title: '관리자',
                    count: admins.length,
                  ),
                  SizedBox(height: context.rsi(12)),
                  for (var i = 0; i < admins.length; i++) ...[
                    if (i > 0) SizedBox(height: context.rsi(12)),
                    _MemberCard(
                      member: admins[i],
                      onRemove: null,
                    ),
                  ],
                  SizedBox(height: context.rsi(24)),
                ],
                _SectionHeader(
                  icon: Icons.engineering_outlined,
                  title: '작업자',
                  count: workers.length,
                ),
                SizedBox(height: context.rsi(12)),
                if (workers.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: context.rsi(16)),
                    child: Text(
                      '초대된 작업자가 없습니다.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < workers.length; i++) ...[
                    if (i > 0) SizedBox(height: context.rsi(12)),
                    _MemberCard(
                      member: workers[i],
                      onRemove: isAdmin
                          ? () => _confirmRemove(context, workers[i])
                          : null,
                    ),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: context.rs(20), color: cs.primary),
        SizedBox(width: context.rsi(8)),
        Text(
          title,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        SizedBox(width: context.rsi(6)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rsi(8),
            vertical: context.rsi(2),
          ),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(context.rsi(12)),
          ),
          child: Text(
            '$count',
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    this.onRemove,
  });

  final PlaceMemberRead member;
  final VoidCallback? onRemove;

  String _getRoleName() {
    if (member.isAdmin) return '관리자';
    return '작업자';
  }

  Color _getRoleColor(ColorScheme cs) {
    if (member.isAdmin) return cs.tertiary;
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rsi(14)),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.rsi(14)),
        child: Row(
          children: [
            CircleAvatar(
              radius: context.rs(22),
              backgroundColor: _getRoleColor(cs).withValues(alpha: 0.2),
              foregroundColor: _getRoleColor(cs),
              child: Text(
                member.uname.isNotEmpty ? member.uname[0] : '?',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: context.rsi(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.uname,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  SizedBox(height: context.rsi(4)),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rsi(8),
                          vertical: context.rsi(3),
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(cs).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(context.rsi(6)),
                        ),
                        child: Text(
                          _getRoleName(),
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _getRoleColor(cs),
                          ),
                        ),
                      ),
                      if (member.autoAdded) ...[
                        SizedBox(width: context.rsi(6)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.rsi(6),
                            vertical: context.rsi(3),
                          ),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(context.rsi(6)),
                          ),
                          child: Text(
                            '자동추가',
                            style: tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: context.rsi(6)),
                  Text(
                    '${member.addedAt.year}.${member.addedAt.month.toString().padLeft(2, '0')}.${member.addedAt.day.toString().padLeft(2, '0')} 추가',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.person_remove_outlined,
                  color: cs.error,
                ),
                tooltip: '제거',
              ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({required this.workers});

  final List<HumanModel> workers;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  late final TextEditingController _searchController;
  late List<HumanModel> _filteredWorkers;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredWorkers = widget.workers;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredWorkers = widget.workers;
      } else {
        _filteredWorkers = widget.workers
            .where((w) => w.hname.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _openBrowseSheet() {
    showWorkerGroupedListSheet(
      context: context,
      title: '작업자 찾기 (${_filteredWorkers.length})',
      workers: _filteredWorkers,
      onWorkerTap: (h) {
        if (h.uid != null) {
          Navigator.pop(context, h.uid);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (widget.workers.isEmpty) {
      return AlertDialog(
        title: const Text('작업자 초대'),
        content: const Text(
          '초대 가능한 등록 작업자가 없습니다.\n'
          '앱에 회원가입한 작업자만 현장 멤버로 추가할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('작업자 초대'),
      contentPadding: EdgeInsets.fromLTRB(
        context.rsi(16),
        context.rsi(12),
        context.rsi(16),
        0,
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HumanWorkerSearchBar(
              searchController: _searchController,
              onChanged: _applySearch,
              workerCount: _filteredWorkers.length,
              onBrowseTap: _openBrowseSheet,
              padding: EdgeInsets.zero,
            ),
            SizedBox(height: context.rsi(8)),
            Expanded(
              child: _filteredWorkers.isEmpty
                  ? Center(
                      child: Text(
                        '검색 결과가 없습니다',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredWorkers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final w = _filteredWorkers[i];
                        return ListTile(
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: context.rsi(4)),
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                            child: Text(
                              w.hname.isNotEmpty ? w.hname[0] : '?',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text(
                            w.hname,
                            style: tt.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            w.hdefaultRole.isNotEmpty
                                ? w.hdefaultRole
                                : '역할 미지정',
                            style: tt.bodySmall,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.pop(context, w.uid),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ],
    );
  }
}
