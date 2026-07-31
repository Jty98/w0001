import 'dart:async';
import 'package:w0001/ui/widget/app_text_field.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/model/auth_models.dart';
import 'package:w0001/data/model/remote/super_admin_dtos.dart';
import 'package:w0001/domain/data_change_event.dart';
import 'package:w0001/presentation/viewmodel/place_list_view_model.dart';
import 'package:w0001/presentation/viewmodel/auth_providers.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_notifier.dart';
import 'package:w0001/presentation/viewmodel/profile_super_admin_members_state.dart';
import 'package:w0001/presentation/viewmodel/worker_mgmt_view_model.dart';
import 'package:w0001/util/worker_skills_display.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/profile_super_admin_search_debounce_holder.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_confirm_dialogs.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_empty_banner.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/non_member_human_detail_sheet.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_member_detail_sheet.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_member_card.dart';
import 'package:w0001/ui/screen/0_auth/super_admin_profile/super_admin_queue_block.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/app_sliding_segment.dart';
import 'package:w0001/ui/widget/human_picker/human_search_pick_sheet.dart';
import 'package:w0001/data/mappers/remote_mappers.dart';
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/util/fetch_data.dart';
import 'package:w0001/util/responsive_layout.dart';

String _memberActionErrorLine(Object e) {
  if (e is DioException) {
    final inner = e.error;
    if (inner is HttpClientException) return inner.message;
  }
  if (e is HttpClientException) return e.message;
  return e.toString();
}

Future<String?> _obtainSensitiveActionToken(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String body,
  required void Function(String message) toast,
}) async {
  final pw = await showSuperAdminSensitiveActionPasswordDialog(
    context: context,
    title: title,
    body: body,
  );
  if (pw == null || !context.mounted) return null;
  try {
    final r =
        await ref.read(authApiProvider).verifySensitiveAction(password: pw);
    return r.actionToken;
  } catch (e) {
    if (context.mounted) toast(_memberActionErrorLine(e));
    return null;
  }
}

/// 프로필 회원 관리 — **처리 필요** / **활동 회원** / **비회원** 탭.
///
/// [expandBody]가 true이면 본문을 [PageView]로 두어 좌우 스와이프로 탭을 바꿀 수 있다.
/// (부모가 세로 높이를 줘야 한다.)
class ProfileSuperAdminMembersPanel extends ConsumerStatefulWidget {
  const ProfileSuperAdminMembersPanel({
    super.key,
    required this.searchController,
    required this.debounceHolder,

    /// `0` 처리 필요, `1` 활동 회원, `2` 비회원. null 이면 데이터에 따라 자동.
    this.initialSection,
    this.expandBody = false,
    this.onRefresh,
  });

  final TextEditingController searchController;
  final ProfileSuperAdminSearchDebounceHolder debounceHolder;
  final int? initialSection;
  final bool expandBody;
  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<ProfileSuperAdminMembersPanel> createState() =>
      _ProfileSuperAdminMembersPanelState();
}

