import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:w0001/ui/widget/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:w0001/data/model/human_model.dart';
import 'package:w0001/presentation/viewmodel/worker_view_model.dart';
import 'package:w0001/ui/screen/0_auth/widgets/profile_section_chrome.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_editor_dialog.dart';
import 'package:w0001/ui/screen/4_human/widgets/human_list_card.dart';
import 'package:w0001/ui/widget/app_sliding_segment.dart';
import 'package:w0001/ui/widget/human_worker_search_bar.dart';
import 'package:w0001/ui/widget/worker_grouped_list/worker_grouped_list_sheet.dart';
import 'package:w0001/ui/widget/app_refresh_indicator.dart';
import 'package:w0001/ui/widget/paged_list_footer.dart';
import 'package:w0001/util/responsive_layout.dart';

enum _HumanListSegment { member, nonMember }

class HumanScreen extends ConsumerStatefulWidget {
  const HumanScreen({super.key});

  @override
  ConsumerState<HumanScreen> createState() => _HumanScreenState();
}

class _HumanScreenState extends ConsumerState<HumanScreen> {
  late final ScrollController _scrollMember;
  late final ScrollController _scrollNonMember;
  late final PageController _pageController;
  var _segment = _HumanListSegment.member;

  @override
  void initState() {
    super.initState();
    _scrollMember = ScrollController()..addListener(_onScrollMember);
    _scrollNonMember = ScrollController()..addListener(_onScrollNonMember);
    _pageController = PageController(initialPage: _segment.index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
          ref.read(workerProvider.notifier).prepareHumanManagementScreen());
    });
  }

  void _onScrollMember() => _onScrollFor(_HumanListSegment.member);

  void _onScrollNonMember() => _onScrollFor(_HumanListSegment.nonMember);

  void _onScrollFor(_HumanListSegment segment) {
    if (_segment != segment) return;
    final controller =
        segment == _HumanListSegment.member ? _scrollMember : _scrollNonMember;
    onPagedScrollNearEnd(
      controller,
      onLoadMore: () => ref.read(workerProvider.notifier).loadMoreWorkers(),
    );
  }

  void _selectSegment(_HumanListSegment next) {
    if (_segment == next) return;
    setState(() => _segment = next);
    _pageController.animateToPage(
      next.index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollMember.dispose();
    _scrollNonMember.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openEditor(
    BuildContext context,
    WorkerViewModel vm, {
    required int? listIndex,
    HumanModel? human,
    bool humanAlreadyLoaded = false,
  }) async {
    if (listIndex != null && human != null && !humanAlreadyLoaded) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AppLoadingIndicator(),
      );
      try {
        final fresh = await vm.loadWorkerForEdit(human);
        if (!context.mounted) return;
        Navigator.of(context).pop();
        vm.showWorkerInfoFromHuman(fresh, listIndex: listIndex);
      } catch (_) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('인력 정보를 불러오지 못했습니다.')),
          );
        }
        return;
      }
    } else if (listIndex != null && human != null) {
      vm.showWorkerInfoFromHuman(human, listIndex: listIndex);
    } else {
      vm.cancelHumanEditorForm();
    }
    if (!context.mounted) return;
    showHumanEditorDialog(
      context: context,
      ref: ref,
      listIndex: listIndex,
    );
  }

  Future<void> _openBrowseSheet(
      BuildContext context, WorkerViewModel vm) async {
    final state = ref.read(workerProvider);
    final workers = state.filteredWorkerList;
    if (workers.isEmpty && state.isWorkersLoading) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AppLoadingIndicator(),
      );
      await ref.read(workerProvider.notifier).refreshWorkers();
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }
    if (!context.mounted) return;
    final refreshed = ref.read(workerProvider);
    final notifier = ref.read(workerProvider.notifier);
    final list = refreshed.filteredWorkerList;
    final total = notifier.displayWorkerCount;
    showWorkerGroupedListSheet(
      context: context,
      title: '인력 찾기 ($total)',
      workers: list,
      onWorkerTap: (h) async {
        final notifier = ref.read(workerProvider.notifier);
        final fresh = await notifier.loadWorkerForEdit(h);
        if (!context.mounted) return;
        final index = notifier.indexOfWorkerInPagedList(fresh);
        if (index >= 0) {
          await _openEditor(
            context,
            notifier,
            listIndex: index,
            human: fresh,
            humanAlreadyLoaded: true,
          );
        } else {
          notifier.showWorkerInfoFromHuman(fresh);
          showHumanEditorDialog(
            context: context,
            ref: ref,
            editHuman: fresh,
          );
        }
      },
    );
  }

  List<({int index, HumanModel human})> _entriesFor(
    List<HumanModel> workers, {
    required bool members,
  }) {
    final out = <({int index, HumanModel human})>[];
    for (var i = 0; i < workers.length; i++) {
      final h = workers[i];
      final isMember = humanIsLinkedAppMember(h);
      if (members == isMember) {
        out.add((index: i, human: h));
      }
    }
    return out;
  }

  Widget _emptyState({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: context.rsi(16)),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.32,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: context.rs(40),
                  color: cs.onSurfaceVariant.withValues(alpha: 0.42),
                ),
                SizedBox(height: context.rsi(10)),
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: context.rsi(4)),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _segmentList({
    required BuildContext context,
    required WorkerViewModel vm,
    required ScrollController scrollController,
    required List<({int index, HumanModel human})> entries,
    required _HumanListSegment segment,
    required bool isSearching,
    required bool directoryEmpty,
    required bool isLoadingMore,
    required bool hasMore,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isMemberTab = segment == _HumanListSegment.member;

    if (entries.isEmpty) {
      final title = directoryEmpty
          ? (isMemberTab ? '등록된 회원이 없습니다' : '등록된 비회원이 없습니다')
          : (isSearching
              ? '검색 결과가 없습니다'
              : (isMemberTab ? '회원이 없습니다' : '비회원이 없습니다'));
      final subtitle = directoryEmpty
          ? (isMemberTab
              ? '앱에 가입·연결된 인력이 여기에 표시됩니다'
              : '우측 상단 + 로 비회원 인력을 등록해 주세요')
          : (isSearching
              ? '다른 검색어를 입력해 보세요'
              : (isMemberTab
                  ? '다른 탭에서 비회원 인력을 확인해 보세요'
                  : '우측 상단 + 로 비회원 인력을 등록해 주세요'));
      return AppRefreshIndicator(
        onRefresh: vm.fetchWorkerInfo,
        child: _emptyState(
          context: context,
          icon: isMemberTab
              ? Icons.badge_outlined
              : Icons.person_add_alt_1_outlined,
          title: title,
          subtitle: subtitle,
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: vm.fetchWorkerInfo,
      child: ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(2),
          context.rsi(16),
          context.rsi(24),
        ),
        children: [
          ProfileSectionTitle(
            isMemberTab ? '회원 ${entries.length}명' : '비회원 ${entries.length}명',
          ),
          SizedBox(height: context.rsi(4)),
          Text(
            isMemberTab ? '앱 계정과 연결된 인력' : '직접 등록한 비회원 인력',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.rsi(10)),
          ProfileInsetPanel(
            padding: EdgeInsets.symmetric(
              horizontal: context.rsi(6),
              vertical: context.rsi(6),
            ),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) SizedBox(height: context.rsi(4)),
                  HumanListCard(
                    index: entries[i].index,
                    human: entries[i].human,
                    onTap: () => _openEditor(
                      context,
                      vm,
                      listIndex: entries[i].index,
                      human: entries[i].human,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PagedListFooter(
            isLoading: isLoadingMore,
            hasMore: hasMore,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workerProvider);
    final vm = ref.read(workerProvider.notifier);
    final workerCount = vm.displayWorkerCount;
    final workers = state.filteredWorkerList;
    final memberEntries = _entriesFor(workers, members: true);
    final nonMemberEntries = _entriesFor(workers, members: false);
    final isSearching =
        vm.searchWorkerDetailTextContoller.text.trim().isNotEmpty;
    final directoryEmpty = state.workerInfoList.isEmpty;
    final showSkeleton =
        state.isWorkersLoading && state.filteredWorkerList.isEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('인력 관리'),
          actions: [
            IconButton(
              tooltip: '비회원 인력 등록',
              onPressed: showSkeleton
                  ? null
                  : () {
                      if (_segment != _HumanListSegment.nonMember) {
                        _selectSegment(_HumanListSegment.nonMember);
                      }
                      _openEditor(context, vm, listIndex: null);
                    },
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            HumanWorkerSearchBar(
              searchController: vm.searchWorkerDetailTextContoller,
              onChanged: showSkeleton ? (_) {} : vm.searchWokerInfo,
              workerCount: showSkeleton ? 0 : workerCount,
              onBrowseTap:
                  showSkeleton ? () {} : () => _openBrowseSheet(context, vm),
            ),
            AppSlidingSegment<_HumanListSegment>(
              value: _segment,
              dense: false,
              padding: EdgeInsets.fromLTRB(
                context.rsi(16),
                context.rsi(2),
                context.rsi(16),
                context.rsi(10),
              ),
              onChanged: showSkeleton ? (_) {} : _selectSegment,
              children: {
                _HumanListSegment.member: AppSlidingSegment.tabLabel(
                  context,
                  '회원',
                  count: showSkeleton ? null : memberEntries.length,
                  selected: _segment == _HumanListSegment.member,
                ),
                _HumanListSegment.nonMember: AppSlidingSegment.tabLabel(
                  context,
                  '비회원',
                  count: showSkeleton ? null : nonMemberEntries.length,
                  selected: _segment == _HumanListSegment.nonMember,
                ),
              },
            ),
            Expanded(
              child: showSkeleton
                  ? const _HumanListSkeleton()
                  : PageView(
                      controller: _pageController,
                      onPageChanged: (i) {
                        final next = _HumanListSegment.values[i];
                        if (_segment != next) {
                          setState(() => _segment = next);
                        }
                      },
                      children: [
                        _segmentList(
                          context: context,
                          vm: vm,
                          scrollController: _scrollMember,
                          entries: memberEntries,
                          segment: _HumanListSegment.member,
                          isSearching: isSearching,
                          directoryEmpty: directoryEmpty,
                          isLoadingMore: state.isLoadingMore,
                          hasMore: state.hasMore,
                        ),
                        _segmentList(
                          context: context,
                          vm: vm,
                          scrollController: _scrollNonMember,
                          entries: nonMemberEntries,
                          segment: _HumanListSegment.nonMember,
                          isSearching: isSearching,
                          directoryEmpty: directoryEmpty,
                          isLoadingMore: state.isLoadingMore,
                          hasMore: state.hasMore,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HumanListSkeleton extends StatelessWidget {
  const _HumanListSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Skeletonizer(
      enabled: true,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          context.rsi(16),
          context.rsi(4),
          context.rsi(16),
          context.rsi(24),
        ),
        children: [
          const Text(
            '인력 불러오는 중',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.rsi(8)),
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) SizedBox(height: context.rsi(4)),
            Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(context.rsi(10)),
              child: const ListTile(
                title: Text('홍길동'),
                subtitle: Text('현장역할 · 일당 · 연락처'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
