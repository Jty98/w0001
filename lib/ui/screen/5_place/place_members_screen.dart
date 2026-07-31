import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/hammer_loading_indicator.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/access/user_role_access.dart';
import 'package:w0001/data/model/place_info_model.dart';
import 'package:w0001/data/model/place_member_model.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/ui/widget/app_text_field.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart'
    show humanUseCaseProvider;
import 'package:w0001/presentation/viewmodel/place_members_providers.dart';
import 'package:w0001/presentation/viewmodel/super_admin_remote_providers.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/theme/app_theme_colors.dart';
import 'package:w0001/theme/app_section_card.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/human_picker/human_search_pick_sheet.dart';
import 'package:w0001/util/responsive_layout.dart';

/// 현장 멤버 관리 화면.
class PlaceMembersScreen extends ConsumerStatefulWidget {
  const PlaceMembersScreen({super.key, required this.place});

  final PlaceInfoModel place;

  @override
  ConsumerState<PlaceMembersScreen> createState() => _PlaceMembersScreenState();
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

    final currentMembers =
        ref.read(placeMembersProvider(pid)).asData?.value ?? [];
    final currentUids = currentMembers.map((m) => m.uid).toSet();

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _PlaceMemberInviteSheet(excludeUids: currentUids),
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

  Future<void> _confirmRemove(
      BuildContext context, PlaceMemberRead member) async {
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
      final res = await ref
          .read(placeMembersUseCaseProvider)
          .removeMember(pid, member.uid);
      if (!context.mounted) return;
      final preWarned = workdayCount != null && workdayCount > 0;
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
      body: AppRefreshIndicator(
        enabled: !(membersAsync.isLoading && !membersAsync.hasValue),
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
                  _MembersSectionCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: '관리자',
                    count: admins.length,
                    members: admins,
                    onRemove: null,
                  ),
                  SizedBox(height: context.rsi(24)),
                ],
                _MembersSectionCard(
                  icon: Icons.engineering_outlined,
                  title: '작업자',
                  count: workers.length,
                  members: workers,
                  emptyMessage: '초대된 작업자가 없습니다.',
                  onRemove: isAdmin
                      ? (member) => _confirmRemove(context, member)
                      : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MembersSectionCard extends StatelessWidget {
  const _MembersSectionCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.members,
    this.emptyMessage,
    this.onRemove,
  });

  final IconData icon;
  final String title;
  final int count;
  final List<PlaceMemberRead> members;
  final String? emptyMessage;
  final void Function(PlaceMemberRead member)? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppSectionCard(
      icon: icon,
      title: title,
      subtitle: '$count명',
      contentPadding: EdgeInsets.fromLTRB(
        context.rsi(12),
        context.rsi(8),
        context.rsi(12),
        context.rsi(12),
      ),
      child: members.isEmpty
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: context.rsi(8)),
              child: Text(
                emptyMessage ?? '멤버가 없습니다.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  if (i > 0) SizedBox(height: context.rsi(8)),
                  _MemberCard(
                    member: members[i],
                    onRemove:
                        onRemove != null ? () => onRemove!(members[i]) : null,
                  ),
                ],
              ],
            ),
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

    return AppInsetTile(
      padding: EdgeInsets.all(context.rsi(14)),
      child: Row(
        children: [
          CircleAvatar(
            radius: context.rs(22),
            backgroundColor: cs.appIconBadge,
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
                        color: cs.appMutedFill,
                        borderRadius: BorderRadius.circular(context.rsi(6)),
                        border: Border.all(color: cs.appBorder),
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
                          color: cs.appIconBadge,
                          borderRadius: BorderRadius.circular(context.rsi(6)),
                          border: Border.all(color: cs.appBorder),
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
    );
  }
}

class _PlaceMemberInviteSheet extends ConsumerStatefulWidget {
  const _PlaceMemberInviteSheet({required this.excludeUids});

  final Set<String> excludeUids;

  @override
  ConsumerState<_PlaceMemberInviteSheet> createState() =>
      _PlaceMemberInviteSheetState();
}

class _PlaceMemberInviteSheetState
    extends ConsumerState<_PlaceMemberInviteSheet> {
  late final TextEditingController _queryCtrl;
  Timer? _debounce;
  var _query = '';
  var _loading = false;
  var _searched = false;
  List<HumanModel> _results = [];

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  List<HumanModel> _filterCandidates(List<HumanModel> raw) {
    return raw
        .where(
          (w) =>
              w.canBePlaceMember &&
              w.hdelete == 0 &&
              w.uid != null &&
              !widget.excludeUids.contains(w.uid),
        )
        .toList();
  }

  Future<void> _search({String? query}) async {
    final q = (query ?? _query).trim();
    if (q.isEmpty) {
      setState(() {
        _searched = false;
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _searched = true;
    });

    try {
      final list = await ref.read(humanUseCaseProvider).searchWorkers(q: q);
      if (!mounted) return;
      setState(() {
        _results = _filterCandidates(list);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _searched = false;
        _results = [];
        _loading = false;
      });
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _search(query: q));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(16),
                context.rsi(4),
                context.rsi(16),
                context.rsi(8),
              ),
              child: Text(
                '작업자 초대',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
              child: AppTextField(
                controller: _queryCtrl,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (q) => _search(query: q),
                decoration: InputDecoration(
                  hintText: '이름으로 검색',
                  isDense: true,
                  filled: true,
                  fillColor: cs.appMutedFill,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? Padding(
                          padding: EdgeInsets.all(context.rsi(12)),
                          child: SizedBox(
                            width: context.rs(18),
                            height: context.rs(18),
                            child: const HammerLoadingIndicator(size: 24),
                          ),
                        )
                      : IconButton(
                          tooltip: '검색',
                          icon: const Icon(Icons.search_rounded),
                          onPressed: () => _search(),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: cs.primary.withValues(alpha: 0.65)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.rsi(16),
                context.rsi(10),
                context.rsi(16),
                context.rsi(4),
              ),
              child: Text(
                '앱에 가입한 작업자만 초대할 수 있습니다. '
                '공정표 기반 AI 추천은 추후 제공될 예정입니다.',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const AppLoadingIndicator()
                  : !_searched
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(context.rsi(24)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_search_outlined,
                                  size: context.rs(48),
                                  color: cs.outline,
                                ),
                                SizedBox(height: context.rsi(12)),
                                Text(
                                  '이름을 검색해 주세요',
                                  style: tt.bodyLarge?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                '초대 가능한 작업자가 없습니다',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                context.rsi(16),
                                0,
                                context.rsi(16),
                                context.rsi(8) + bottom,
                              ),
                              itemCount: _results.length,
                              itemBuilder: (ctx, i) {
                                final w = _results[i];
                                return HumanPickPersonTile(
                                  name: w.hname,
                                  human: w,
                                  showRrn: false,
                                  selected: false,
                                  multi: false,
                                  onTap: () {
                                    final uid = w.uid;
                                    if (uid != null) {
                                      Navigator.pop(context, uid);
                                    }
                                  },
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}