class _ProfileSuperAdminMembersPanelState
    extends ConsumerState<ProfileSuperAdminMembersPanel> {
  /// 0 = 처리 필요, 1 = 활동 회원, 2 = 비회원
  late int _section;
  late final PageController _pageController;
  var _initialSectionApplied = false;
  var _humanDirectoryEnsured = false;
  final _nonMemberSearch = TextEditingController();

  @override
  void dispose() {
    _nonMemberSearch.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final forced = widget.initialSection;
    if (forced != null && (forced == 0 || forced == 1 || forced == 2)) {
      _section = forced;
      _initialSectionApplied = true;
    } else {
      _section = 0;
    }
    _pageController = PageController(initialPage: _section);
    // Human directory를 한 번만 로드하도록 initState에서 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_humanDirectoryEnsured) {
        _humanDirectoryEnsured = true;
        ref.read(workerMgmtHumanDirectoryProvider.notifier).ensureLoaded();
      }
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteNonMemberHuman(HumanRead h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'),
        content: Text('${h.hname} 님을 삭제할까요?'),
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
    if (ok != true || !mounted) return;
    try {
      await ref.read(humanUseCaseProvider).deleteWorker(h.hid);
      await FetchData.onDataChanged(DataChangeEvent.humanSaved);
      if (mounted) _toast('삭제했습니다.');
    } catch (e) {
      if (mounted) _toast('삭제 실패: $e');
    }
  }

  void _applyInitialSectionIfNeeded(ProfileSuperAdminMembersState state) {
    if (_initialSectionApplied || widget.initialSection != null) return;
    if (state.busyQueue && state.busyActive) return;
    final queueTotal = state.pendingMembers.length +
        state.suspendedMembers.length +
        state.rejectedMembers.length;
    final next = queueTotal > 0 ? 0 : 1;
    if (_section != next) {
      setState(() => _section = next);
      _syncPageToSection(next);
    }
    _initialSectionApplied = true;
  }

  void _syncPageToSection(int index, {bool animate = true}) {
    if (!widget.expandBody) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final current = _pageController.page?.round() ?? _section;
      if (current == index) return;
      if (animate) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _pageController.jumpToPage(index);
      }
    });
  }

  void _selectSection(int index) {
    if (_section == index) return;
    setState(() => _section = index);
    if (widget.expandBody) {
      _syncPageToSection(index);
    }
  }

  Widget _wrapSectionPage(BuildContext context, Widget section) {
    if (!widget.expandBody) return section;
    final onRefresh = widget.onRefresh;
    return AppRefreshIndicator(
      enabled: onRefresh != null,
      onRefresh: onRefresh ?? () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: context.rsi(4)),
        child: section,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileSuperAdminMembersProvider);
    final n = ref.read(profileSuperAdminMembersProvider.notifier);
    final humanDir = ref.watch(workerMgmtHumanDirectoryProvider);
    final humans = humanDir.humans;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    _applyInitialSectionIfNeeded(state);
    final queueTotal = state.pendingMembers.length +
        state.suspendedMembers.length +
        state.rejectedMembers.length;

    final handlers = _buildHandlers(context, ref, n, cs);
    final openMemberDetail = (UserRead u) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => SuperAdminMemberDetailSheet(initialUser: u),
      );
    };
    final openNonMemberDetail = (HumanRead h) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => NonMemberHumanDetailSheet(initialHuman: h),
      );
    };

    final nonMembers = humans
        .where((h) => h.hdelete == 0 && h.uid.trim().isEmpty)
        .toList()
      ..sort((a, b) => a.hname.compareTo(b.hname));

    bool queueLoading(Object? queueErr, List<UserRead> queueItems) =>
        state.busyQueue && queueErr == null && queueItems.isEmpty;

    final queueSection = _buildQueueSection(
      context: context,
      state: state,
      n: n,
      humans: humans,
      cs: cs,
      tt: tt,
      handlers: handlers,
      openMemberDetail: openMemberDetail,
      queueLoading: queueLoading,
    );
    final activeSection = _buildActiveSection(
      context: context,
      state: state,
      n: n,
      humans: humans,
      cs: cs,
      tt: tt,
      handlers: handlers,
      openMemberDetail: openMemberDetail,
    );
    final nonMemberSection = _buildNonMemberSection(
      context: context,
      nonMembers: nonMembers,
      cs: cs,
      tt: tt,
      dirLoading: humanDir.initialLoading,
      openNonMemberDetail: openNonMemberDetail,
      onDeleteNonMember: _deleteNonMemberHuman,
    );

    final sectionBody = widget.expandBody
        ? Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) {
                if (_section != i) setState(() => _section = i);
              },
              children: [
                _wrapSectionPage(context, queueSection),
                _wrapSectionPage(context, activeSection),
                _wrapSectionPage(context, nonMemberSection),
              ],
            ),
          )
        : _MemberSectionSwipeDetector(
            onSwipeLeft: _section < 2 ? () => setState(() => _section++) : null,
            onSwipeRight:
                _section > 0 ? () => setState(() => _section--) : null,
            child: switch (_section) {
              0 => queueSection,
              1 => activeSection,
              _ => nonMemberSection,
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSlidingSegment<int>(
          value: _section,
          dense: false,
          padding: EdgeInsets.fromLTRB(
            0,
            context.rsi(2),
            0,
            context.rsi(10),
          ),
          onChanged: _selectSection,
          children: {
            0: AppSlidingSegment.tabLabel(
              context,
              '처리',
              count: queueTotal > 0 ? queueTotal : null,
              selected: _section == 0,
            ),
            1: AppSlidingSegment.tabLabel(
              context,
              '활동',
              count: state.activeMembers.length,
              selected: _section == 1,
            ),
            2: AppSlidingSegment.tabLabel(
              context,
              '비회원',
              count: nonMembers.length,
              selected: _section == 2,
            ),
          },
        ),
        sectionBody,
      ],
    );
  }

  SuperAdminMemberHandlers _buildHandlers(
    BuildContext context,
    WidgetRef ref,
    ProfileSuperAdminMembersNotifier n,
    ColorScheme cs,
  ) {
    Future<void> approve(UserRead u) async {
      final pack = await showSuperAdminConfirmWithNoteDialog(
        context: context,
        title: '가입 승인',
        body: '\'${u.uname}\' 님 가입 요청을 승인합니다. 활동 가능 상태로 만들 수 있습니다.',
        affirmativeLabel: '승인',
        hint: '메모 (선택)',
        affirmativeStyle: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
      );
      if (pack == null || pack.$1 != true || !context.mounted) return;
      try {
        await n.userApprove(
          u.uid,
          note: pack.$2.isEmpty ? null : pack.$2,
        );
        if (!context.mounted) return;
        _toast('승인했습니다.');
      } catch (e) {
        if (context.mounted) _toast('승인 실패: $e');
      }
    }

    Future<void> reject(UserRead u) async {
      final pack = await showSuperAdminConfirmWithNoteDialog(
        context: context,
        title: '가입 거절',
        body: '\'${u.uname}\' 님 가입 요청을 거절합니다. 계정 레코드는 남으며, 나중에 다시 승인할 수 있습니다.',
        affirmativeLabel: '거절',
        hint: '사유 메모 (선택)',
        affirmativeStyle: FilledButton.styleFrom(
          backgroundColor: cs.error,
          foregroundColor: cs.onError,
        ),
      );
      if (pack == null || pack.$1 != true || !context.mounted) return;
      try {
        await n.userReject(
          u.uid,
          note: pack.$2.isEmpty ? null : pack.$2,
        );
        if (!context.mounted) return;
        _toast('거절 처리했습니다.');
      } catch (e) {
        if (context.mounted) _toast('거절 실패: $e');
      }
    }

    Future<void> suspend(UserRead u) async {
      if (isProtectedAdminUser(u)) return;
      final pack = await showSuperAdminConfirmWithNoteDialog(
        context: context,
        title: '활동 정지',
        body: '\'${u.uname}\' 계정 활동을 막습니다. 나중에 재활성화할 수 있습니다.',
        affirmativeLabel: '정지',
        hint: '사유 (선택)',
        affirmativeStyle: null,
      );
      if (pack == null || pack.$1 != true || !context.mounted) return;
      final token = await _obtainSensitiveActionToken(
        context,
        ref,
        title: '활동 정지 확인',
        body: '\'${u.uname}\' 계정에 활동 정지를 적용합니다. 관리자 비밀번호를 입력하세요.',
        toast: _toast,
      );
      if (token == null || !context.mounted) return;
      try {
        await n.userSuspend(
          u.uid,
          reason: pack.$2.isEmpty ? null : pack.$2,
          adminActionToken: token,
        );
        if (!context.mounted) return;
        _toast('활동을 정지했습니다.');
      } catch (e) {
        if (context.mounted) {
          _toast('정지 실패: ${_memberActionErrorLine(e)}');
        }
      }
    }

    Future<void> activate(UserRead u) async {
      final ok = await showSuperAdminSimpleConfirmDialog(
        context: context,
        title: '계정 활성화',
        body: '\'${u.uname}\' 활동 정지 상태를 해제합니다. 바로 활동 가능 상태로 되돌립니다.',
        confirmLabel: '활성화',
      );
      if (!ok || !context.mounted) return;
      try {
        await n.userActivate(u.uid);
        if (!context.mounted) return;
        _toast('재활성화했습니다.');
      } catch (e) {
        if (context.mounted) _toast('재활성화 실패: $e');
      }
    }

    Future<void> flipRole(UserRead u) async {
      if (isProtectedAdminUser(u)) return;
      final next = u.role == UserRole.admin ? UserRole.worker : UserRole.admin;
      final token = await _obtainSensitiveActionToken(
        context,
        ref,
        title: '권한 변경 확인',
        body: '\'${u.uname}\' 님을 ${next.labelKo}(으)로 변경합니다. 관리자 비밀번호를 입력하세요.',
        toast: _toast,
      );
      if (token == null || !context.mounted) return;
      try {
        await n.userChangeRole(
          u.uid,
          next,
          adminActionToken: token,
        );
        if (!context.mounted) return;
        _toast('권한을 ${next.labelKo}(으)로 변경했습니다.');
      } catch (e) {
        if (context.mounted) {
          _toast('권한 변경 실패: ${_memberActionErrorLine(e)}');
        }
      }
    }

    Future<void> deleteUser(UserRead u) async {
      final ok = await showSuperAdminDeleteUserConfirmDialog(
        context: context,
        uname: u.uname,
      );
      if (!ok || !context.mounted) return;
      try {
        await n.userDelete(u.uid);
        if (!context.mounted) return;
        _toast('삭제했습니다.');
      } catch (e) {
        if (context.mounted) _toast('삭제 실패: $e');
      }
    }

    return SuperAdminMemberHandlers(
      approve: approve,
      reject: reject,
      suspend: suspend,
      activate: activate,
      flipRole: flipRole,
      deleteUser: deleteUser,
    );
  }

  Widget _buildQueueSection({
    required BuildContext context,
    required ProfileSuperAdminMembersState state,
    required ProfileSuperAdminMembersNotifier n,
    required List<HumanRead> humans,
    required ColorScheme cs,
    required TextTheme tt,
    required SuperAdminMemberHandlers handlers,
    required void Function(UserRead u) openMemberDetail,
    required bool Function(Object?, List<UserRead>) queueLoading,
  }) {
    final pending = state.pendingMembers.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionTitle('처리 필요'),
        SizedBox(height: context.rsi(8)),
        if (pending > 0)
          Material(
            color: cs.tertiaryContainer.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rsi(10),
                vertical: context.rsi(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.mark_email_unread_rounded,
                    size: context.rs(18),
                    color: cs.onTertiaryContainer,
                  ),
                  SizedBox(width: context.rsi(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '승인 대기 $pending건',
                          style: tt.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                        SizedBox(height: context.rsi(2)),
                        Text(
                          '가입 요청을 먼저 처리해 주세요',
                          style: tt.labelSmall?.copyWith(
                            color:
                                cs.onTertiaryContainer.withValues(alpha: 0.9),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (pending > 0) SizedBox(height: context.rsi(8)),
        if (state.busyQueue)
          Padding(
            padding: EdgeInsets.only(bottom: context.rsi(6)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Skeletonizer(
                enabled: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: context.rs(16),
                      color: cs.tertiary.withValues(alpha: 0.9),
                    ),
                    SizedBox(width: context.rsi(6)),
                    Text('목록 불러오는 중…', style: tt.labelSmall),
                  ],
                ),
              ),
            ),
          ),
        ProfileInsetPanel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SuperAdminQueueBlock(
                subtitle: '승인 대기',
                humans: humans,
                items: state.pendingMembers,
                error: state.errorPending,
                icon: Icons.mark_email_unread_rounded,
                emptyMessage: '대기 없음',
                handlers: handlers,
                onRetryReload: () => unawaited(n.reload()),
                onOpenMemberDetail: openMemberDetail,
                loading: queueLoading(state.errorPending, state.pendingMembers),
                embedded: true,
              ),
              SuperAdminQueueBlock(
                subtitle: '활동 정지',
                humans: humans,
                items: state.suspendedMembers,
                error: state.errorSuspended,
                icon: Icons.block_rounded,
                emptyMessage: '없음',
                handlers: handlers,
                onRetryReload: () => unawaited(n.reload()),
                onOpenMemberDetail: openMemberDetail,
                loading:
                    queueLoading(state.errorSuspended, state.suspendedMembers),
                embedded: true,
                showTopDivider: true,
              ),
              SuperAdminQueueBlock(
                subtitle: '거절 및 재승인',
                humans: humans,
                items: state.rejectedMembers,
                error: state.errorRejected,
                icon: Icons.cancel_outlined,
                emptyMessage: '없음',
                handlers: handlers,
                onRetryReload: () => unawaited(n.reload()),
                onOpenMemberDetail: openMemberDetail,
                loading:
                    queueLoading(state.errorRejected, state.rejectedMembers),
                embedded: true,
                showTopDivider: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSection({
    required BuildContext context,
    required ProfileSuperAdminMembersState state,
    required ProfileSuperAdminMembersNotifier n,
    required List<HumanRead> humans,
    required ColorScheme cs,
    required TextTheme tt,
    required SuperAdminMemberHandlers handlers,
    required void Function(UserRead u) openMemberDetail,
  }) {
    final searchTrim = widget.searchController.text.trim();
    final isSearching = searchTrim.isNotEmpty;
    final total = state.activeDisplayCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionTitle('활동 회원'),
        SizedBox(height: context.rsi(8)),
        if (total > 0)
          Padding(
            padding: EdgeInsets.only(bottom: context.rsi(6)),
            child: Text(
              isSearching ? '검색 결과 $total명' : '활동 회원 $total명',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ProfileInsetPanel(
          padding: EdgeInsets.all(context.rsi(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: widget.searchController,
                builder: (context, _) {
                  final hasQuery =
                      widget.searchController.text.trim().isNotEmpty;
                  return AppTextField(
                    controller: widget.searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '이름으로 검색',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: context.rsi(8),
                      ),
                      prefixIcon:
                          Icon(Icons.search_rounded, size: context.rs(20)),
                      suffixIcon: hasQuery
                          ? IconButton(
                              tooltip: '지우기',
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                widget.debounceHolder.cancel();
                                final had = widget.searchController.text
                                    .trim()
                                    .isNotEmpty;
                                widget.searchController.clear();
                                if (had) {
                                  unawaited(n.fetchActiveMembers(''));
                                }
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: cs.surface.withValues(alpha: 0.65),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.55)),
                      ),
                    ),
                    onSubmitted: (_) {
                      widget.debounceHolder.cancel();
                      unawaited(
                        n.fetchActiveMembers(
                            widget.searchController.text.trim()),
                      );
                    },
                  );
                },
              ),
              if (state.errorActive != null)
                Padding(
                  padding: EdgeInsets.only(top: context.rsi(8)),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(context.rsi(10)),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: cs.error,
                          size: context.rs(18),
                        ),
                        SizedBox(width: context.rsi(8)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '목록을 불러오지 못했습니다',
                                style: tt.labelMedium?.copyWith(
                                  color: cs.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: context.rsi(2)),
                              Text(
                                '${state.errorActive}',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '다시',
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.refresh_rounded, color: cs.primary),
                          onPressed: () => unawaited(
                            n.fetchActiveMembers(
                                widget.searchController.text.trim()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: context.rsi(8)),
              if (state.activeMembers.isEmpty &&
                  !state.busyActive &&
                  state.errorActive == null)
                SuperAdminEmptyBanner(
                  message: widget.searchController.text.trim().isEmpty
                      ? '등록된 활동 회원이 없습니다.'
                      : '검색 결과 없음',
                  icon: Icons.people_outline_rounded,
                )
              else if (state.activeMembers.isNotEmpty) ...[
                ...state.activeMembers.map(
                  (u) {
                    final linked = findHumanReadForMember(u, humans);
                    return SuperAdminMemberCard(
                      user: u,
                      handlers: handlers,
                      primarySpecialty: memberListPrimarySpecialty(
                        u,
                        linkedHuman: linked,
                      ),
                      onOpenDetail: () => openMemberDetail(u),
                    );
                  },
                ),
                if (state.activeHasMore)
                  Padding(
                    padding: EdgeInsets.only(top: context.rsi(4)),
                    child: state.activeLoadingMore
                        ? PagedListFooter(
                            isLoading: true,
                            hasMore: true,
                          )
                        : Center(
                            child: TextButton.icon(
                              onPressed: () =>
                                  unawaited(n.loadMoreActiveMembers()),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.expand_more_rounded,
                                  size: 18),
                              label: Text(
                                '더 불러오기 (${state.activeMembers.length}/$total)',
                                style: tt.labelMedium,
                              ),
                            ),
                          ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNonMemberSection({
    required BuildContext context,
    required List<HumanRead> nonMembers,
    required ColorScheme cs,
    required TextTheme tt,
    required bool dirLoading,
    required void Function(HumanRead h) openNonMemberDetail,
    required Future<void> Function(HumanRead h) onDeleteNonMember,
  }) {
    final query = _nonMemberSearch.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? nonMembers
        : nonMembers
            .where((h) => h.hname.toLowerCase().contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionTitle('비회원 인력'),
        SizedBox(height: context.rsi(8)),
        Text(
          '앱 가입 없이 직접 등록한 인력입니다. 인력관리 화면과 동일한 정보를 확인할 수 있습니다.',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        SizedBox(height: context.rsi(10)),
        ProfileInsetPanel(
          padding: EdgeInsets.all(context.rsi(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _nonMemberSearch,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '이름으로 검색',
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded, size: context.rs(20)),
                  filled: true,
                  fillColor: cs.surface.withValues(alpha: 0.65),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: context.rsi(10)),
              if (dirLoading && nonMembers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: AppLoadingIndicator(size: 64),
                )
              else if (filtered.isEmpty)
                SuperAdminEmptyBanner(
                  message: query.isEmpty ? '등록된 비회원 인력이 없습니다.' : '검색 결과 없음',
                  icon: Icons.person_off_outlined,
                )
              else
                ...filtered.map(
                  (h) => Slidable(
                    closeOnScroll: true,
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      extentRatio: 0.22,
                      children: [
                        CustomSlidableAction(
                          onPressed: (_) => onDeleteNonMember(h),
                          backgroundColor: cs.error,
                          foregroundColor: cs.onError,
                          padding: EdgeInsets.zero,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: context.rs(20),
                          ),
                        ),
                      ],
                    ),
                    child: HumanPickPersonTile(
                      name: h.hname,
                      human: humanReadToModel(h),
                      showRrn: false,
                      selected: false,
                      multi: false,
                      onTap: () => openNonMemberDetail(h),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberSectionSwipeDetector extends StatelessWidget {
  const _MemberSectionSwipeDetector({
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -320) {
          onSwipeLeft?.call();
        } else if (velocity > 320) {
          onSwipeRight?.call();
        }
      },
      child: child,
    );
  }
}
